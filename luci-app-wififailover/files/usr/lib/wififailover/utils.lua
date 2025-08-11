#!/usr/bin/lua
-- Файл: files/usr/lib/wififailover/utils.lua
-- Утилиты для работы с Wi-Fi и UCI конфигурацией (LEDE 17.01.7)

-- Создание глобального пространства имен для совместимости с require
package.path = package.path .. ";/usr/lib/wififailover/?.lua"

local uci = require "uci"
local fs = require "nixio.fs"

local utils = {}

-- Инициализация UCI курсора
local cursor = uci.cursor()

-- Логирование
function utils.log(level, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] [%s] %s", timestamp, level, message)
    
    -- Запись в syslog
    os.execute(string.format("logger -t wififailover '%s'", message))
    
    -- Запись в файл лога если включен debug
    local debug = cursor:get("wififailover", "settings", "debug")
    if debug == "1" then
        local log_file = "/tmp/wififailover.log"
        local file = io.open(log_file, "a")
        if file then
            file:write(log_entry .. "\n")
            file:close()
        end
    end
end

-- Получение настроек из UCI
function utils.get_settings()
    cursor:load("wififailover")
    
    local settings = {
        enabled = cursor:get("wififailover", "settings", "enabled") or "0",
        ping_host = cursor:get("wififailover", "settings", "ping_host") or "8.8.8.8",
        check_interval = tonumber(cursor:get("wififailover", "settings", "check_interval")) or 30,
        max_failures = tonumber(cursor:get("wififailover", "settings", "max_failures")) or 3,
        connection_timeout = tonumber(cursor:get("wififailover", "settings", "connection_timeout")) or 60,
        debug = cursor:get("wififailover", "settings", "debug") or "0",
        current_network = cursor:get("wififailover", "settings", "current_network") or "",
        auto_switch = cursor:get("wififailover", "settings", "auto_switch") or "1"
    }
    
    return settings
end

-- Получение списка сетей из UCI
function utils.get_networks()
    cursor:load("wififailover")
    local networks = {}
    
    cursor:foreach("wififailover", "network", function(section)
        if section.enabled == "1" then
            table.insert(networks, {
                id = section[".name"],
                ssid = section.ssid,
                key = section.key or "",
                priority = tonumber(section.priority) or 999,
                security = section.security or "psk2",
                last_connected = tonumber(section.last_connected) or 0
            })
        end
    end)
    
    -- Сортировка по приоритету
    table.sort(networks, function(a, b) return a.priority < b.priority end)
    
    return networks
end

-- Обновление текущей сети в UCI
function utils.set_current_network(ssid)
    cursor:load("wififailover")
    cursor:set("wififailover", "settings", "current_network", ssid)
    cursor:commit("wififailover")
    utils.log("INFO", "Current network set to: " .. ssid)
end

-- Обновление времени последнего подключения
function utils.update_last_connected(network_id)
    cursor:load("wififailover")
    cursor:set("wififailover", "settings", network_id, "last_connected", tostring(os.time()))
    cursor:commit("wififailover")
end

-- Проверка доступности интернета
function utils.check_internet(host, timeout)
    host = host or "8.8.8.8"
    timeout = timeout or 5
    
    local cmd = string.format("ping -c 1 -W %d %s >/dev/null 2>&1", timeout, host)
    local result = os.execute(cmd)
    
    -- В Lua 5.1 os.execute возвращает число, в 5.2+ boolean
    local success = (result == 0 or result == true)
    
    if success then
        utils.log("DEBUG", "Internet check successful")
    else
        utils.log("DEBUG", "Internet check failed")
    end
    
    return success
end

-- Получение текущей Wi-Fi сети
function utils.get_current_wifi()
    local handle = io.popen("iw dev wlan0 link 2>/dev/null | grep 'SSID' | awk '{print $2}'")
    local ssid = handle:read("*a"):match("^%s*(.-)%s*$")
    handle:close()
    
    return ssid and ssid ~= "" and ssid or nil
end

-- Сканирование доступных Wi-Fi сетей (LEDE 17.01 совместимо)
function utils.scan_wifi()
    local available = {}
    
    -- Попытка использовать iw, fallback на iwlist
    local scan_cmd = "iw dev wlan0 scan 2>/dev/null | grep 'SSID:' | sed 's/.*SSID: //' 2>/dev/null"
    local handle = io.popen(scan_cmd)
    
    if handle then
        for line in handle:lines() do
            line = line:match("^%s*(.-)%s*$") -- trim whitespace
            if line and line ~= "" and line ~= "\\x00" then
                available[line] = true
            end
        end
        handle:close()
    end
    
    -- Fallback для LEDE 17.01
    if next(available) == nil then
        local iwlist_cmd = "iwlist wlan0 scan 2>/dev/null | grep 'ESSID:' | sed 's/.*ESSID:\"//' | sed 's/\".*//' 2>/dev/null"
        handle = io.popen(iwlist_cmd)
        
        if handle then
            for line in handle:lines() do
                line = line:match("^%s*(.-)%s*$")
                if line and line ~= "" then
                    available[line] = true
                end
            end
            handle:close()
        end
    end
    
    return available
end

-- Подключение к Wi-Fi сети (совместимо с LEDE 17.01)
function utils.connect_wifi(ssid, key, security)
    utils.log("INFO", "Attempting to connect to: " .. ssid)
    
    -- Получение wireless конфигурации
    cursor:load("wireless")
    
    -- Поиск WiFi интерфейса
    local wifi_iface_section = nil
    cursor:foreach("wireless", "wifi-iface", function(s)
        if s.device and s.mode == "sta" then
            wifi_iface_section = s[".name"]
            return false  -- Прекращаем поиск
        end
    end)
    
    if not wifi_iface_section then
        utils.log("ERROR", "WiFi client interface not found")
        return false
    end
    
    -- Настройка новой сети
    cursor:set("wireless", wifi_iface_section, "ssid", ssid)
    cursor:set("wireless", wifi_iface_section, "disabled", "0")
    
    if key and key ~= "" then
        cursor:set("wireless", wifi_iface_section, "key", key)
        cursor:set("wireless", wifi_iface_section, "encryption", security or "psk2")
    else
        cursor:delete("wireless", wifi_iface_section, "key")
        cursor:set("wireless", wifi_iface_section, "encryption", "none")
    end
    
    cursor:commit("wireless")
    
    -- Перезапуск WiFi (LEDE 17.01 совместимая команда)
    os.execute("wifi down")
    os.execute("sleep 2")
    os.execute("wifi up")
    
    utils.log("INFO", "WiFi configuration updated for: " .. ssid)
    return true
end

-- Проверка состояния демона
function utils.is_daemon_running()
    local handle = io.popen("pgrep -f wififailover-daemon")
    local pid = handle:read("*a"):match("^%s*(.-)%s*$")
    handle:close()
    
    return pid and pid ~= ""
end

-- Получение статистики
function utils.get_status()
    local settings = utils.get_settings()
    local current_wifi = utils.get_current_wifi()
    local internet_ok = utils.check_internet(settings.ping_host)
    local daemon_running = utils.is_daemon_running()
    
    return {
        enabled = settings.enabled == "1",
        daemon_running = daemon_running,
        current_network = current_wifi or "Not connected",
        internet_status = internet_ok and "Connected" or "Disconnected",
        ping_host = settings.ping_host,
        auto_switch = settings.auto_switch == "1",
        networks_count = #utils.get_networks()
    }
end

return utils