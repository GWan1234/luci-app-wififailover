#!/usr/bin/lua

package.path = package.path .. ";/usr/lib/wififailover/?.lua"

local uci = require "uci"

package.path = package.path .. ";/usr/lib/wififailover/?.lua"
local uci = require "uci"
local utils = {}
local cursor = uci.cursor()

function utils.log(level, message)
    os.execute("logger -t wififailover '" .. message .. "'")
    if cursor:get("wififailover", "settings", "debug") == "1" then
        local f = io.open("/tmp/wififailover.log", "a")
        if f then f:write(message .. "\n"); f:close() end
    end
end

function utils.get_settings()
    cursor:load("wififailover")
    return {
        enabled = cursor:get("wififailover", "settings", "enabled") or "0",
        ping_host = cursor:get("wififailover", "settings", "ping_host") or "8.8.8.8",
        check_interval = tonumber(cursor:get("wififailover", "settings", "check_interval")) or 30,
        max_failures = tonumber(cursor:get("wififailover", "settings", "max_failures")) or 3,
        connection_timeout = tonumber(cursor:get("wififailover", "settings", "connection_timeout")) or 60,
        debug = cursor:get("wififailover", "settings", "debug") or "0",
        current_network = cursor:get("wififailover", "settings", "current_network") or "",
        auto_switch = cursor:get("wififailover", "settings", "auto_switch") or "1"
    }
end

function utils.get_networks()
    cursor:load("wififailover")
    local n = {}
    cursor:foreach("wififailover", "network", function(s)
        if s.enabled == "1" then
            table.insert(n, {
                id = s[".name"], ssid = s.ssid, key = s.key or "", priority = tonumber(s.priority) or 999,
                security = s.security or "psk2", last_connected = tonumber(s.last_connected) or 0
            })
        end
    end)
    table.sort(n, function(a, b) return a.priority < b.priority end)
    return n
end

function utils.set_current_network(ssid)
    cursor:load("wififailover")
    cursor:set("wififailover", "settings", "current_network", ssid)
    cursor:commit("wififailover")
    utils.log("INFO", "Current network set to: " .. ssid)
end

function utils.update_last_connected(network_id)
    cursor:load("wififailover")
    cursor:set("wififailover", "settings", network_id, "last_connected", tostring(os.time()))
    cursor:commit("wififailover")
end

function utils.check_internet(host, timeout)
    host = host or "8.8.8.8"; timeout = timeout or 5
    local r = os.execute("ping -c 1 -W " .. timeout .. " " .. host .. " >/dev/null 2>&1")
    return r == 0 or r == true
end

function utils.get_current_wifi()
    local h = io.popen("iw dev wlan0 link 2>/dev/null | grep 'SSID' | awk '{print $2}'")
    local s = h:read("*a"):match("^%s*(.-)%s*$")
    h:close()
    return s ~= "" and s or nil
end

function utils.scan_wifi()
    local a = {}
    local h = io.popen("iw dev wlan0 scan 2>/dev/null | grep 'SSID:' | sed 's/.*SSID: //' 2>/dev/null")
    if h then for l in h:lines() do l = l:match("^%s*(.-)%s*$"); if l and l ~= "" then a[l] = true end end; h:close() end
    return a
end

function utils.connect_wifi(ssid, key, security)
    utils.log("INFO", "Attempting to connect to: " .. ssid)
    cursor:load("wireless")
    local iface
    cursor:foreach("wireless", "wifi-iface", function(s)
        if s.device and s.mode == "sta" then iface = s[".name"]; return false end
    end)
    if not iface then utils.log("ERROR", "WiFi client interface not found"); return false end
    cursor:set("wireless", iface, "ssid", ssid)
    cursor:set("wireless", iface, "disabled", "0")
    if key and key ~= "" then
        cursor:set("wireless", iface, "key", key)
        cursor:set("wireless", iface, "encryption", security or "psk2")
    else
        cursor:delete("wireless", iface, "key")
        cursor:set("wireless", iface, "encryption", "none")
    end
    cursor:commit("wireless")
    os.execute("wifi down"); os.execute("sleep 2"); os.execute("wifi up")
    utils.log("INFO", "WiFi configuration updated for: " .. ssid)
    return true
end

function utils.is_daemon_running()
    local h = io.popen("pgrep -f wififailover-daemon")
    local pid = h:read("*a"):match("^%s*(.-)%s*$")
    h:close()
    return pid and pid ~= ""
end

function utils.get_status()
    local s = utils.get_settings()
    return {
        enabled = s.enabled == "1",
        daemon_running = utils.is_daemon_running(),
        current_network = utils.get_current_wifi() or "Not connected",
        internet_status = utils.check_internet(s.ping_host) and "Connected" or "Disconnected",
        ping_host = s.ping_host,
        auto_switch = s.auto_switch == "1",
        networks_count = #utils.get_networks()
    }
end

return utils
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