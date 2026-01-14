#!/bin/bash
#
# ============================================================================
# 本地构建脚本 (LiBwrt 版本)
# ============================================================================
# 位置: op-ci 仓库根目录
# 使用: 克隆仓库后，在仓库根目录运行 ./build-local-libwrt.sh
# ============================================================================
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "🚀 LiBwrt 本地构建"
echo "========================================="

# 工作目录（仓库内的 build/libwrt 目录，避免与 immortalwrt 冲突）
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$REPO_DIR/build_libwrt"

echo "📁 仓库目录: $REPO_DIR"
echo "📁 工作目录: $WORK_DIR"
echo ""

# 设置环境变量（LiBwrt）
export REPO_URL="https://github.com/LiBwrt/openwrt-6.x"
export REPO_BRANCH="kernel-6.12"
export CONFIG_FILE="seed.config"
export TZ="Asia/Shanghai"

# 解决 Git 目录所有权安全报错
git config --global --add safe.directory "*"

mkdir -p "$WORK_DIR"

# 步骤 1: 安装依赖
echo "🔧 步骤 1: 安装系统依赖"
echo "⚠️  需要 sudo 权限"
read -p "是否安装依赖？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh | sudo bash
fi

# 步骤 1.5: 检查并配置 Go 环境 (用于编译 v2dat)
# ------------------------------------------------------------------------
echo ""
echo "🔧 步骤 1.5: 配置 Go 编译环境 (v2dat 需要)"
if ! command -v go &> /dev/null; then
    echo "  ⚠️  未检测到 Go，正在自动下载 Go 1.22..."
    mkdir -p "$WORK_DIR/go_toolchain"
    # 下载 Go (中国大陆使用镜像，或者官方源)
    curl -L "https://go.dev/dl/go1.22.5.linux-amd64.tar.gz" -o "$WORK_DIR/go.tar.gz"
    tar -xzf "$WORK_DIR/go.tar.gz" -C "$WORK_DIR/go_toolchain"
    export PATH="$WORK_DIR/go_toolchain/go/bin:$PATH"
    export GOROOT="$WORK_DIR/go_toolchain/go"
    rm "$WORK_DIR/go.tar.gz"
    echo "  ✅ Go 环境配置完成: $(go version)"
else
    echo "  ✅ 检测到 Go 环境: $(go version)"
fi
# 设置 Go 代理 (防止本地网络拉取失败)
export GOPROXY=https://goproxy.io,direct

# 步骤 2: 克隆源码
cd "$WORK_DIR"
if [ ! -d "openwrt" ]; then
    echo ""
    echo "📦 步骤 2: 克隆 LiBwrt 源码"
    git clone --depth=1 --single-branch --branch $REPO_BRANCH $REPO_URL openwrt
fi

cd openwrt

# 步骤 3: 准备软件包环境
echo ""
echo "📦 步骤 3: 准备软件包环境 (Feeds & Custom Plugins)"
bash "$REPO_DIR/scripts/03-prepare-packages.sh"

# 步骤 5: 清理冲突
echo ""
echo "🧹 步骤 5: 清理冲突插件"
bash "$REPO_DIR/scripts/04-clean-conflicts.sh"

# 步骤 6: 安装 Feeds
echo ""
echo "📥 步骤 6: 安装 Feeds"
bash "$REPO_DIR/scripts/install-feeds.sh"

# 步骤 7: 加载配置
echo ""
echo "⚙️  步骤 7: 加载配置文件"
# 使用加载配置脚本（包含 APK/OPKG 处理）
export GITHUB_WORKSPACE="$REPO_DIR" # 模拟 GitHub Workspace
bash "$REPO_DIR/scripts/05-load-config.sh"

# 步骤 8: 下载依赖
echo ""
echo "📥 步骤 8: 下载编译依赖"
make download -j$(nproc)

# 步骤 9: 编译
echo ""
echo "🔨 步骤 9: 编译固件（需要 1-2 小时）"
make -j$(nproc) || make -j1 V=s

# 完成
echo ""
echo "========================================="
echo -e "${GREEN}✅ 构建完成！${NC}"
echo "========================================="
echo "固件位置:"
find bin/targets -name "*.bin" -o -name "*.img.gz" 2>/dev/null | head -10
echo ""
