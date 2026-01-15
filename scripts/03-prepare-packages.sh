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
# MosDNS & v2dat (回归官方推荐的源码编译模式)
# ----------------------------------------------------------------------------
echo -e "\n${GREEN}Processing: MosDNS & Dependencies (Source Build)${NC}"

# 1. 彻底清理冲突
rm -rf package/custom/luci-app-mosdns
rm -rf package/custom/mosdns
rm -rf package/custom/v2dat
rm -rf package/custom/v2ray-geodata
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/v2ray-geodata

# 2. 拉取 sbwml 的 luci-app-mosdns (包含 v5 分支界面)
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/custom/luci-app-mosdns

# 3. 拉取核心依赖 (mosdns, v2dat)
# sbwml 的仓库里包含了 mosdns 和 v2dat 的 Makefile
# 我们直接使用他在仓库里提供的源码定义，让 OpenWrt 自动去拉取 Go 源码并编译
# 只需要把它们移动到 package 根目录能被识别到的地方即可
# 注意：sbwml 仓库结构:
#   luci-app-mosdns/
#   mosdns/
#   v2dat/
# 我们已经把整个仓库 clone 到了 package/custom/luci-app-mosdns
# OpenWrt 会自动扫描子目录。所以 mosdns 和 v2dat 的 Makefile 已经被包含在内了。
# 我们不需要额外做任何事！只需要确保 feeds 里的同名包被删除了（上面已做）。

# 4. 拉取 v2ray-geodata
git clone https://github.com/sbwml/v2ray-geodata package/custom/v2ray-geodata

# ----------------------------------------------------------------------------
# sing-box (回归官方 Feeds 源码编译)
# ----------------------------------------------------------------------------
# 之前的预编译模式导致了兼容性问题，现在直接使用官方 feeds 中的 sing-box 源码。
# 这样虽然编译较慢，但能保证与当前系统的 libc 和内核完全兼容。
echo -e "\n${GREEN}Processing: sing-box (Using Official Feeds)${NC}"
rm -rf package/custom/sing-box

# --- homeproxy 修复 ---
# 修改 HomeProxy 依赖，允许它使用 sing-box 变体 (如 tiny)
HOMEPROXY_MAKEFILE="package/custom/homeproxy/Makefile"
if [ -f "$HOMEPROXY_MAKEFILE" ]; then
    echo "  🔧 修复 homeproxy 依赖..."
    # 移除原有的强依赖
    sed -i '/^\s*+sing-box/d' "$HOMEPROXY_MAKEFILE"
    
    # 重写 Package 定义，依然依赖 sing-box (官方包名为 sing-box，安装后提供 /usr/bin/sing-box)
    # 如果想用 tiny 版，可以在 .config 中设置 CONFIG_PACKAGE_sing-box-tiny=y
    # 但 HomeProxy 只需要 executable，所以这里写 +sing-box 是安全的
    sed -i '/^include $(TOPDIR)\/feeds\/luci\/luci.mk/i \
define Package/$(PKG_NAME)\
  SECTION:=luci\
  CATEGORY:=LuCI\
  SUBMENU:=3. Applications\
  TITLE:=$(LUCI_TITLE)\
  PKGARCH:=$(LUCI_PKGARCH)\
  DEPENDS:=+sing-box +firewall4 +kmod-nft-tproxy +ucode-mod-digest\
endef\
' "$HOMEPROXY_MAKEFILE"
fi

# 🚨 最终清理
echo -e "\n${GREEN}🧹 Final Cleanup...${NC}"
# 注意: 不再删除 feeds/packages/net/sing-box，因为我们要用它
rm -rf feeds/packages/net/v2ray-geodata
# 只有当我们用 sbwml 的 mosdns 时才需要删 feeds 里的
rm -rf feeds/packages/net/mosdns

echo ""
echo -e "${GREEN}✅ 所有准备工作完成！${NC}"
echo ""
