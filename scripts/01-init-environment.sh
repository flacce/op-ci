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

# 使用 ImmortalWrt 官方提供的初始化脚本
echo "[1/3] 使用官方脚本安装编译依赖..."
sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'


# 设置系统时区
echo "[2/3] 设置时区为 Asia/Shanghai..."
sudo timedatectl set-timezone "${TZ:-Asia/Shanghai}"

# 创建工作目录并授权给当前用户
echo "[3/3] 创建工作目录 /workdir..."
sudo mkdir -p /workdir
sudo chown $USER:$USER /workdir

echo "✅ 环境初始化完成！"

