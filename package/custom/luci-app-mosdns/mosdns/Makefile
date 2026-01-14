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

define Build/Prepare
	# 手动解压到构建目录
	mkdir -p $(PKG_BUILD_DIR)
	unzip -o $(DL_DIR)/$(PKG_SOURCE) -d $(PKG_BUILD_DIR)
	# 赋予执行权限
	chmod +x $(PKG_BUILD_DIR)/mosdns
endef

define Build/Compile
	# Binary download, no compile
endef

define Package/mosdns/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/mosdns
	$(INSTALL_DIR) $(1)/etc/init.d
	
	# 从构建目录复制
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mosdns $(1)/usr/bin/mosdns
	$(INSTALL_BIN) ./files/mosdns.init $(1)/etc/init.d/mosdns
endef

$(eval $(call BuildPackage,mosdns))
