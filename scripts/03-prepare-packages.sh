#!/bin/bash
#
# ============================================================================
# 脚本名称: 03-prepare-packages.sh
# 功能描述: 准备软件包环境（更新 Feeds、克隆插件、修复代码）
# ============================================================================
# 整合了原来的:
#   - Feeds 更新
#   - 03.5-clone-plugins.sh
#   - 03.6-fix-makefiles.sh
# ============================================================================
#

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}📦 步骤 3: 准备软件包环境${NC}"
echo -e "${BLUE}=========================================${NC}"

# 智能检测 OpenWrt 目录
if [ -d "openwrt" ]; then
    cd openwrt
    echo "📂 进入 openwrt 目录"
elif [ -f "feeds.conf.default" ]; then
    echo "📂 当前已在 openwrt 目录"
else
    # 尝试在 build/openwrt 查找 (适配本地构建)
    if [ -d "build/openwrt" ]; then
        cd build/openwrt
        echo "📂 进入 build/openwrt 目录"
    fi
fi

# ============================================================================
# [1/3] 更新 Feeds
# ============================================================================
echo ""
echo -e "${GREEN}[1/3] 更新官方 Feeds...${NC}"
./scripts/feeds update -a

# ============================================================================
# [2/3] 克隆第三方插件
# ============================================================================
echo ""
echo -e "${GREEN}[2/3] 克隆第三方插件...${NC}"
mkdir -p package/custom

# 清理旧目录
for plugin in "luci-app-lucky" "homeproxy" "luci-app-easytier" "luci-theme-aurora" "sing-box" "luci-app-athena-led"; do
    [ -d "package/custom/$plugin" ] && rm -rf "package/custom/$plugin"
done

# 克隆插件
echo "  -> Lucky (综合工具箱)..."
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/custom/luci-app-lucky

echo "  -> HomeProxy (代理管理)..."
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy.git package/custom/homeproxy


echo "  -> EasyTier (虚拟组网)..."
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier.git package/custom/luci-app-easytier

echo "  -> Athena LED (雅典娜呼吸灯)..."
git clone --depth=1 https://github.com/NemoAlex/luci-app-athena-led.git package/custom/luci-app-athena-led

echo "  -> Aurora (现代化主题)..."
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora.git package/custom/luci-theme-aurora

echo "  -> sing-box (核心组件)..."
# 使用 sparse-checkout 只获取包定义
mkdir -p package/custom/sing-box
pushd package/custom/sing-box > /dev/null
git init
git remote add origin https://github.com/openwrt/packages.git
git config core.sparseCheckout true
echo "net/sing-box/*" >> .git/info/sparse-checkout
git pull --depth=1 origin master
mv net/sing-box/* .
rm -rf net .git
popd > /dev/null

echo "✅ 插件克隆完成"

# ============================================================================
# [3/3] 修复 Makefile
# ============================================================================
echo ""
echo -e "${GREEN}[3/3] 修复 Makefile 问题...${NC}"

# --- sing-box 修复 ---
SINGBOX_MAKEFILE="package/custom/sing-box/Makefile"
if [ -f "$SINGBOX_MAKEFILE" ]; then
    echo "  🔧 修复 sing-box..."
    
    # 备份原文件
    cp "$SINGBOX_MAKEFILE" "$SINGBOX_MAKEFILE.bak"
    
    # 重写 Makefile
    echo "  🔄 重写 Makefile 以适配..."
    
    # 1. 写入头部
    cat <<EOF > "$SINGBOX_MAKEFILE"
include \$(TOPDIR)/rules.mk

EOF
    # 2. 提取变量定义 (PKG_*, GO_*)
    grep -E "^(PKG_|GO_)" "$SINGBOX_MAKEFILE.bak" | grep -v "GO_PKG_TAGS" >> "$SINGBOX_MAKEFILE"
    
    # 3. 写入主体
    cat <<EOF >> "$SINGBOX_MAKEFILE"

include \$(INCLUDE_DIR)/package.mk
include \$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/sing-box
  TITLE:=The universal proxy platform
  SECTION:=net
  CATEGORY:=Network
  URL:=https://sing-box.sagernet.org
  DEPENDS:=\$(GO_ARCH_DEPENDS) +ca-bundle +kmod-inet-diag +kmod-tun
  USERID:=sing-box=5566:sing-box=5566
  TITLE+= (tiny)
  VARIANT:=tiny
endef

define Package/sing-box/description
  Sing-box is a universal proxy platform which supports hysteria, SOCKS, Shadowsocks,
  ShadowTLS, Tor, trojan, VLess, VMess, WireGuard and so on.
endef

define Package/sing-box/conffiles
/etc/config/sing-box
/etc/sing-box/
endef

define Package/sing-box/install
	\$(INSTALL_DIR) \$(1)/usr/bin/
	\$(INSTALL_BIN) \$(GO_PKG_BUILD_BIN_DIR)/sing-box \$(1)/usr/bin/sing-box

	\$(INSTALL_DIR) \$(1)/etc/sing-box
	\$(INSTALL_DATA) \$(PKG_BUILD_DIR)/release/config/config.json \$(1)/etc/sing-box

	\$(INSTALL_DIR) \$(1)/etc/config/
	\$(INSTALL_CONF) ./files/sing-box.conf \$(1)/etc/config/sing-box
	\$(INSTALL_DIR) \$(1)/etc/init.d/
	\$(INSTALL_BIN) ./files/sing-box.init \$(1)/etc/init.d/sing-box
endef

GO_PKG_TAGS:=with_quic,with_utls,with_clash_api
ifndef CONFIG_SMALL_FLASH
  GO_PKG_TAGS:=with_gvisor,\$(GO_PKG_TAGS)
endif

\$(eval \$(call BuildPackage,sing-box))
EOF
    
else
    echo "  ⚠️  sing-box Makefile 未找到"
fi

# --- homeproxy 修复 ---
HOMEPROXY_MAKEFILE="package/custom/homeproxy/Makefile"
if [ -f "$HOMEPROXY_MAKEFILE" ]; then
    echo "  🔧 修复 homeproxy..."
    # 移除依赖 +sing-box (避免 select)
    sed -i '/^\s*+sing-box/d' "$HOMEPROXY_MAKEFILE"
    # 手动定义 Package (使用 DEPENDS)
    sed -i '/^include $(TOPDIR)\/feeds\/luci\/luci.mk/i \
define Package/$(PKG_NAME)\
  SECTION:=luci\
  CATEGORY:=LuCI\
  SUBMENU:=3. Applications\
  TITLE:=$(LUCI_TITLE)\
  PKGARCH:=$(LUCI_PKGARCH)\
  DEPENDS:=+sing-box +firewall4 +kmod-nft-tproxy +ucode-mod-digest\
endef\
' "$HOMEPROXY_MAKEFILE"
else
    echo "  ⚠️  homeproxy Makefile 未找到"
fi

echo ""
echo -e "${GREEN}✅ 所有准备工作完成！${NC}"
echo ""
