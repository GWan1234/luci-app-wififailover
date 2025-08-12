local uci = luci.model.uci.cursor()

m = Map("wififailover", translate("WiFi Failover Settings"),
    translate("Configure WiFi failover parameters"))

-- Общие настройки
s = m:section(NamedSection, "general", translate("General Settings"))
s.addremove = false

o = s:option(Value, "check_interval", translate("Check Interval (seconds)"))
o.datatype = "uinteger"
o.default = "30"

o = s:option(Value, "ping_target", translate("Ping Target"))
o.datatype = "host"
o.default = "8.8.8.8"

-- Section for WiFi networks with a custom handler
s = m:section(TypedSection, "wifi_network", translate("WiFi Networks"))
s.template = "cbi/tblsection"
s.addremove = true
s.anonymous = true

-- Override the creation of a new section
function s.create(self, section)
    -- Create an anonymous section, UCI will assign a name
    local sid = uci:add("wififailover", "wifi_network")
    return sid
end

-- Hide the ID input field, but display the generated ID
local id = s:option(DummyValue, ".name", translate("ID"))
id.forcewrite = true
function id.cfgvalue(self, section)
    return section
end

-- Fields for WiFi configuration
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