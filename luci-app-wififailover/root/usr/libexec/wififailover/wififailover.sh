#!/bin/sh 

CONFIG_FILE="/etc/config/wififailover"
LOG_FILE="/var/log/wifi_failover.log" 
CON_QUALITY=1
STA_IFACE_INDEX=1

log() {                                                                                                                                                    
    # Логирование сообщений в файл, syslog и консоль
    local message="$1"  

    echo "WIFI_Failover: $message"                                                                                                                                  
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"                                                                                          
    logger -t WIFI_Failover "$message"                                                                                                                   
}

find_sta_iface_index() {
    #находит индекс wifi-iface с режимом sta (клиентский режим):

    local index=0
    while uci -q get wireless.@wifi-iface[$index] >/dev/null; do
        if [ "$(uci -q get wireless.@wifi-iface[$index].mode)" = "sta" ]; then
            STA_IFACE_INDEX=$index
            return 0
        fi
        index=$((index + 1))
    done
    return 1
}

init_cnf() {
    # Инициализация конфигурационного файла, если он отсутствует
    if [ ! -f "$CONFIG_FILE" ]; then   
        echo "" > "$CONFIG_FILE"
        echo "config wifi 'settings'" >> "$CONFIG_FILE"  
        echo "    option check_interval '30'" >> "$CONFIG_FILE"
        echo "    option ping_target '8.8.8.8'" >> "$CONFIG_FILE"
        echo "    option current_idx 0" >> "$CONFIG_FILE"

        log "config file was create $CONFIG_FILE"
    fi
}

check_internet() {
    # Проверка доступности интернета через ping
    local ping_ok=0
    local http_ok=1

    local target=$(uci -q get $CONFIG_FILE.settings.ping_target)
    if ping -c 2 -W 3 "$target" >/dev/null 2>&1; then
        ping_ok=1
    fi

    if [ $ping_ok -eq 1 ] && [ $http_ok -eq 1 ]; then
        return 0  # Интернет есть
    else
        return 1  # Интернета нет
    fi
}


check_connection_quality() {
    local target=$(uci -q get $CONFIG_FILE.settings.ping_target)
    local ping_count=20     # Увеличим количество пакетов для лучшей статистики
    local max_packet_loss=20  # Максимально допустимые потери пакетов в %
    local max_duplicates=20   # Максимально допустимые дубликаты в %

    # Выполняем ping и получаем полную статистику
    local ping_output=$(ping -c $ping_count -q $target 2>&1)

     # Исправленное извлечение packet loss (только число)
    local packet_loss=$(echo "$ping_output" | awk -F'[, %]' '{for(i=1;i<=NF;i++) if ($i == "loss") print $(i-3)}')
    packet_loss=${packet_loss:-100}  # Если не найдено, считаем 100% потерь

    # Извлечение duplicates (только число)
    local duplicates=$(echo "$ping_output" | awk -F'[, %]' '{for(i=1;i<=NF;i++) if ($i == "duplicates") print $(i-1)}')
    duplicates=${duplicates:-0}  # Если не найдено, считаем 0 дубликатов

    if [ "$packet_loss" -gt 99 ]; then
        log "Ошибка: не удалось выполнить ping"
        return 1
    fi

    if [ "$packet_loss" -gt "$max_packet_loss" ]; then
        log "Проблема: высокая потеря пакетов (${packet_loss}% > ${max_packet_loss}%)"
        return 1
    fi

    if [ "$duplicates" -gt "$max_duplicates" ]; then
        log "Проблема: много дублирующихся пакетов (${duplicates}% > ${max_duplicates}%)"
        return 1
    fi

    return 0
}


get_current_index(){
    # Получение текущего индекса WiFi-конфигурации
    local current_idx

    current_idx=$(uci -q get $CONFIG_FILE.settings.current_idx)
    current_idx="${current_idx:-0}"
    echo "$current_idx"
}

set_current_index(){
    # Установка текущего индекса WiFi-конфигурации
    local index=$1

    $(uci set $CONFIG_FILE.settings.current_idx=$index)

}

check_exist_wifi_conf(){
    # Проверка наличия WiFi-конфигурации по индексу
    local index=$1
    local ssid

    ssid=$(uci -q get "$CONFIG_FILE.@wifi_network[$index].ssid")
    if [ -n "$ssid" ]; then
        return 0  # настройка есть
    else
        return 1  # настройки нет
    fi
}

get_next_index(){
    # Получение следующего индекса WiFi-конфигурации, сброс на 0 если не найден
    local current_idx
    local next_idx

    current_idx=$(get_current_index)
    next_idx=$((current_idx + 1))
    
    if check_exist_wifi_conf "$next_idx"; then
        set_current_index $next_idx
        echo $next_idx
    else
        set_current_index 0 
        echo 0
    fi
}

get_wifi_params() {
    # Получение параметров WiFi-сети по индексу
    local index=$1

    echo "ssid=$(uci -q get $CONFIG_FILE.@wifi_network[$index].ssid)"
    echo "bssid=$(uci -q get $CONFIG_FILE.@wifi_network[$index].bssid)"
    echo "key=$(uci -q get $CONFIG_FILE.@wifi_network[$index].key)"
    echo "encryption=$(uci -q get $CONFIG_FILE.@wifi_network[$index].encryption)"
}

switch_wifi(){
    # Переключение на следующую WiFi-сеть из конфигурации
    local next_index

    next_index=$(get_next_index)
    if ! check_exist_wifi_conf "$next_index"; then
        log "WiFi конфиг не найден, выход"
        return
    fi

    eval $(get_wifi_params $next_index)
    
    log "Переключаемся на WiFi: $ssid"
    
    uci set wireless.@wifi-iface[0].ssid="$ssid"
    uci set wireless.@wifi-iface[0].bssid="$bssid"
    uci set wireless.@wifi-iface[0].key="$key"
    uci set wireless.@wifi-iface[0].encryption="$encryption"
    uci commit wireless
    
    wifi down
    sleep 2
    wifi up
    sleep 10
}

monitoring(){
    # Основной цикл мониторинга доступности интернета и переключения WiFi
    while true; do

    if ! check_internet; then
        log "Интернет недоступен, переключаем WiFi"
        switch_wifi
    fi

    if [ $CON_QUALITY -eq 1 ]; then 
        if ! check_connection_quality; then
            log "Плохое качество соединения, переключаем WiFi"
            switch_wifi
        fi
    fi

    sleep $(uci -q get $CONFIG_FILE.settings.check_interval)
    done
}


main(){
    # Точка входа: инициализация и запуск мониторинга
    if find_sta_iface_index; then
        init_cnf
        monitoring
    else 
        log "Нет wifi-iface в режиме клиента"
        exit 0
    fi
}

main
