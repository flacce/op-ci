include $(TOPDIR)/rules.mk

PKG_NAME:=mosdns
PKG_VERSION:=5.3.3
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-linux-arm64.zip
PKG_SOURCE_URL:=https://github.com/IrineSistiana/mosdns/releases/download/v$(PKG_VERSION)/
PKG_HASH:=skip

include $(INCLUDE_DIR)/package.mk

define Package/mosdns
  SECTION:=net
  CATEGORY:=Network
  TITLE:=MosDNS (Pre-compiled)
  URL:=https://github.com/IrineSistiana/mosdns
  DEPENDS:=@(aarch64) +ca-bundle
endef

define Package/mosdns/description
  MosDNS is a DNS proxy server. (Pre-compiled binary from GitHub Releases)
endef

define Build/Compile
	# Binary download, no compile
endef

define Package/mosdns/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/mosdns
	$(INSTALL_DIR) $(1)/etc/init.d
	
	unzip -o $(DL_DIR)/$(PKG_SOURCE) -d $(PKG_BUILD_DIR)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mosdns $(1)/usr/bin/mosdns
	
	# 如果有默认配置和启动脚本，从 files 目录安装
	# 注意：sbwml 的 luci-app-mosdns 通常自带了 init 脚本，这里我们可能只需要提供二进制
	# 但为了保险，我们提供一个基础的 init 脚本，如果 luci-app 覆盖了它也没关系
	$(INSTALL_BIN) ./files/mosdns.init $(1)/etc/init.d/mosdns
endef

$(eval $(call BuildPackage,mosdns))
