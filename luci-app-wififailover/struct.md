luci-app-wififailover/
    ├── Makefile                           # SDK совместимый Makefile
    ├── files/                             # Файлы для установки
    │   ├── etc/
    │   │   ├── config/
    │   │   │   └── wififailover           # UCI конфиг по умолчанию
    │   │   ├── init.d/
    │   │   │   └── wififailover           # Init скрипт
    │   │   └── uci-defaults/
    │   │       └── 99-wififailover        # UCI инициализация
    │   └── usr/
    │       ├── bin/
    │       │   └── wififailover-daemon    # Демон мониторинга
    │       └── lib/
    │           └── wififailover/
    │               └── utils.lua          # Утилиты
    └── luasrc/                           # LuCI компоненты
        ├── controller/
        │   └── wififailover.lua          # Контроллер
        └── model/
            └── cbi/
                └── wififailover/
                    ├── config.lua        # Настройки
                    └── status.lua        # Статус