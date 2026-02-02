#!/bin/bash
#
# ============================================================================
# 脚本名称: 03-prepare-packages.sh
# 功能描述: 准备软件包环境（回归稳健的源码编译模式）
# ============================================================================

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}📦 步骤 3: 准备软件包环境${NC}"
echo -e "${BLUE}=========================================${NC}"

# 智能检测 OpenWrt 目录
if [ -d "openwrt" ]; then
    cd openwrt
elif [ -d "build/openwrt" ]; then
    cd build/openwrt
fi

# ============================================================================
# 函数定义: UPDATE_PACKAGE
# ============================================================================
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_CONFLICTS=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	echo -e "\n${GREEN}Processing: $PKG_NAME ($PKG_REPO)${NC}"

	# 1. 清理冲突目录
	for NAME in "${PKG_CONFLICTS[@]}"; do
        if [ -n "$NAME" ]; then
            # 查找 feeds 中匹配的目录
            find package/ feeds/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null | while read -r DIR; do
                echo "  - Removing conflicting directory: $DIR"
                rm -rf "$DIR"
            done
        fi
	done

	# 2. 准备目标目录
    mkdir -p package/custom
    local TARGET_DIR="package/custom/$PKG_NAME"
    [ -d "$TARGET_DIR" ] && rm -rf "$TARGET_DIR"

	# 3. 克隆仓库
    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        # 模式: pkg (提取特定子目录)
        echo "  -> Cloning (Sparse)..."
        git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" "package/custom/_tmp_$REPO_NAME"
        
        echo "  -> Extracting $PKG_NAME..."
        find "package/custom/_tmp_$REPO_NAME" -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} "package/custom/" \;
        
        local EXTRACTED=$(find package/custom -maxdepth 1 -type d -iname "*$PKG_NAME*" -not -name "_tmp_*" | head -n 1)
        if [ -n "$EXTRACTED" ] && [ "$(basename "$EXTRACTED")" != "$PKG_NAME" ]; then
            mv "$EXTRACTED" "$TARGET_DIR"
        fi
        rm -rf "package/custom/_tmp_$REPO_NAME"
        
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        # 模式: name (重命名克隆的目录)
        echo "  -> Cloning & Renaming..."
        git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" "$TARGET_DIR"
        
    else
        # 模式: 普通 (直接克隆)
        echo "  -> Cloning..."
        git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" "package/custom/$REPO_NAME"
    fi
}

# ============================================================================
# [1] 更新官方 Feeds
# ============================================================================
echo -e "${GREEN}[1/3] 更新官方 Feeds...${NC}"
./scripts/feeds update -a

# ============================================================================
# [2] 安装第三方插件
# ============================================================================
echo -e "${GREEN}[2/3] 安装第三方插件...${NC}"

# Lucky (综合工具箱) - 使用官方源码编译模式
UPDATE_PACKAGE "luci-app-lucky" "gdy666/luci-app-lucky" "main" "name" "lucky"

# HomeProxy (代理管理)
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main" "name"

# EasyTier (虚拟组网)
UPDATE_PACKAGE "luci-app-easytier" "EasyTier/luci-app-easytier" "main" "name" "easytier"

# Aurora Theme (主题)
UPDATE_PACKAGE "luci-theme-aurora" "eamonxg/luci-theme-aurora" "master" "name"

# Athena LED (雅典娜呼吸灯)
UPDATE_PACKAGE "luci-app-athena-led" "haipengno1/luci-app-athena-led" "main" "name"

# ----------------------------------------------------------------------------
# HomeProxy 依赖修复 (使用官方 feeds 中的 sing-box)
# ----------------------------------------------------------------------------
echo -e "\n${GREEN}🔧 修复 HomeProxy 依赖...${NC}"
HOMEPROXY_MAKEFILE="package/custom/homeproxy/Makefile"
if [ -f "$HOMEPROXY_MAKEFILE" ]; then
    echo "  -> 修改 HomeProxy 依赖使用官方 feeds 中的 sing-box..."
    # 移除原有的强依赖
    sed -i '/^\s*+sing-box/d' "$HOMEPROXY_MAKEFILE" 2>/dev/null || true
    
    # 重写 Package 定义，依赖官方 feeds 中的 sing-box
    sed -i '/^include $(TOPDIR)\/feeds\/luci\/luci.mk/i \
define Package/$(PKG_NAME)\
  SECTION:=luci\
  CATEGORY:=LuCI\
  SUBMENU:=3. Applications\
  TITLE:=$(LUCI_TITLE)\
  PKGARCH:=$(LUCI_PKGARCH)\
  DEPENDS:=+sing-box +firewall4 +kmod-nft-tproxy +ucode-mod-digest\
endef\
' "$HOMEPROXY_MAKEFILE" 2>/dev/null || true
    
    echo "  ✅ HomeProxy 依赖已修复"
