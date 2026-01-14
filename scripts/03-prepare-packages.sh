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
            # 关键修复: PKG_VERSION 必须符合 OpenWrt 规范 (去除 'v'，增加 beta/rc 的分隔符)
            SAFE_VERSION=$(echo "$LATEST_VER_DIR" | sed 's/^v//' | sed 's/beta/_beta/' | sed 's/rc/_rc/')
            
            cat <<EOF > "$TARGET_MAKEFILE"
include \$(TOPDIR)/rules.mk

PKG_NAME:=lucky
PKG_VERSION:=$SAFE_VERSION
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

define Build/Prepare
	# 手动解压到构建目录
	mkdir -p \$(PKG_BUILD_DIR)
	# 使用 tar 解压 .tar.gz 文件
	tar -xzvf \$(DL_DIR)/\$(PKG_SOURCE) -C \$(PKG_BUILD_DIR)/
	# 赋予执行权限
	chmod +x \$(PKG_BUILD_DIR)/lucky
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

# 2. 从 sbwml 仓库提取界面部分 (luci-app-mosdns)
echo "  ⚡ Setting up MosDNS..."
rm -rf _tmp_mosdns_repo
git clone https://github.com/sbwml/luci-app-mosdns -b v5 _tmp_mosdns_repo

# 提取界面
cp -r _tmp_mosdns_repo/luci-app-mosdns package/custom/luci-app-mosdns

# 3. 单独克隆 v2ray-geodata
git clone https://github.com/sbwml/v2ray-geodata package/custom/v2ray-geodata

# 3.5. ⚡ v2dat 预编译 (利用 Host Go 环境)
# v2dat 依赖新版 Go (cobra)，OpenWrt 内置 Go 版本可能过低，因此在 Host 环境预先编译
echo "  ⚡ Compiling v2dat on Host..."
# 清理可能存在的旧目录
rm -rf _v2dat_source
# 直接从源码仓库克隆，而不是从 sbwml 仓库提取 (后者只包含 Makefile)
git clone https://github.com/urlesistiana/v2dat _v2dat_source
pushd _v2dat_source > /dev/null
# 交叉编译
GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o ../v2dat_bin .
popd > /dev/null
rm -rf _v2dat_source

# 创建 v2dat 插件包
mkdir -p package/custom/v2dat
mv v2dat_bin package/custom/v2dat/v2dat

# 写入 v2dat Makefile
cat <<EOF > package/custom/v2dat/Makefile
include \$(TOPDIR)/rules.mk

PKG_NAME:=v2dat
PKG_VERSION:=2024
PKG_RELEASE:=1

include \$(INCLUDE_DIR)/package.mk

define Package/v2dat
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=v2dat (Host Compiled)
  DEPENDS:=@(aarch64)
endef

define Package/v2dat/description
  v2dat tool compiled on host environment.
endef

define Build/Compile
	# Already compiled
endef

define Package/v2dat/install
	\$(INSTALL_DIR) \$(1)/usr/bin
	\$(INSTALL_BIN) ./v2dat \$(1)/usr/bin/v2dat
endef

\$(eval \$(call BuildPackage,v2dat))
EOF

# 4. 创建 MosDNS 核心包 (预编译模式)
# 这一步完全独立于 sbwml 的源码，确保使用的是我们自定义的 Makefile
mkdir -p package/custom/mosdns
MOSDNS_DIR="package/custom/mosdns"

# 自动获取最新 MosDNS 版本
LATEST_MOSDNS=$(curl -s https://api.github.com/repos/IrineSistiana/mosdns/releases/latest | grep "tag_name" | cut -d '"' -f 4 | sed 's/^v//')
if [ -z "$LATEST_MOSDNS" ]; then LATEST_MOSDNS="5.3.3"; fi

echo "    -> Using MosDNS version: $LATEST_MOSDNS (Pre-compiled)"

# 写入预编译 Makefile
cat <<EOF > "$MOSDNS_DIR/Makefile"
include \$(TOPDIR)/rules.mk

PKG_NAME:=mosdns
PKG_VERSION:=$LATEST_MOSDNS
PKG_RELEASE:=1

PKG_SOURCE:=\$(PKG_NAME)-linux-arm64.zip
PKG_SOURCE_URL:=https://github.com/IrineSistiana/mosdns/releases/download/v\$(PKG_VERSION)/
PKG_HASH:=skip

include \$(INCLUDE_DIR)/package.mk

define Package/mosdns
  SECTION:=net
  CATEGORY:=Network
  TITLE:=MosDNS (Pre-compiled)
  URL:=https://github.com/IrineSistiana/mosdns
  DEPENDS:=@(aarch64) +ca-bundle
endef

define Package/mosdns/description
  MosDNS is a DNS proxy server. (Pre-compiled binary from GitHub Releases)
endef

define Build/Prepare
	# 手动解压到构建目录
	mkdir -p \$(PKG_BUILD_DIR)
	unzip -o \$(DL_DIR)/\$(PKG_SOURCE) -d \$(PKG_BUILD_DIR)
	# 赋予执行权限
	chmod +x \$(PKG_BUILD_DIR)/mosdns
endef

define Build/Compile
	# Binary download, no compile
endef

define Package/mosdns/install
	\$(INSTALL_DIR) \$(1)/usr/bin
	\$(INSTALL_DIR) \$(1)/etc/mosdns
	# Init script is provided by luci-app-mosdns, skip installing it here
	
	# 从构建目录复制
	\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/mosdns \$(1)/usr/bin/mosdns
endef

\$(eval \$(call BuildPackage,mosdns))
EOF

# 创建 files 目录和 init 脚本
mkdir -p "$MOSDNS_DIR/files"
cat <<EOF > "$MOSDNS_DIR/files/mosdns.init"
#!/bin/sh /etc/rc.common

START=90
USE_PROCD=1
PROG=/usr/bin/mosdns
CONF=/etc/mosdns/config.yaml

start_service() {
	procd_open_instance
	procd_set_param command \$PROG start -c \$CONF -d /etc/mosdns
	procd_set_param user root
	procd_set_param file \$CONF
	procd_set_param respawn
	procd_close_instance
}
EOF





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

# 🚨 最终清理：确保 feeds 中的 sing-box 和 v2ray-geodata 被移除
# 这一步非常重要，否则 OpenWrt 可能会优先编译 feeds 中的源码版本，导致构建失败
echo -e "\n${GREEN}🧹 Final Cleanup: Removing conflicting feed packages...${NC}"
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/v2ray-geodata

echo ""
echo -e "${GREEN}✅ 所有准备工作完成！${NC}"
echo ""
