local uci = luci.model.uci.cursor()

m = Map("wififailover", translate("WiFi Failover Settings"),
    translate("Configure WiFi failover parameters"))

-- Общие настройки
s = m:section(NamedSection, "wifi", translate("General Settings"))
s.addremove = false

o = s:option(Value, "check_interval", translate("Check Interval (seconds)"))
o.datatype = "uinteger"
o.default = "30"

o = s:option(Value, "ping_target", translate("Ping Target"))
o.datatype = "host"
o.default = "8.8.8.8"


s = m:section(TypedSection, "wifi_network", translate("Static Leases"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

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


