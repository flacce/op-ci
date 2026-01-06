#!/bin/bash
#
# ============================================================================
# 脚本名称: 02-clone-source.sh
# 功能描述: 克隆 ImmortalWrt 源码
# ============================================================================
# 作用:
#   1. 显示当前磁盘使用情况
#   2. 克隆 ImmortalWrt 主线最新源码到 /workdir/openwrt
#   3. 创建软链接到 GitHub Workspace
# ============================================================================
# 环境变量:
#   - REPO_URL: ImmortalWrt 仓库地址
#   - REPO_BRANCH: 分支名称
#   - GITHUB_WORKSPACE: GitHub Actions 工作目录
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "📦 克隆 ImmortalWrt 源码..."
echo "========================================="

# 进入工作目录
cd /workdir

# 显示当前磁盘使用情况
echo "[1/3] 当前磁盘使用情况:"
df -hT $PWD

# 克隆 ImmortalWrt 主线最新源码（浅克隆，深度=1，节省时间和空间）
echo "[2/3] 克隆最新源码: ${REPO_URL} (${REPO_BRANCH})"
git clone --depth=1 --single-branch --branch $REPO_BRANCH $REPO_URL openwrt

# 创建软链接到 GitHub Workspace，方便后续步骤访问
if [ -n "$GITHUB_WORKSPACE" ]; then
    echo "[3/3] 创建软链接到 GitHub Workspace..."
    ln -sf /workdir/openwrt $GITHUB_WORKSPACE/openwrt
fi

echo "✅ 源码克隆完成！"

