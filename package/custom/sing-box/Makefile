include $(TOPDIR)/rules.mk

PKG_NAME:=sing-box
PKG_VERSION:=1.13.0-beta.5
PKG_RELEASE:=1

PKG_ARCH:=aarch64
PKG_OS:=linux
PKG_ENV:=musl

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_OS)-$(PKG_ARCH)-$(PKG_ENV).tar.gz
PKG_SOURCE_URL:=https://github.com/SagerNet/sing-box/releases/download/v$(PKG_VERSION)/
PKG_HASH:=skip

include $(INCLUDE_DIR)/package.mk

define Package/sing-box
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Sing-box (Pre-compiled)
  URL:=https://sing-box.sagernet.org
  DEPENDS:=+ca-bundle +kmod-tun
  USERID:=sing-box=5566:sing-box=5566
  PROVIDES:=sing-box
endef

define Package/sing-box/description
  The universal proxy platform (Pre-compiled binary from GitHub Releases).
endef

define Package/sing-box/conffiles
/etc/sing-box/
/etc/config/sing-box
endef

define Build/Compile
	# No compilation needed for pre-compiled binary
endef

define Package/sing-box/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/sing-box $(1)/usr/bin/sing-box
	
	$(INSTALL_DIR) $(1)/etc/sing-box
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	
	$(INSTALL_BIN) ./files/sing-box.init $(1)/etc/init.d/sing-box
	$(INSTALL_CONF) ./files/sing-box.conf $(1)/etc/config/sing-box
endef

$(eval $(call BuildPackage,sing-box))
