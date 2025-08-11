-- Файл: luasrc/controller/wififailover.lua
-- LuCI контроллер для WiFi Failover (LEDE 17.01.7)

module("luci.controller.wififailover", package.seeall)

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs = require "nixio.fs"

function index()
    -- Проверка прав доступа
    if not nixio.fs.access("/etc/config/wififailover") then
        return
    end

    -- Главное меню
    local page = entry({"admin", "network", "wififailover"}, firstchild(), _("WiFi Failover"), 60)
    page.dependent = false
    page.acl_depends = { "luci-app-wififailover" }

    -- Вкладка настроек
    entry({"admin", "network", "wififailover", "config"}, 
          cbi("wififailover/config"), _("Configuration"), 1)

    -- Вкладка статуса
    entry({"admin", "network", "wififailover", "status"}, 
          call("action_status"), _("Status"), 2)

    -- API endpoints для AJAX
    entry({"admin", "network", "wififailover", "scan"}, 
          call("action_scan_wifi"), nil).leaf = true
          
    entry({"admin", "network", "wififailover", "test_connection"}, 
          call("action_test_connection"), nil).leaf = true
          
    entry({"admin", "network", "wififailover", "switch_network"}, 
          call("action_switch_network"), nil).leaf = true
          
    entry({"admin", "network", "wififailover", "logs"}, 
          call("action_get_logs"), nil).leaf = true
end

-- Страница статуса
function action_status()
    local data = get_status_data()
    luci.template.render("wififailover/status", data)
end

-- Сканирование WiFi сетей
function action_scan_wifi()
    luci.http.prepare_content("application/json")
    
    local networks = {}
    local scan_cmd = "iw dev wlan0 scan 2>/dev/null | grep -E 'SSID:|signal:' | paste - -"
    local handle = io.popen(scan_cmd)
    
    if handle then
        for line in handle:lines() do
            local ssid = line:match("SSID:%s*(.-)%s*signal:")
            local signal = line:match("signal:%s*([-0-9.]+)")
            
            if ssid and ssid ~= "" and ssid ~= "\\x00" then
                table.insert(networks, {
                    ssid = ssid,
                    signal = tonumber(signal) or -100,
                    quality = get_signal_quality(tonumber(signal) or -100)
                })
            end
        end
        handle:close()
    end
    
    -- Fallback для LEDE 17.01
    if #networks == 0 then
        local iwlist_cmd = "iwlist wlan0 scan 2>/dev/null | grep -E 'ESSID:|Quality='"
        handle = io.popen(iwlist_cmd)
        
        if handle then
            local current_ssid = nil
            for line in handle:lines() do
                local essid = line:match('ESSID:"(.-)"')
                local quality = line:match("Quality=(%d+)/(%d+)")
                
                if essid then
                    current_ssid = essid
                elseif quality and current_ssid then
                    local qual_num = tonumber(quality) or 0
                    table.insert(networks, {
                        ssid = current_ssid,
                        signal = -50 - (70 * (1 - qual_num/70)), -- Примерное преобразование
                        quality = math.floor((qual_num / 70) * 100)
                    })
                    current_ssid = nil
                end
            end
            handle:close()
        end
    end
    
    -- Сортировка по уровню сигнала
    table.sort(networks, function(a, b) return a.signal > b.signal end)
    
    luci.http.write_json({
        success = true,
        networks = networks,
        timestamp = os.time()
    })
end

-- Тестирование подключения
function action_test_connection()
    luci.http.prepare_content("application/json")
    
    local host = luci.http.formvalue("host") or "8.8.8.8"
    local timeout = tonumber(luci.http.formvalue("timeout")) or 5
    
    local start_time = os.time()
    local cmd = string.format("ping -c 1 -W %d %s >/dev/null 2>&1", timeout, host)
    local result = os.execute(cmd)
    local end_time = os.time()
    
    local success = (result == 0 or result == true)
    
    luci.http.write_json({
        success = success,
        host = host,
        response_time = end_time - start_time,
        timestamp = os.time()
    })
end

-- Ручное переключение сети
function action_switch_network()
    luci.http.prepare_content("application/json")
    
    local ssid = luci.http.formvalue("ssid")
    if not ssid or ssid == "" then
        luci.http.write_json({
            success = false,
            error = "SSID is required"
        })
        return
    end
    
    -- Поиск сети в конфигурации
    local network_found = false
    local network_data = {}
    
    uci:foreach("wififailover", "network", function(s)
        if s.ssid == ssid then
            network_found = true
            network_data = {
                ssid = s.ssid,
                key = s.key or "",
                security = s.security or "psk2"
            }
            return false
        end
    end)
    
    if not network_found then
        luci.http.write_json({
            success = false,
            error = "Network not found in configuration"
        })
        return
    end
    
    -- Выполнение переключения
    local switch_cmd = string.format("lua -e \"" ..
        "local utils = require('wififailover.utils'); " ..
        "utils.connect_wifi('%s', '%s', '%s')\"", 
        network_data.ssid, network_data.key, network_data.security)
    
    local result = os.execute(switch_cmd)
    local success = (result == 0 or result == true)
    
    if success then
        -- Обновление текущей сети в UCI
        uci:set("wififailover", "settings", "current_network", ssid)
        uci:commit("wififailover")
    end
    
    luci.http.write_json({
        success = success,
        ssid = ssid,
        message = success and "Network switch initiated" or "Failed to switch network"
    })
