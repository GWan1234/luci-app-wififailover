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
m:section(SimpleSection).template = "admin_network/lease_status"

s = m:section(TypedSection, "host", translate("Static Leases"),
	translate("Static leases are used to assign fixed IP addresses and symbolic hostnames to " ..
		"DHCP clients. They are also required for non-dynamic interface configurations where " ..
		"only hosts with a corresponding lease are served.") .. "<br />" ..
	translate("Use the <em>Add</em> Button to add a new lease entry. The <em>MAC-Address</em> " ..
		"indentifies the host, the <em>IPv4-Address</em> specifies to the fixed address to " ..
		"use and the <em>Hostname</em> is assigned as symbolic name to the requesting host. " ..
		"The optional <em>Lease time</em> can be used to set non-standard host-specific " ..
		"lease time, e.g. 12h, 3d or infinite."))

s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

name = s:option(Value, "name", translate("Hostname"))
name.datatype = "hostname"
name.rmempty  = true

function name.write(self, section, value)
	Value.write(self, section, value)
	m:set(section, "dns", "1")
end

function name.remove(self, section)
	Value.remove(self, section)
	m:del(section, "dns")
end

mac = s:option(Value, "mac", translate("<abbr title=\"Media Access Control\">MAC</abbr>-Address"))
mac.datatype = "list(macaddr)"
mac.rmempty  = true

ip = s:option(Value, "ip", translate("<abbr title=\"Internet Protocol Version 4\">IPv4</abbr>-Address"))
ip.datatype = "or(ip4addr,'ignore')"

time = s:option(Value, "leasetime", translate("Lease time"))
time.rmempty  = true

hostid = s:option(Value, "hostid", translate("<abbr title=\"Internet Protocol Version 6\">IPv6</abbr>-Suffix (hex)"))

ipc.neighbors({ family = 4 }, function(n)
	if n.mac and n.dest then
		ip:value(n.dest:string())
		mac:value(n.mac, "%s (%s)" %{ n.mac, n.dest:string() })
	end
end)

function ip.validate(self, value, section)
	local m = mac:formvalue(section) or ""
	local n = name:formvalue(section) or ""
	if value and #n == 0 and #m == 0 then
		return nil, translate("One of hostname or mac address must be specified!")
	end
	return Value.validate(self, value, section)
end



