# Makefile для luci-app-wififailover (LEDE SDK 17.01.7)
# Расположение: feeds/wififailover/luci-app-wififailover/Makefile

include $(TOPDIR)/rules.mk

LUCI_TITLE:=WiFi Failover
LUCI_DESCRIPTION:=Automatic WiFi network switching on internet connection loss
LUCI_DEPENDS:=+iw +wpad-mini +curl +luci-base
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-wififailover
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=WiFi Failover Team <team@wififailover.org>

# Для feeds репозитория не нужно указывать PKG_BUILD_DIR

include $(TOPDIR)/feeds/luci/luci.mk

# Дополнительные зависимости для runtime
define Package/$(PKG_NAME)/install
	# Вызов стандартного LuCI install
	$(call Package/luci-app-template/install,$(1))
	
	# Демон и утилиты
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/wififailover-daemon $(1)/usr/bin/
	
	# Init скрипт
	$(INSTALL_DIR) $(1)/etc/init.d  
	$(INSTALL_BIN) ./files/etc/init.d/wififailover $(1)/etc/init.d/
	
	# UCI конфигурация по умолчанию
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/wififailover $(1)/etc/config/
	
	# Библиотеки утилит
	$(INSTALL_DIR) $(1)/usr/lib/wififailover
	$(INSTALL_DATA) ./files/usr/lib/wififailover/utils.lua $(1)/usr/lib/wififailover/
	
	# UCI схема
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-wififailover $(1)/etc/uci-defaults/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	# Выполнение uci-defaults
	[ -x /etc/uci-defaults/99-wififailover ] && {
		/etc/uci-defaults/99-wififailover
		rm -f /etc/uci-defaults/99-wififailover
	}
	
	# Перезагрузка LuCI
	/etc/init.d/uhttpd restart 2>/dev/null || true
	
	# Включение сервиса
	/etc/init.d/wififailover enable 2>/dev/null || true
	
	echo "WiFi Failover installed successfully"
}
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/wififailover stop 2>/dev/null || true
	/etc/init.d/wififailover disable 2>/dev/null || true
}
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/uhttpd restart 2>/dev/null || true
	echo "WiFi Failover removed"
}
exit 0
endef

# Компиляция не требуется для LuCI приложения
$(eval $(call BuildPackage,$(PKG_NAME)))