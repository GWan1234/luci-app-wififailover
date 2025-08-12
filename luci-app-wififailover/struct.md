luci-app-wififailover/
├── Makefile
├── root/
│   ├── usr/
│   │   ├── libexec/
│   │   │   └── wififailover/
│   │   │       └── wififailover.sh
│   │   └── share/
│   │       └── rpcd/
│   │           └── acl.d/
│   │               └── luci-app-wififailover.json
│   └── etc/
│       ├── config/
│       │   └── wififailover
│       ├── init.d/
│       │   └── wififailover
│       └── uci-defaults/
│           └── luci-wififailover
└── luasrc/
    ├── controller/
    │   └── wififailover.lua
    └── model/
        └── cbi/
            └── wififailover/
                └── settings.lua