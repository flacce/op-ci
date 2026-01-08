#!/bin/bash
#
# ============================================================================
# 脚本名称: 03.6-fix-makefiles.sh
# 功能描述: 修复 sing-box 和 homeproxy 的 Makefile 问题
# ============================================================================
# 作用:
#   1. 修复 sing-box Makefile（路径、循环依赖）
#   2. 修复 homeproxy Makefile（循环依赖）
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "🔧 修复 Makefile 文件..."
echo "========================================="

# 智能检测当前目录
if [ -f "package/custom/sing-box/Makefile" ]; then
    OPENWRT_DIR="."
elif [ -f "openwrt/package/custom/sing-box/Makefile" ]; then
    OPENWRT_DIR="openwrt"
elif [ -f "build/openwrt/package/custom/sing-box/Makefile" ]; then
    OPENWRT_DIR="build/openwrt"
else
    echo "⚠️  未找到目标 Makefile，跳过修复"
    exit 0
fi

# ============================================================================
# 第一部分：修复 sing-box Makefile
# ============================================================================
SINGBOX_MAKEFILE="$OPENWRT_DIR/package/custom/sing-box/Makefile"

if [ -f "$SINGBOX_MAKEFILE" ]; then
    echo "[1/2] 修复 sing-box Makefile..."
    
    # 1. 移除 sing-box full 版本的定义
    sed -i '/^define Package\/sing-box$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    sed -i '/^define Package\/sing-box\/description$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    sed -i '/^define Package\/sing-box\/config$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    
    # 2. 将 sing-box-tiny 重命名为 sing-box
    sed -i 's/Package\/sing-box-tiny/Package\/sing-box/g' "$SINGBOX_MAKEFILE"
    sed -i 's/BuildPackage,sing-box-tiny/BuildPackage,sing-box/g' "$SINGBOX_MAKEFILE"
    
    # 3. 移除 PROVIDES 和 CONFLICTS
    sed -i 's/PROVIDES:=sing-box/# PROVIDES:=sing-box/' "$SINGBOX_MAKEFILE"
    sed -i 's/CONFLICTS:=sing-box/# CONFLICTS:=sing-box/' "$SINGBOX_MAKEFILE"
    
    # 4. 移除重复的 BuildPackage 调用
    sed -i '/$(eval $(call BuildPackage,sing-box-tiny))$/d' "$SINGBOX_MAKEFILE"
    
    # 5. 修复 golang-package.mk 路径
    sed -i 's|include ../../lang/golang/golang-package.mk|include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|' "$SINGBOX_MAKEFILE"
    
    # 6. 修复 description 自引用问题
    sed -i '/^Package\/sing-box\/description:=$(Package\/sing-box\/description)$/d' "$SINGBOX_MAKEFILE"
    
    echo "  ✅ sing-box Makefile 修复完成"
else
    echo "  ⚠️  未找到 sing-box Makefile"
fi

# ============================================================================
# 第二部分：修复 homeproxy Makefile
# ============================================================================
HOMEPROXY_MAKEFILE="$OPENWRT_DIR/package/custom/homeproxy/Makefile"

if [ -f "$HOMEPROXY_MAKEFILE" ]; then
    echo "[2/2] 修复 homeproxy Makefile..."
    
    # 1. 从 LUCI_DEPENDS 移除 +sing-box（避免自动生成 select）
    sed -i '/^\s*+sing-box/d' "$HOMEPROXY_MAKEFILE"
    
    # 2. 在 include luci.mk 前插入手动 Package 定义
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
    
    echo "  ✅ homeproxy Makefile 修复完成"
else
    echo "  ⚠️  未找到 homeproxy Makefile"
fi

echo ""
echo "✅ 所有 Makefile 修复完成！"
echo ""
