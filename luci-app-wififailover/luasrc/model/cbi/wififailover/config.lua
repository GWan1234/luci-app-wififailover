-- Файл: luasrc/model/cbi/wififailover/config.lua
-- CBI модель для конфигурации WiFi Failover (LEDE 17.01.7)

local fs = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

-- Создание основной карты
m = Map("wififailover", translate("WiFi Failover Configuration"),
    translate("Configure automatic WiFi network switching when internet connection is lost. " ..
             "Networks are tried in priority order (1 = highest priority)."))

-- Проверка наличия WiFi интерфейса
if not fs.access("/sys/class/net/wlan0") then
    m.message = translate("Warning: WiFi interface 'wlan0' not found. Please ensure WiFi is properly configured.")
end

--
-- Глобальные настройки
--
s = m:section(TypedSection, "global", translate("Global Settings"))
s.anonymous = true
s.addremove = false

-- Включение службы
enabled = s:option(Flag, "enabled", translate("Enable WiFi Failover"))
enabled.default = "0"
enabled.rmempty = false
enabled.description = translate("Enable automatic WiFi network switching")

-- Автоматическое переключение
auto_switch = s:option(Flag, "auto_switch", translate("Auto Switch"))
auto_switch.default = "1"
auto_switch.rmempty = false
auto_switch.description = translate("Automatically switch to backup networks when connection fails")
auto_switch:depends("enabled", "1")

-- Хост для проверки
ping_host = s:option(Value, "ping_host", translate("Ping Host"))
ping_host.default = "8.8.8.8"
ping_host.rmempty = false
ping_host.description = translate("Host to ping for internet connectivity check")
ping_host:depends("enabled", "1")

function ping_host.validate(self, value)
    if value then
        -- Проверка на валидный IP или доменное имя
        if value:match("^%d+%.%d+%.%d+%.%d+$") or value:match("^[%w%.%-]+$") then
            return value
        end
    end
    return nil, translate("Invalid host address")
end

-- Интервал проверки
check_interval = s:option(Value, "check_interval", translate("Check Interval"))
check_interval.default = "30"
check_interval.rmempty = false
check_interval.description = translate("Interval between internet connectivity checks (seconds)")
check_interval.datatype = "range(10,300)"
check_interval:depends("enabled", "1")

-- Максимальное количество неудач
max_failures = s:option(Value, "max_failures", translate("Max Failures"))
max_failures.default = "3"
max_failures.rmempty = false
max_failures.description = translate("Number of failed checks before switching network")
max_failures.datatype = "range(1,10)"
max_failures:depends("enabled", "1")

-- Таймаут подключения
connection_timeout = s:option(Value, "connection_timeout", translate("Connection Timeout"))
connection_timeout.default = "60"
connection_timeout.rmempty = false
connection_timeout.description = translate("Timeout for connecting to a network (seconds)")
connection_timeout.datatype = "range(30,180)"
connection_timeout:depends("enabled", "1")

-- Отладочный режим
debug = s:option(Flag, "debug", translate("Debug Mode"))
debug.default = "0"
debug.rmempty = false
debug.description = translate("Enable detailed logging to /tmp/wififailover.log")
debug:depends("enabled", "1")

--
-- Настройка сетей
--
s2 = m:section(TypedSection, "network", translate("WiFi Networks"))
s2.anonymous = true
s2.addremove = true
s2.template = "cbi/tblsection"
s2.sortable = true
s2.description = translate("Configure WiFi networks in order of preference. Lower priority numbers are tried first.")

-- Функция создания новой сети
function s2.create(self, section)
    local new_section = TypedSection.create(self, section)
    if new_section then
        -- Установка приоритета по умолчанию
        local max_priority = 0
        uci:foreach("wififailover", "network", function(s)
            local prio = tonumber(s.priority) or 0
            if prio > max_priority then
                max_priority = prio
            end
        end)
        uci:set("wififailover", new_section, "priority", tostring(max_priority + 1))
        uci:set("wififailover", new_section, "enabled", "1")
        uci:set("wififailover", new_section, "security", "psk2")
    end
    return new_section
end

-- SSID
ssid = s2:option(Value, "ssid", translate("SSID"))
ssid.rmempty = false
ssid.size = 20

-- Кнопка сканирования
scan_button = s2:option(Button, "_scan", translate("Scan"))
scan_button.inputtitle = translate("Scan Networks")
scan_button.inputstyle = "apply"
scan_button.template = "wififailover/scan_button"

-- Пароль
key = s2:option(Value, "key", translate("Password"))
key.password = true
key.rmempty = true
key.size = 15

-- Тип безопасности
security = s2:option(ListValue, "security", translate("Security"))
security:value("none", translate("No Encryption"))
security:value("wep", translate("WEP"))
security:value("psk", translate("WPA-PSK"))
security:value("psk2", translate("WPA2-PSK"))
security:value("psk-mixed", translate("WPA/WPA2 Mixed"))
security.default = "psk2"
security.rmempty = false

-- Приоритет
priority = s2:option(Value, "priority", translate("Priority"))
priority.datatype = "range(1,99)"
priority.default = "1"
priority.rmempty = false
priority.size = 5

-- Включена ли сеть
network_enabled = s2:option(Flag, "enabled", translate("Enabled"))
network_enabled.default = "1"
network_enabled.rmempty = false

-- Кнопка тестирования
test_button = s2:option(Button, "_test", translate("Test"))
test_button.inputtitle = translate("Test Connection")
test_button.inputstyle = "apply"
test_button.template = "wififailover/test_button"

-- Последнее подключение (только для чтения)
last_connected = s2:option(DummyValue, "last_connected", translate("Last Connected"))
function last_connected.cfgvalue(self, section)
    local timestamp = uci:get("wififailover", section, "last_connected")
    if timestamp and timestamp ~= "0" then
        return os.date("%Y-%m-%d %H:%M:%S", tonumber(timestamp))
    else
        return translate("Never")
    end
end

--
-- Валидация формы
--
function m.on_parse(self)
    Map.on_parse(self)
    
    -- Проверка уникальности SSID
    local ssids = {}
    local duplicates = {}
    
    uci:foreach("wififailover", "network", function(s)
        if s.ssid then
            if ssids[s.ssid] then
                duplicates[s.ssid] = true
            else
                ssids[s.ssid] = s[".name"]
            end
        end
    end)
    
    if next(duplicates) then
        self.message = translate("Error: Duplicate SSID found. Each network must have a unique SSID.")
        return false
    end
    
    -- Проверка наличия хотя бы одной активной сети при включенном сервисе
    local service_enabled = uci:get("wififailover", "settings", "enabled") == "1"
    if service_enabled then
        local has_active_network = false
        uci:foreach("wififailover", "network", function(s)
            if s.enabled == "1" and s.ssid and s.ssid ~= "" then
                has_active_network = true
                return false
            end
        end)
        
        if not has_active_network then
            self.message = translate("Warning: Service is enabled but no active networks are configured.")
        end
    end
end

function m.on_commit(self)
    Map.on_commit(self)
    
    -- Перезапуск сервиса при изменении конфигурации
    local service_enabled = uci:get("wififailover", "settings", "enabled")
    if service_enabled == "1" then
        sys.call("/etc/init.d/wififailover restart >/dev/null 2>&1 &")
        self.message = translate("Configuration saved. Service restarted.")
    else
        sys.call("/etc/init.d/wififailover stop >/dev/null 2>&1 &")
        self.message = translate("Configuration saved. Service stopped.")
    end
end

-- JavaScript для кнопок сканирования и тестирования
m.pageaction = false

return m