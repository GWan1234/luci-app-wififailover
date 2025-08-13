# Makefile для luci-app-wififailover (LEDE SDK 17.01.7)

include $(TOPDIR)/rules.mk

LUCI_TITLE:=WiFi Failover
LUCI_DESCRIPTION:=Automatic WiFi network switching on internet connection loss
LUCI_DEPENDS:=+rpcd +iw +luci-base
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-wififailover
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=WiFi Failover Team <team@wififailover.org>

include $(TOPDIR)/feeds/luci/luci.mk


# Установка init-скрипта с правами на исполнение
define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/wififailover $(1)/etc/init.d/wififailover
	$(INSTALL_DIR) $(1)/usr/libexec/wififailover/
	$(INSTALL_BIN) ./root/usr/libexec/wififailover/wififailover $(1)/usr/libexec/wififailover/wififailover
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_BIN) ./root/etc/config/wififailover $(1)/etc/config/wififailover
endef

# Компиляция не требуется для LuCI приложения
$(eval $(call BuildPackage,$(PKG_NAME)))