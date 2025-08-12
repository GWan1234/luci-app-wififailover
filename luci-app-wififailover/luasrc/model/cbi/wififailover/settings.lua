local uci = luci.model.uci.cursor()

m = Map("wififailover", translate("WiFi Failover Settings"),
    translate("Configure WiFi failover parameters"))

-- Общие настройки
s = m:section(NamedSection, "settings", "wifi", translate("General Settings"))
s.addremove = false

o = s:option(Value, "check_interval", translate("Check Interval (seconds)"))
o.datatype = "uinteger"
o.default = "30"

o = s:option(Value, "ping_target", translate("Ping Target"))
o.datatype = "host"
o.default = "8.8.8.8"

-- Секция WiFi сетей с кастомным обработчиком
s = m:section(TypedSection, "wifi_network", translate("WiFi Networks"))
s.template = "cbi/tblsection"
s.addremove = true
s.anonymous = false

-- Переопределяем создание новой секции
function s.create(self, section)
    -- Создаем анонимную секцию
    local sid = uci:add("wififailover", "wifi_network")
    uci:set("wififailover", sid, "type", "wifi_network")
    return sid
end

-- Скрываем поле ввода ID
id = s:option(DummyValue, ".name", translate("ID"))
id.forcewrite = true
function id.cfgvalue(self, section)
    return section
end

-- Поля для конфигурации WiFi
ssid = s:option(Value, "ssid", translate("SSID"))
bssid = s:option(Value, "bssid", translate("BSSID"))
key = s:option(Value, "key", translate("Password"))
key.password = true

encr = s:option(ListValue, "encryption", translate("Encryption"))
encr:value("none", "No Encryption")
encr:value("psk", "WPA-PSK")
encr:value("psk2", "WPA2-PSK")
encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode")
encr.default = "psk2"

return m