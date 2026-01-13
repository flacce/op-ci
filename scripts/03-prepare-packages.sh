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

# 🔍 自动更新 Lucky 到最新版 (使用 release.66666.host 源)
LUCKY_PKG_DIR="package/custom/luci-app-lucky/lucky"
if [ -d "$LUCKY_PKG_DIR" ]; then
    echo "  ✨ 正在从 release.66666.host 检查 Lucky 最新版..."
    
    # 1. 获取最新版本目录 (例如 v2.26.0beta1)
    BASE_URL="https://release.66666.host"
    LATEST_VER_DIR=$(curl -s "$BASE_URL" | grep -o 'href="./v[^"]*"' | cut -d'"' -f2 | sed 's/\.\///;s/\///' | sort -V | tail -n 1)
    
    if [ -n "$LATEST_VER_DIR" ]; then
        echo "    -> Found latest version: $LATEST_VER_DIR"
        
        # 2. 获取内部目录 (例如 2.26.0_lucky)
        INNER_DIR=$(curl -s "$BASE_URL/$LATEST_VER_DIR/" | grep -o 'href="./[^"]*_lucky/"' | head -n 1 | cut -d'"' -f2 | sed 's/\.\///;s/\///')
        
        if [ -n "$INNER_DIR" ]; then
            echo "    -> Found inner dir: $INNER_DIR"
            
            # 3. 提取纯版本号 (从 INNER_DIR 中，例如 2.26.0)
            VER_NUM=$(echo "$INNER_DIR" | sed 's/_lucky//')
            
            # 4. 构建完整下载 URL
            FILE_NAME="lucky_${VER_NUM}_Linux_arm64.tar.gz"
            # 目标 Makefile 路径
            TARGET_MAKEFILE="$LUCKY_PKG_DIR/Makefile"
            
            # 5. 重写 Makefile
            cat <<EOF > "$TARGET_MAKEFILE"
include \$(TOPDIR)/rules.mk

PKG_NAME:=lucky
PKG_VERSION:=$LATEST_VER_DIR
PKG_RELEASE:=1

PKG_SOURCE:=$FILE_NAME
PKG_SOURCE_URL:=$BASE_URL/$LATEST_VER_DIR/$INNER_DIR/
PKG_HASH:=skip

include \$(INCLUDE_DIR)/package.mk

define Package/lucky
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Lucky (Custom Host)
  URL:=https://github.com/gdy666/lucky
  DEPENDS:=@(aarch64)
endef

define Package/lucky/description
  Lucky (Integrated from 66666.host - $LATEST_VER_DIR)
endef

define Build/Compile
	# Binary download, no compile
endef

define Package/lucky/install
	\$(INSTALL_DIR) \$(1)/usr/bin
	\$(INSTALL_DIR) \$(1)/etc/init.d
	\$(INSTALL_DIR) \$(1)/etc/config
	
	tar -xzvf \$(DL_DIR)/\$(PKG_SOURCE) -C \$(PKG_BUILD_DIR)/
	\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/lucky \$(1)/usr/bin/lucky
	\$(INSTALL_BIN) ./files/lucky.init \$(1)/etc/init.d/lucky
	\$(INSTALL_CONF) ./files/luckyuci \$(1)/etc/config/lucky
endef

\$(eval \$(call BuildPackage,lucky))
EOF
            echo "    ✅ Lucky Makefile updated to use custom host ($LATEST_VER_DIR)."
        else
            echo "    ⚠️ Failed to find inner lucky directory."
        fi
    else
        echo "    ⚠️ Failed to find latest version directory."
    fi
fi


# HomeProxy (代理管理)
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main" "name"

# EasyTier (虚拟组网)
UPDATE_PACKAGE "luci-app-easytier" "EasyTier/luci-app-easytier" "main" "name" "easytier"

# Aurora Theme (主题)
UPDATE_PACKAGE "luci-theme-aurora" "eamonxg/luci-theme-aurora" "master" "name"

# MosDNS (DNS 转发器)
# 1. 移除源码自带的 mosdns 和 v2ray-geodata (防止冲突)
find package/ feeds/ -name "mosdns" -o -name "v2ray-geodata" -o -name "luci-app-mosdns" | xargs rm -rf
# 2. 克隆 sbwml 的版本 (v5 分支)
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/custom/luci-app-mosdns
git clone https://github.com/sbwml/v2ray-geodata package/custom/v2ray-geodata

# Athena LED (雅典娜呼吸灯)
UPDATE_PACKAGE "luci-app-athena-led" "haipengno1/luci-app-athena-led" "main" "name"

# 🔧 优化 Athena LED 插件
ATHENA_DIR="package/custom/luci-app-athena-led"
if [ -d "$ATHENA_DIR" ]; then
    echo "  ✨ 优化 Athena LED 插件..."
    
    # 1. 优化应用设置后的重启逻辑 (reload -> restart, exec -> sys.call)
    # 原代码使用 reload 可能导致配置不生效，且 logging 方式冗余
    sed -i 's/local output = luci.util.exec("\/etc\/init.d\/athena_led reload.*")/luci.sys.call("\/etc\/init.d\/athena_led restart >\/dev\/null 2>\&1")/' "$ATHENA_DIR/luasrc/model/cbi/athena_led/settings.lua"
    sed -i '/luci.util.exec("logger/d' "$ATHENA_DIR/luasrc/model/cbi/athena_led/settings.lua"
    
    # 2. 移除 init.d 中冗余的 reload_service (Procd 会自动处理)
    # 删除 reload_service(){ stop; start; } 块
    sed -i '/reload_service()/,/^}/d' "$ATHENA_DIR/root/etc/init.d/athena_led"
    
    # 3. 确保脚本有执行权限 (二进制由 Makefile 负责下载和安装)
    chmod +x "$ATHENA_DIR/root/etc/init.d/athena_led"
fi




# sing-box (核心组件 - 使用预编译包模式)
echo -e "\n${GREEN}Processing: sing-box (Pre-compiled Binary Mode)${NC}"
# 注意: package/custom/sing-box 已在本地创建，无需 git clone
# 这里我们只需要确保 Makefile 中的版本是最新的

SINGBOX_MAKEFILE="package/custom/sing-box/Makefile"
if [ -f "$SINGBOX_MAKEFILE" ]; then
    echo "  ✨ Checking for latest sing-box version (Pre-release)..."
    # 获取最新的包含 "linux-arm64" 的 release tag
    # 注意: sing-box release tag 通常是 v1.13.0-beta.5 格式
    LATEST_SINGBOX=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases | grep "tag_name" | grep -v "rc" | head -n 1 | cut -d '"' -f 4 | sed 's/^v//')
    
    if [ -n "$LATEST_SINGBOX" ]; then
        CURRENT_VER=$(grep "PKG_VERSION:=" "$SINGBOX_MAKEFILE" | cut -d'=' -f2)
        if [ "$LATEST_SINGBOX" != "$CURRENT_VER" ]; then
            echo "    -> Updating sing-box: $CURRENT_VER -> $LATEST_SINGBOX"
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$LATEST_SINGBOX/" "$SINGBOX_MAKEFILE"
        else
            echo "    -> sing-box is up-to-date ($CURRENT_VER)"
        fi
    else
        echo "    ⚠️ Failed to check sing-box version, using default."
    fi
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
