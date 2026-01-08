#!/bin/bash
#
# ============================================================================
# 脚本名称: install-feeds.sh
# 功能描述: 安装 OpenWrt Feeds
# ============================================================================
# 作用:
#   1. 智能检测 OpenWrt 目录
#   2. 执行 ./scripts/feeds install -a
#   3. 处理可能出现的锁问题
# ============================================================================

set -e

echo "========================================="
echo "📥 安装 Feeds..."
echo "========================================="

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

# 检查 feeds 脚本是否存在
if [ ! -f "./scripts/feeds" ]; then
    echo "❌ 错误: 未找到 feeds 脚本！当前目录: $(pwd)"
    ls -la
    exit 1
fi

echo "🚀 执行 feeds install -a..."
./scripts/feeds install -a

echo "✅ Feeds 安装完成！"
echo ""