fi

# ----------------------------------------------------------------------------
# [3] 安装核心依赖 (MosDNS, v2dat, v2ray-geodata)
# ----------------------------------------------------------------------------
echo -e "\n${GREEN}[3/3] 安装核心依赖...${NC}"

# 清理所有相关缓存和冲突
echo "  🧹 清理 mosdns 相关缓存和冲突..."
rm -rf package/custom/luci-app-mosdns 2>/dev/null || true
rm -rf package/custom/mosdns 2>/dev/null || true
rm -rf package/custom/v2dat 2>/dev/null || true
rm -rf package/custom/v2ray-geodata 2>/dev/null || true
rm -rf feeds/packages/net/mosdns 2>/dev/null || true
rm -rf feeds/packages/net/v2ray-geodata 2>/dev/null || true

# 清理 Go 模块缓存
for module in "github.com/IrineSistiana" "github.com/mdlayher/socket" "github.com/google/nftables" "golang.org/x/net" "golang.org/x/time" "go4.org/netipx"; do
    if [ -d "dl/go-mod-cache/$module" ]; then
        rm -rf "dl/go-mod-cache/$module"
        echo "  ✅ 已清理 $module 缓存"
    fi
done

# 使用 UPDATE_PACKAGE 统一安装所有包
echo -e "\n${GREEN}安装 MosDNS 及相关组件...${NC}"

# 1. 安装 luci-app-mosdns (包含 mosdns 和 v2dat)
UPDATE_PACKAGE "luci-app-mosdns" "sbwml/luci-app-mosdns" "v5" "name" "mosdns v2dat"

# 2. 安装 v2ray-geodata
UPDATE_PACKAGE "v2ray-geodata" "sbwml/v2ray-geodata" "main" "name"

# 3. 修复 mosdns 版本兼容性问题
echo -e "\n${GREEN}🔧 处理 mosdns 版本兼容性...${NC}"
MOSDNS_MAKEFILE="package/custom/luci-app-mosdns/mosdns/Makefile"
if [ -f "$MOSDNS_MAKEFILE" ]; then
    echo "  -> 检测到 mosdns v5.3.3，需要 Go 1.22+..."
    echo "  -> 检查当前 Go 版本..."
    
    # 检查当前 Go 版本
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | grep -oP 'go\d+\.\d+')
        echo "  -> 当前 Go 版本: $GO_VERSION"
        
        # 如果 Go 版本低于 1.22，降级 mosdns 到 v5.1.3
        if [[ "$GO_VERSION" < "go1.22" ]]; then
            echo "  -> Go 版本过低，降级 mosdns 到 v5.1.3..."
            sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=5.1.3/g' "$MOSDNS_MAKEFILE" 2>/dev/null || true
            sed -i 's/PKG_HASH:=.*/PKG_HASH:=a863848ebb3261e9e8a5e6b8b70075496ea3a4e1d8e67c04ff5f3f3783166f23/g' "$MOSDNS_MAKEFILE" 2>/dev/null || true
            echo "  ✅ mosdns 已降级到 v5.1.3 (兼容 Go $GO_VERSION)"
        else
            echo "  ✅ Go 版本 $GO_VERSION 支持 mosdns v5.3.3"
        fi
    else
        echo "  ⚠️  未检测到 Go，假设使用系统默认版本，降级 mosdns 到 v5.1.3..."
        sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=5.1.3/g' "$MOSDNS_MAKEFILE" 2>/dev/null || true
        sed -i 's/PKG_HASH:=.*/PKG_HASH:=a863848ebb3261e9e8a5e6b70075496ea3a4e1d8e67c04ff5f3f3783166f23/g' "$MOSDNS_MAKEFILE" 2>/dev/null || true
        echo "  ✅ mosdns 已降级到 v5.1.3"
    fi
fi

# ----------------------------------------------------------------------------
# 清理 feeds 中的冲突包
# ----------------------------------------------------------------------------
echo -e "\n${GREEN}🧹 清理 feeds 冲突包...${NC}"
rm -rf feeds/packages/net/v2ray-geodata 2>/dev/null || true
rm -rf feeds/packages/net/mosdns 2>/dev/null || true
# 注意: 保留 feeds/packages/net/sing-box，使用官方 feeds 版本

echo ""
echo -e "${GREEN}✅ 所有准备工作完成！${NC}"
echo ""
