<%#
Файл: luasrc/view/wififailover/status.htm
Шаблон страницы статуса WiFi Failover (LEDE 17.01.7)
-%>

<%+header%>

<script type="text/javascript">
//<![CDATA[
    var updateTimer;
    
    function updateStatus() {
        XHR.get('<%=REQUEST_URI%>', null, function(xhr, data) {
            if (data) {
                updateStatusDisplay(data);
            }
        });
    }
    
    function updateStatusDisplay(data) {
        // Обновление статуса службы
        var serviceStatus = document.getElementById('service-status');
        if (serviceStatus) {
            serviceStatus.className = data.settings.enabled ? 'status-enabled' : 'status-disabled';
            serviceStatus.innerHTML = data.settings.enabled ? '<%:Enabled%>' : '<%:Disabled%>';
        }
        
        // Обновление статуса демона
        var daemonStatus = document.getElementById('daemon-status');
        if (daemonStatus) {
            daemonStatus.className = data.daemon.running ? 'status-running' : 'status-stopped';
            daemonStatus.innerHTML = data.daemon.running ? '<%:Running%>' : '<%:Stopped%>';
            if (data.daemon.pid) {
                daemonStatus.innerHTML += ' (PID: ' + data.daemon.pid + ')';
            }
        }
        
        // Обновление текущей сети
        var currentNetwork = document.getElementById('current-network');
        if (currentNetwork) {
            currentNetwork.innerHTML = data.current_wifi.ssid || '<%:Not connected%>';
            if (data.current_wifi.signal && data.current_wifi.ssid !== 'Not connected') {
                currentNetwork.innerHTML += ' (' + data.current_wifi.signal + ' dBm, ' + 
                                          data.current_wifi.quality + '%)';
            }
        }
        
        // Обновление статуса интернета
        var internetStatus = document.getElementById('internet-status');
        if (internetStatus) {
            internetStatus.className = data.internet.connected ? 'status-connected' : 'status-disconnected';
            internetStatus.innerHTML = data.internet.connected ? '<%:Connected%>' : '<%:Disconnected%>';
            internetStatus.innerHTML += ' (' + data.internet.host + ')';
        }
    }
    
    function testConnection() {
        var button = document.getElementById('test-button');
        button.disabled = true;
        button.value = '<%:Testing...%>';
        
        XHR.get('<%=url("admin/services/wififailover/test_connection")%>', null, function(xhr, data) {
            button.disabled = false;
            button.value = '<%:Test Connection%>';
            
            if (data && data.success) {
                alert('<%:Connection test successful%> (' + data.response_time + 's)');
            } else {
                alert('<%:Connection test failed%>');
            }
        });
    }
    
    function scanWiFi() {
        var button = document.getElementById('scan-button');
        button.disabled = true;
        button.value = '<%:Scanning...%>';
        
        XHR.get('<%=url("admin/services/wififailover/scan")%>', null, function(xhr, data) {
            button.disabled = false;
            button.value = '<%:Scan Networks%>';
            
            if (data && data.success) {
                showScanResults(data.networks);
            } else {
                alert('<%:WiFi scan failed%>');
            }
        });
    }
    
    function showScanResults(networks) {
        var html = '<h3><%:Available Networks%></h3><table class="cbi-section-table">';
        html += '<tr class="cbi-section-table-titles"><th><%:SSID%></th><th><%:Signal%></th><th><%:Quality%></th><th><%:Action%></th></tr>';
        
        for (var i = 0; i < networks.length; i++) {
            var network = networks[i];
            html += '<tr class="cbi-section-table-row">';
            html += '<td>' + network.ssid + '</td>';
            html += '<td>' + network.signal + ' dBm</td>';
            html += '<td>' + network.quality + '%</td>';
            html += '<td><input type="button" class="cbi-button" value="<%:Connect%>" onclick="switchNetwork(\'' + network.ssid + '\')" /></td>';
            html += '</tr>';
        }
        html += '</table>';
        
        document.getElementById('scan-results').innerHTML = html;
    }
    
    function switchNetwork(ssid) {
        if (!confirm('<%:Switch to network%> "' + ssid + '"?')) {
            return;
        }
        
        XHR.post('<%=url("admin/services/wififailover/switch_network")%>', 
                 'ssid=' + encodeURIComponent(ssid), 
                 function(xhr, data) {
            if (data && data.success) {
                alert('<%:Network switch initiated%>. <%:Please wait for connection...%>');
                setTimeout(updateStatus, 5000);
            } else {
                alert('<%:Network switch failed%>: ' + (data.error || '<%:Unknown error%>'));
            }
        });
    }
    
    function toggleAutoRefresh() {
        var checkbox = document.getElementById('auto-refresh');
        if (checkbox.checked) {
            updateTimer = setInterval(updateStatus, 10000);
        } else {
            if (updateTimer) {
                clearInterval(updateTimer);
            }
        }
    }
    
    // Инициализация при загрузке страницы
    document.addEventListener('DOMContentLoaded', function() {
        updateStatus();
        document.getElementById('auto-refresh').checked = true;
        toggleAutoRefresh();
    });
//]]>
</script>

<style type="text/css">
.status-enabled { color: #0f0; font-weight: bold; }
.status-disabled { color: #999; }
.status-running { color: #0f0; font-weight: bold; }
.