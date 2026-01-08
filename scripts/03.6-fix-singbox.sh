#!/bin/bash
#
# ============================================================================
# 脚本名称: 03.6-fix-singbox.sh
# 功能描述: 修复 sing-box Makefile 的循环依赖问题
# ============================================================================
# 作用:
#   修改 package/custom/sing-box/Makefile，移除 full 版本
#   只保留 tiny 版本，避免 PROVIDES/CONFLICTS 循环依赖
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "🔧 修复 sing-box Makefile..."
echo "========================================="

# 进入 OpenWrt 源码目录
cd openwrt

MAKEFILE="package/custom/sing-box/Makefile"

if [ ! -f "$MAKEFILE" ]; then
    echo "⚠️  未找到 $MAKEFILE，跳过修复"
    exit 0
fi

echo "📝 移除 sing-box full 版本，只保留 tiny..."

# 1. 移除 sing-box full 版本的 Package 定义
sed -i '/^define Package\/sing-box$/,/^endef$/d' "$MAKEFILE"

# 2. 移除 sing-box full 版本的 description
sed -i '/^define Package\/sing-box\/description$/,/^endef$/d' "$MAKEFILE"

# 3. 移除 sing-box full 版本的 config 菜单
sed -i '/^define Package\/sing-box\/config$/,/^endef$/d' "$MAKEFILE"

# 4. 修改 sing-box-tiny，移除 PROVIDES 和 CONFLICTS
sed -i 's/PROVIDES:=sing-box/# PROVIDES:=sing-box/' "$MAKEFILE"
sed -i 's/CONFLICTS:=sing-box/# CONFLICTS:=sing-box/' "$MAKEFILE"

# 5. 移除 BuildPackage sing-box 调用，只保留 sing-box-tiny
sed -i '/$(eval $(call BuildPackage,sing-box))$/d' "$MAKEFILE"

# 6. 将 sing-box-tiny 重命名为 sing-box（提供兼容性）
sed -i 's/Package\/sing-box-tiny/Package\/sing-box/g' "$MAKEFILE"
sed -i 's/BuildPackage,sing-box-tiny/BuildPackage,sing-box/g' "$MAKEFILE"

echo "✅ sing-box Makefile 修复完成！"
echo ""
