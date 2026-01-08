#!/bin/bash
#
# ============================================================================
# 脚本名称: 03.7-fix-homeproxy.sh
# 功能描述: 修复 homeproxy Makefile 的循环依赖
# ============================================================================
# 作用:
#   修改 homeproxy Makefile，避免 LUCI_DEPENDS 自动生成 select 语句
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "🔧 修复 homeproxy Makefile..."
echo "========================================="

# 智能检测当前目录
if [ -f "package/custom/homeproxy/Makefile" ]; then
    OPENWRT_DIR="."
elif [ -f "openwrt/package/custom/homeproxy/Makefile" ]; then
    OPENWRT_DIR="openwrt"
elif [ -f "build/openwrt/package/custom/homeproxy/Makefile" ]; then
    OPENWRT_DIR="build/openwrt"
else
    echo "⚠️  未找到 homeproxy Makefile，跳过修复"
    exit 0
fi

MAKEFILE="$OPENWRT_DIR/package/custom/homeproxy/Makefile"

echo "📝 修改 sing-box 依赖方式（避免自动生成 select）..."

# 1. 从 LUCI_DEPENDS 中移除 +sing-box（避免自动 select）
sed -i '/^\s*+sing-box/d' "$MAKEFILE"

# 2. 在 Package 定义中手动添加 DEPENDS（只依赖，不 select）
# 找到 include $(TOPDIR)/feeds/luci/luci.mk 这一行，在它前面插入依赖定义
sed -i '/^include $(TOPDIR)\/feeds\/luci\/luci.mk/i \
define Package/$(PKG_NAME)\
  SECTION:=luci\
  CATEGORY:=LuCI\
  SUBMENU:=3. Applications\
  TITLE:=$(LUCI_TITLE)\
  PKGARCH:=$(LUCI_PKGARCH)\
  DEPENDS:=+sing-box +firewall4 +kmod-nft-tproxy +ucode-mod-digest\
endef\
' "$MAKEFILE"

echo "✅ homeproxy Makefile 修复完成！"
echo ""
