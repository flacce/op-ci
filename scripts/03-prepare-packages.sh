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
for plugin in "luci-app-lucky" "homeproxy" "luci-app-adguardhome" "luci-app-easytier" "luci-theme-aurora" "sing-box"; do
    [ -d "package/custom/$plugin" ] && rm -rf "package/custom/$plugin"
done

# 克隆插件
echo "  -> Lucky (综合工具箱)..."
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/custom/luci-app-lucky

echo "  -> HomeProxy (代理管理)..."
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy.git package/custom/homeproxy

echo "  -> AdGuardHome (广告拦截)..."
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/custom/luci-app-adguardhome

echo "  -> EasyTier (虚拟组网)..."
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier.git package/custom/luci-app-easytier

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
    # 移除 full/config 定义
    sed -i '/^define Package\/sing-box$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    sed -i '/^define Package\/sing-box\/description$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    sed -i '/^define Package\/sing-box\/config$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    # 重命名 tiny -> sing-box
    sed -i 's/Package\/sing-box-tiny/Package\/sing-box/g' "$SINGBOX_MAKEFILE"
    sed -i 's/BuildPackage,sing-box-tiny/BuildPackage,sing-box/g' "$SINGBOX_MAKEFILE"
    # 移除 CONFLICTS
    sed -i 's/PROVIDES:=sing-box/# PROVIDES:=sing-box/' "$SINGBOX_MAKEFILE"
    sed -i 's/CONFLICTS:=sing-box/# CONFLICTS:=sing-box/' "$SINGBOX_MAKEFILE"
    # 移除重复 BuildPackage
    sed -i '/$(eval $(call BuildPackage,sing-box-tiny))$/d' "$SINGBOX_MAKEFILE"
    # 修复路径
    sed -i 's|include ../../lang/golang/golang-package.mk|include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|' "$SINGBOX_MAKEFILE"
    # 修复自引用描述
    sed -i '/^Package\/sing-box\/description:=$(Package\/sing-box\/description)$/d' "$SINGBOX_MAKEFILE"
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
