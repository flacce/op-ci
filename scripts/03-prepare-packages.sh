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




# sing-box (核心组件 - 使用原版修改策略)
echo -e "\n${GREEN}Processing: sing-box (Patching upstream)${NC}"
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

# --- sing-box 修复 (改用 sed 精准裁剪) ---
SINGBOX_MAKEFILE="package/custom/sing-box/Makefile"
if [ -f "$SINGBOX_MAKEFILE" ]; then
    echo "  🔧 修复 sing-box (去除 full 版本)..."
    
    # 1. 修正 golang-package.mk 路径 (最关键)
    sed -i 's|\.\./\.\./lang/golang/golang-package.mk|$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|' "$SINGBOX_MAKEFILE"
    
    # 2. 移除 full 版本的定义块
    # 删除 define Package/sing-box ... endef 块
    sed -i '/^define Package\/sing-box$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    # 删除对应的 description, config, conffiles, install
    sed -i '/^define Package\/sing-box\/description$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    sed -i '/^define Package\/sing-box\/config$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    sed -i '/^define Package\/sing-box\/conffiles$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    sed -i '/^define Package\/sing-box\/install$/,/^endef$/d' "$SINGBOX_MAKEFILE"
    
    # 3. 将 tiny 版本重命名为 sing-box (成为默认)
    sed -i 's/Package\/sing-box-tiny/Package\/sing-box/g' "$SINGBOX_MAKEFILE"
    sed -i 's/Build\/Compile\/sing-box-tiny/Build\/Compile\/sing-box/g' "$SINGBOX_MAKEFILE"
    
    # 4. 清理 tiny 特有的属性 (PROVIDES/CONFLICTS/VARIANT)
    sed -i '/PROVIDES:=sing-box/d' "$SINGBOX_MAKEFILE"
    sed -i '/CONFLICTS:=sing-box/d' "$SINGBOX_MAKEFILE"
    sed -i '/VARIANT:=tiny/d' "$SINGBOX_MAKEFILE"
    
    # 5. 修正最后的构建调用
    # 此时文件中应该剩下 $(eval $(call BuildPackage,sing-box)) 和原本的 tiny 调用
    # 我们需要确保只保留一个有效的 BuildPackage,sing-box
    # 简单粗暴：删除所有 BuildPackage 调用，然后手动添加一个正确的
    sed -i '/BuildPackage/d' "$SINGBOX_MAKEFILE"
    echo '$(eval $(call BuildPackage,sing-box))' >> "$SINGBOX_MAKEFILE"
    
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
