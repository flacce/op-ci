#!/bin/bash
#
# ============================================================================
# 本地构建脚本
# ============================================================================
# 位置: op-ci 仓库根目录
# 使用: 克隆仓库后，在仓库根目录运行 ./build-local.sh
# ============================================================================
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "🚀 ImmortalWrt 本地构建"
echo "========================================="

# 工作目录（仓库所在目录的上级）
WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)/immortalwrt-build"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📁 仓库目录: $REPO_DIR"
echo "📁 工作目录: $WORK_DIR"
echo ""

# 设置环境变量（本地环境）
export REPO_URL="https://github.com/immortalwrt/immortalwrt"
export REPO_BRANCH="master"
export CONFIG_FILE="seed.config"
export TZ="Asia/Shanghai"

mkdir -p "$WORK_DIR"

# 步骤 1: 安装依赖
echo "🔧 步骤 1: 安装系统依赖"
echo "⚠️  需要 sudo 权限"
read -p "是否安装依赖？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh | sudo bash
fi

# 步骤 2: 克隆源码
cd "$WORK_DIR"
if [ ! -d "openwrt" ]; then
    echo ""
    echo "📦 步骤 2: 克隆 ImmortalWrt 源码"
    git clone --depth=1 --single-branch --branch $REPO_BRANCH $REPO_URL openwrt
fi

cd openwrt

# 步骤 3: 更新 Feeds
echo ""
echo "🔄 步骤 3: 更新 Feeds"
./scripts/feeds update -a

# 步骤 4: 克隆第三方插件
echo ""
echo "📦 步骤 4: 克隆第三方插件"
mkdir -p package/custom

for plugin in "luci-app-lucky" "homeproxy" "luci-app-adguardhome" "luci-app-easytier" "luci-theme-aurora" "sing-box"; do
    [ -d "package/custom/$plugin" ] && rm -rf "package/custom/$plugin"
done

git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/custom/luci-app-lucky
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy.git package/custom/homeproxy
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/custom/luci-app-adguardhome
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier.git package/custom/luci-app-easytier
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora.git package/custom/luci-theme-aurora
git clone --depth=1 https://github.com/SagerNet/sing-box.git package/custom/sing-box

# 步骤 5: 清理冲突
echo ""
echo "🧹 步骤 5: 清理冲突插件"
find feeds/ -name "sing-box" -o -name "adguardhome" -o -name "luci-app-adguardhome" | xargs rm -rf 2>/dev/null || true
./scripts/feeds update -i

# 步骤 6: 安装 Feeds
echo ""
echo "📥 步骤 6: 安装 Feeds"
./scripts/feeds install -a

# 步骤 7: 加载配置
echo ""
echo "⚙️  步骤 7: 加载配置文件"
cp "$REPO_DIR/$CONFIG_FILE" .config
make defconfig

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
find bin/targets -name "*.bin" -o -name "*.img" 2>/dev/null | head -10
echo ""