end

-- Получение логов
function action_get_logs()
    luci.http.prepare_content("application/json")
    
    local logs = {}
    local log_sources = {
        {file = "/tmp/wififailover.log", source = "daemon"},
        {cmd = "logread | grep wififailover | tail -50", source = "syslog"}
    }
    
    for _, src in ipairs(log_sources) do
        if src.file and fs.access(src.file) then
            local content = fs.readfile(src.file) or ""
            for line in content:gmatch("[^\r\n]+") do
                table.insert(logs, {
                    source = src.source,
                    message = line,
                    timestamp = extract_timestamp(line)
                })
            end
        elseif src.cmd then
            local handle = io.popen(src.cmd)
            if handle then
                for line in handle:lines() do
                    table.insert(logs, {
                        source = src.source,
                        message = line,
                        timestamp = extract_timestamp(line)
                    })
                end
                handle:close()
            end
        end
    end
    
    -- Сортировка по времени (новые сверху)
    table.sort(logs, function(a, b) 
        return (a.timestamp or 0) > (b.timestamp or 0) 
    end)
    
    luci.http.write_json({
        success = true,
        logs = logs,
        count = #logs
    })
end

-- Вспомогательные функции

function get_status_data()
    local data = {}
    
    -- Настройки из UCI
    uci:load("wififailover")
    data.settings = {
        enabled = uci:get("wififailover", "settings", "enabled") == "1",
        ping_host = uci:get("wififailover", "settings", "ping_host") or "8.8.8.8",
        check_interval = uci:get("wififailover", "settings", "check_interval") or "30",
        max_failures = uci:get("wififailover", "settings", "max_failures") or "3",
        auto_switch = uci:get("wififailover", "settings", "auto_switch") == "1",
        debug = uci:get("wififailover", "settings", "debug") == "1"
    }
    
    -- Статус демона
    data.daemon = {
        running = is_daemon_running(),
        pid = get_daemon_pid()
    }
    
    -- Текущая WiFi сеть
    data.current_wifi = get_current_wifi_info()
    
    -- Статус интернета
    data.internet = test_internet_connection(data.settings.ping_host)
    
    -- Настроенные сети
    data.networks = get_configured_networks()
    
    -- Системная информация
    data.system = {
        uptime = sys.uptime(),
        load = sys.loadavg(),
        wifi_interface = fs.access("/sys/class/net/wlan0")
    }
    
    return data
end

function is_daemon_running()
    local handle = io.popen("pgrep -f wififailover-daemon")
    local pid = handle:read("*a"):match("^%s*(.-)%s*$")
    handle:close()
    return pid and pid ~= ""
end

function get_daemon_pid()
    if fs.access("/var/run/wififailover.pid") then
        return fs.readfile("/var/run/wififailover.pid"):match("^%s*(.-)%s*$")
    end
    return nil
end

function get_current_wifi_info()
    local info = {}
    
    -- SSID
    local handle = io.popen("iw dev wlan0 link 2>/dev/null | grep 'SSID' | awk '{print $2}'")
    info.ssid = handle:read("*a"):match("^%s*(.-)%s*$") or "Not connected"
    handle:close()
    
    -- Уровень сигнала
    handle = io.popen("iw dev wlan0 link 2>/dev/null | grep 'signal' | awk '{print $2}'")
    local signal = handle:read("*a"):match("^%s*(.-)%s*$")
    info.signal = tonumber(signal) or -100
    info.quality = get_signal_quality(info.signal)
    handle:close()
    
    -- Время подключения
    handle = io.popen("cat /proc/net/wireless 2>/dev/null | grep wlan0")
    info.connected = handle:read("*a") ~= ""
    handle:close()
    
    return info
end

function test_internet_connection(host)
    local start_time = os.time()
    local cmd = string.format("ping -c 1 -W 5 %s >/dev/null 2>&1", host)
    local result = os.execute(cmd)
    local end_time = os.time()
    
    return {
        connected = (result == 0 or result == true),
        host = host,
        response_time = end_time - start_time
    }
end

function get_configured_networks()
    local networks = {}
    
    uci:foreach("wififailover", "network", function(s)
        table.insert(networks, {
            id = s[".name"],
            ssid = s.ssid,
            priority = tonumber(s.priority) or 999,
            enabled = s.enabled == "1",
            security = s.security or "psk2",
            has_key = (s.key and s.key ~= ""),
            last_connected = tonumber(s.last_connected) or 0
        })
    end)
    
    -- Сортировка по приоритету
    table.sort(networks, function(a, b) return a.priority < b.priority end)
    
    return networks
end

function get_signal_quality(signal)
    if signal >= -50 then
        return 100
    elseif signal >= -60 then
        return 75
    elseif signal >= -70 then
        return 50
    elseif signal >= -80 then
        return 25
    else
        return 0
    end
end

function extract_timestamp(line)
    -- Попытка извлечь timestamp из строки лога
    local patterns = {
        "(%d+-%d+-%d+ %d+:%d+:%d+)",  -- YYYY-MM-DD HH:MM:SS
        "(%w+ %d+ %d+:%d+:%d+)",      -- Mon DD HH:MM:SS
    }
    
    for _, pattern in ipairs(patterns) do
        local match = line:match(pattern)
        if match then
            return os.time() -- Упрощение, в реальности нужен парсинг
        end
    end
    
    return os.time()
end