#!/bin/bash
#
# ============================================================================
# 脚本名称: 03.6-update-singbox.sh
# 功能描述: 更新 feeds 中的 sing-box 到最新版本
# ============================================================================
# 作用:
#   自动获取 sing-box 最新版本，更新 Makefile
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "📦 更新 sing-box 到最新版本..."
echo "========================================="

# 进入 OpenWrt 源码目录
cd openwrt

# 查找 sing-box 的 Makefile
SINGBOX_MAKEFILE=$(find feeds/packages -name "Makefile" -path "*/sing-box/Makefile" | head -1)

if [ -z "$SINGBOX_MAKEFILE" ]; then
    echo "⚠️  未找到 sing-box Makefile，跳过更新"
    exit 0
fi

echo "📄 找到 Makefile: $SINGBOX_MAKEFILE"

# 获取最新版本（包括预览版）
echo "🔍 获取最新版本..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases | grep '"tag_name"' | head -1 | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "❌ 无法获取最新版本，使用 feeds 默认版本"
    exit 0
fi

echo "✅ 最新版本: v$LATEST_VERSION"

# 更新 Makefile
echo "📝 更新 Makefile..."
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$LATEST_VERSION/" "$SINGBOX_MAKEFILE"
sed -i "s/PKG_HASH:=.*/PKG_HASH:=skip/" "$SINGBOX_MAKEFILE"

echo "✅ sing-box 已更新到 v$LATEST_VERSION（跳过哈希验证）"
echo ""
