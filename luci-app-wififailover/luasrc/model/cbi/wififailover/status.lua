<%+header%>
<script>
let timer;
const ids = ['service-status','daemon-status','current-network','internet-status'];
const classes = {
    service: ['status-enabled','status-disabled'],
    daemon: ['status-running','status-stopped'],
    internet: ['status-connected','status-disconnected']
};
function set(id, html, cls) {
    let e = document.getElementById(id);
    if (e) { e.innerHTML = html; if (cls) e.className = cls; }
}
function updateStatus() {
    XHR.get('<%=REQUEST_URI%>', null, (_, d) => {
        if (!d) return;
        set('service-status', d.settings.enabled ? '<%:Enabled%>' : '<%:Disabled%>', classes.service[+!d.settings.enabled]);
        let ds = d.daemon, dsTxt = ds.running ? '<%:Running%>' : '<%:Stopped%>';
        if (ds.pid) dsTxt += ` (PID: ${ds.pid})`;
        set('daemon-status', dsTxt, classes.daemon[+!ds.running]);
        let nw = d.current_wifi, nwTxt = nw.ssid || '<%:Not connected%>';
        if (nw.signal && nw.ssid !== 'Not connected') nwTxt += ` (${nw.signal} dBm, ${nw.quality}%)`;
        set('current-network', nwTxt);
        let inet = d.internet, inetTxt = inet.connected ? '<%:Connected%>' : '<%:Disconnected%>';
        set('internet-status', inetTxt + ` (${inet.host})`, classes.internet[+!inet.connected]);
    });
}
function btn(id, txt, dis) { let b=document.getElementById(id); b.disabled=dis; b.value=txt; }
function testConnection() {
    btn('test-button','<%:Testing...%>',1);
    XHR.get('<%=url("admin/services/wififailover/test_connection")%>',null,(_,d)=>{
        btn('test-button','<%:Test Connection%>',0);
        alert(d&&d.success?`<%:Connection test successful%> (${d.response_time}s)`:'<%:Connection test failed%>');
    });
}
function scanWiFi() {
    btn('scan-button','<%:Scanning...%>',1);
    XHR.get('<%=url("admin/services/wififailover/scan")%>',null,(_,d)=>{
        btn('scan-button','<%:Scan Networks%>',0);
        if(d&&d.success) showScanResults(d.networks); else alert('<%:WiFi scan failed%>');
    });
}
function showScanResults(nw) {
    let html = `<h3><%:Available Networks%></h3><table><tr><th><%:SSID%></th><th><%:Signal%></th><th><%:Quality%></th><th><%:Action%></th></tr>`;
    nw.forEach(n=>{html+=`<tr><td>${n.ssid}</td><td>${n.signal} dBm</td><td>${n.quality}%</td><td><input type="button" value="<%:Connect%>" onclick="switchNetwork('${n.ssid}')"></td></tr>`});
    html+='</table>'; document.getElementById('scan-results').innerHTML=html;
}
function switchNetwork(ssid) {
    if(!confirm(`<%:Switch to network%> "${ssid}"?`))return;
    XHR.post('<%=url("admin/services/wififailover/switch_network")%>','ssid='+encodeURIComponent(ssid),(_,d)=>{
        alert(d&&d.success?'<%:Network switch initiated%>. <%:Please wait for connection...%>':`<%:Network switch failed%>: ${d.error||'<%:Unknown error%>'}`);
        if(d&&d.success) setTimeout(updateStatus,5000);
    });
}
function toggleAutoRefresh() {
    let c=document.getElementById('auto-refresh');
    if(c.checked) timer=setInterval(updateStatus,1e4); else if(timer) clearInterval(timer);
}
document.addEventListener('DOMContentLoaded',()=>{
    updateStatus();
    document.getElementById('auto-refresh').checked=1;
    toggleAutoRefresh();
});
</script>
<style>
.status-enabled,.status-running{color:#0f0;font-weight:bold;}
.status-disabled{color:#999;}
</style>