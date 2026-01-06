#!/bin/bash
#
# ============================================================================
# 脚本名称: 03.5-clone-plugins.sh
# 功能描述: 从 GitHub 克隆第三方插件
# ============================================================================
# 作用:
#   从 GitHub 克隆最新的第三方插件到 package 目录
#   包括: Lucky、HomeProxy、AdGuardHome 等
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "📦 克隆第三方插件..."
echo "========================================="

# 进入 OpenWrt 源码目录
cd openwrt

# 创建第三方插件目录
mkdir -p package/custom

# ----------------------------------------------------------------------------
# 克隆第三方插件
# ----------------------------------------------------------------------------

echo "[1/4] 克隆 Lucky（综合工具箱）..."
if [ -d "package/custom/luci-app-lucky" ]; then
    rm -rf package/custom/luci-app-lucky
fi
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/custom/luci-app-lucky

echo "[2/4] 克隆 HomeProxy（代理管理）..."
if [ -d "package/custom/homeproxy" ]; then
    rm -rf package/custom/homeproxy
fi
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy.git package/custom/homeproxy

echo "[3/4] 克隆 AdGuardHome（广告拦截）..."
if [ -d "package/custom/luci-app-adguardhome" ]; then
    rm -rf package/custom/luci-app-adguardhome
fi
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/custom/luci-app-adguardhome

echo "[4/5] 克隆 EasyTier（组网工具）..."
if [ -d "package/custom/luci-app-easytier" ]; then
    rm -rf package/custom/luci-app-easytier
fi
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier.git package/custom/luci-app-easytier

echo "[5/5] 克隆 Aurora 主题..."
if [ -d "package/custom/luci-theme-aurora" ]; then
    rm -rf package/custom/luci-theme-aurora
fi
git clone --depth=1 https://github.com/kenzok78/luci-theme-aurora.git package/custom/luci-theme-aurora

echo "✅ 第三方插件克隆完成！"
