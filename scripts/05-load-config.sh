#!/bin/bash
#
# ============================================================================
# 脚本名称: 05-load-config.sh
# 功能描述: 加载自定义配置并强制开启 APK + 核心插件
# ============================================================================
# 作用:
#   1. 将仓库中的配置文件复制到 OpenWrt 源码目录
#   2. 强制启用 APK 包管理器
#   3. 禁用旧的 OPKG 包管理器
#   4. 强制启用核心插件（双重保险）
#   5. 使用 defconfig 自动补全依赖
# ============================================================================
# 环境变量:
#   - CONFIG_FILE: 配置文件名（默认: seed.config）
#   - GITHUB_WORKSPACE: GitHub Actions 工作目录
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "⚙️ 加载配置并强制启用核心功能..."
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

# 将仓库中的配置文件复制到 OpenWrt 源码目录并重命名为 .config
CONFIG_FILE="${CONFIG_FILE:-seed.config}"
if [ -e "$GITHUB_WORKSPACE/$CONFIG_FILE" ]; then
    echo "[1/4] 加载配置文件: $CONFIG_FILE"
    cp "$GITHUB_WORKSPACE/$CONFIG_FILE" .config
else
    echo "⚠️  未找到配置文件: $CONFIG_FILE，使用默认配置"
    touch .config
fi

echo "[2/4] 强制启用 APK 包管理器..."
# 🔥 强制启用 APK 包管理器（OpenWrt 新一代包管理器）
echo "CONFIG_USE_APK=y" >> .config
# 禁用旧的 OPKG 包管理器
sed -i 's/CONFIG_USE_OPKG=y/# CONFIG_USE_OPKG is not set/g' .config

echo "[3/4] 双重保险：强制启用核心插件..."
# 🔥 双重保险：强制启用核心插件（即使配置文件里漏了也会补上）
echo "CONFIG_PACKAGE_luci-app-homeproxy=y" >> .config    # HomeProxy（代理管理）
echo "CONFIG_PACKAGE_luci-app-lucky=y" >> .config        # Lucky（综合工具箱）
echo "CONFIG_PACKAGE_luci-app-nlbwmon=y" >> .config      # 流量监控 UI
echo "CONFIG_PACKAGE_nlbwmon=y" >> .config               # 流量监控后端
echo "CONFIG_PACKAGE_luci-app-wrtbwmon=y" >> .config     # WRT 带宽监控
echo "CONFIG_PACKAGE_luci-app-adguardhome=y" >> .config  # AdGuardHome UI
echo "CONFIG_PACKAGE_adguardhome=y" >> .config           # AdGuardHome 后端

echo "[4/4] 运行 defconfig 自动补全依赖..."
# 使用 defconfig 自动补全依赖，生成最终的 .config
make defconfig

echo "✅ 配置加载完成！"

