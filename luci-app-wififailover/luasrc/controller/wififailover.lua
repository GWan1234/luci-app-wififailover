module("luci.controller.wififailover", package.seeall)

function index()
    entry({"admin", "network", "wififailover"}, cbi("wififailover/settings"), _("WiFi Failover"), 60)
    entry({"admin", "network", "wififailover", "toggle"}, call("action_toggle")).leaf = true
end


function action_toggle()
    local http = require "luci.http"
    local util = require "luci.util"

    local action = http.formvalue("action")
    if action == "start" then
        util.exec("/etc/init.d/wififailover start")
    elseif action == "stop" then
        util.exec("/etc/init.d/wififailover stop")
    end

    http.redirect(luci.dispatcher.build_url("admin/network/wififailover"))
end