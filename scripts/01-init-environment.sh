#!/bin/bash
#
# ============================================================================
# 脚本名称: 01-init-environment.sh
# 功能描述: 初始化 OpenWrt 编译环境
# ============================================================================
# 作用:
#   1. 使用 ImmortalWrt 官方提供的初始化脚本
#   2. 自动安装所有编译依赖
#   3. 设置时区
#   4. 创建工作目录
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "🔧 初始化编译环境..."
echo "========================================="

# 🧹 清理磁盘空间（GitHub Actions 默认环境有很多无用的大型工具）
echo "[1/4] 清理磁盘空间，释放存储..."
echo "清理前磁盘使用情况:"
df -h

# 删除 GitHub Actions 默认安装的大型工具包
sudo rm -rf /usr/share/dotnet
sudo rm -rf /usr/local/lib/android
sudo rm -rf /opt/ghc
sudo rm -rf /opt/hostedtoolcache/CodeQL
sudo rm -rf /usr/local/share/boost
sudo rm -rf /usr/share/swift
sudo rm -rf /usr/local/.ghcup
sudo rm -rf /usr/local/share/powershell
sudo rm -rf /usr/local/share/chromium
sudo rm -rf /usr/local/lib/node_modules
sudo rm -rf /opt/az

# 清理 Docker 镜像
docker rmi $(docker images -q) 2>/dev/null || true

# 清理 apt 缓存
sudo apt-get clean

echo "清理后磁盘使用情况:"
df -h

# 使用 ImmortalWrt 官方提供的初始化脚本
echo "[2/4] 使用官方脚本安装编译依赖..."
sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'

# 补充安装 jq (解决 luci-app-advanced-reboot 等插件的构建依赖警告)
echo "[2.5/4] 补充安装 jq 工具..."
sudo apt-get update && sudo apt-get install -y jq


# 设置系统时区
echo "[3/4] 设置时区为 Asia/Shanghai..."
sudo timedatectl set-timezone "${TZ:-Asia/Shanghai}"

# 创建工作目录并授权给当前用户
echo "[4/4] 创建工作目录 /workdir..."
sudo mkdir -p /workdir
sudo chown $USER:$USER /workdir

echo "✅ 环境初始化完成！"

