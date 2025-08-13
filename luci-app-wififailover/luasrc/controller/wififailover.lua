module("luci.controller.wififailover", package.seeall)

function index()
    entry({"admin", "network", "wififailover"}, cbi("wififailover/settings"), _("WiFi Failover"), 60)
end
