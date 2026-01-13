#!/bin/bash
#
# ============================================================================
# 脚本名称: 03-prepare-packages.sh
# 功能描述: 准备软件包环境（借鉴 VIKINGYFY/OpenWRT-CI 的插件管理逻辑）
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
# 功能: 智能清理冲突并克隆/更新插件
# 参数:
#   $1: 目标包名 (Package Name)
#   $2: 仓库地址 (Repo URL, 例如 user/repo)
#   $3: 分支 (Branch, 默认为 main/master)
#   $4: 模式 (pkg: 提取子目录, name: 重命名)
#   $5: 冲突关键词列表 (空格分隔)
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
        # 查找并移动匹配的子目录
        find "package/custom/_tmp_$REPO_NAME" -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} "package/custom/" \;
        
        # 如果提取出的目录名不匹配 PKG_NAME，重命名
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
        # 注意: 这里直接 clone 到 package/custom/REPO_NAME，或者如果指定了 PKG_NAME 且不匹配 REPO_NAME...
        # 简单起见，直接 clone 到 package/custom/PKG_NAME (如果 URL 结尾就是 PKG_NAME)
        # 或者为了稳妥，clone 后检查
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

# 格式: UPDATE_PACKAGE "包名" "仓库/名" "分支" "模式" "额外冲突词"

# Lucky (综合工具箱)
UPDATE_PACKAGE "luci-app-lucky" "gdy666/luci-app-lucky" "main" "name" "lucky"

# HomeProxy (代理管理)
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main" "name"

# EasyTier (虚拟组网)
UPDATE_PACKAGE "luci-app-easytier" "EasyTier/luci-app-easytier" "main" "name" "easytier"

# Aurora Theme (主题)
UPDATE_PACKAGE "luci-theme-aurora" "eamonxg/luci-theme-aurora" "master" "name"

# Athena LED (雅典娜呼吸灯)
UPDATE_PACKAGE "luci-app-athena-led" "NONGFAH/luci-app-athena-led" "main" "name"


# sing-box (核心组件 - 使用特殊处理逻辑)
echo -e "\n${GREEN}Processing: sing-box (Manual handling)${NC}"
# 清理旧的 sing-box
rm -rf package/custom/sing-box
mkdir -p package/custom/sing-box
pushd package/custom/sing-box > /dev/null
git init
git remote add origin https://github.com/openwrt/packages.git
git config core.sparseCheckout true
echo "net/sing-box/*" >> .git/info/sparse-checkout
git pull --depth=1 origin master
mv net/sing-box/* .
rm -rf net .git
popd > /dev/null


# ============================================================================
# [3] 修复 Makefile
# ============================================================================
echo -e "${GREEN}[3/3] 修复 Makefile 问题...${NC}"

# --- sing-box 修复 (保持原有的有效修复逻辑) ---
SINGBOX_MAKEFILE="package/custom/sing-box/Makefile"
if [ -f "$SINGBOX_MAKEFILE" ]; then
    echo "  🔧 修复 sing-box..."
    cp "$SINGBOX_MAKEFILE" "$SINGBOX_MAKEFILE.bak"
    
    # 写入头部
    cat <<EOF > "$SINGBOX_MAKEFILE"
include \$(TOPDIR)/rules.mk

EOF
    # 提取变量
    grep -E "^(PKG_|GO_)" "$SINGBOX_MAKEFILE.bak" | grep -v "GO_PKG_TAGS" >> "$SINGBOX_MAKEFILE"
    
    # 写入主体
    cat <<EOF >> "$SINGBOX_MAKEFILE"

include \$(INCLUDE_DIR)/package.mk
include \$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/sing-box
  TITLE:=The universal proxy platform
  SECTION:=net
  CATEGORY:=Network
  URL:=https://sing-box.sagernet.org
  DEPENDS:=\$(GO_ARCH_DEPENDS) +ca-bundle +kmod-inet-diag +kmod-tun
  USERID:=sing-box=5566:sing-box=5566
  TITLE+= (tiny)
  VARIANT:=tiny
endef

define Package/sing-box/description
  Sing-box is a universal proxy platform which supports hysteria, SOCKS, Shadowsocks,
  ShadowTLS, Tor, trojan, VLess, VMess, WireGuard and so on.
endef

define Package/sing-box/conffiles
/etc/config/sing-box
/etc/sing-box/
endef

define Package/sing-box/install
	\$(INSTALL_DIR) \$(1)/usr/bin/
	\$(INSTALL_BIN) \$(GO_PKG_BUILD_BIN_DIR)/sing-box \$(1)/usr/bin/sing-box

	\$(INSTALL_DIR) \$(1)/etc/sing-box
	\$(INSTALL_DATA) \$(PKG_BUILD_DIR)/release/config/config.json \$(1)/etc/sing-box

	\$(INSTALL_DIR) \$(1)/etc/config/
	\$(INSTALL_CONF) ./files/sing-box.conf \$(1)/etc/config/sing-box
	\$(INSTALL_DIR) \$(1)/etc/init.d/
	\$(INSTALL_BIN) ./files/sing-box.init \$(1)/etc/init.d/sing-box
endef

GO_PKG_TAGS:=with_quic,with_utls,with_clash_api
ifndef CONFIG_SMALL_FLASH
  GO_PKG_TAGS:=with_gvisor,\$(GO_PKG_TAGS)
endif

\$(eval \$(call BuildPackage,sing-box))
EOF
else
    echo "  ⚠️  sing-box Makefile 未找到"
fi

# --- homeproxy 修复 ---
HOMEPROXY_MAKEFILE="package/custom/homeproxy/Makefile"
if [ -f "$HOMEPROXY_MAKEFILE" ]; then
    echo "  🔧 修复 homeproxy..."
    sed -i '/^\s*+sing-box/d' "$HOMEPROXY_MAKEFILE"
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

echo ""
echo -e "${GREEN}✅ 所有准备工作完成！${NC}"
echo ""
