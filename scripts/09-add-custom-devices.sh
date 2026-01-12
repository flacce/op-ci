#!/bin/bash
#
# ============================================================================
# 脚本名称: 09-add-custom-devices.sh
# 功能描述: 添加 JDCloud RE-CS-02 和 RE-SS-01 设备支持
# ============================================================================
# 说明:
#   ImmortalWrt 官方源码尚未包含这两个设备的支持。
#   本脚本从 coolsnowwolf/lede 仓库拉取 DTS 文件，并修改 Makefile 添加设备定义。
# ============================================================================

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}🔧 步骤 9: 添加自定义设备支持${NC}"
echo -e "${BLUE}=========================================${NC}"

# 智能检测 OpenWrt 目录
if [ -d "openwrt" ]; then
    cd openwrt
    echo "📂 进入 openwrt 目录"
elif [ -f "feeds.conf.default" ]; then
    echo "📂 当前已在 openwrt 目录"
elif [ -d "build/openwrt" ]; then
    cd build/openwrt
    echo "📂 进入 build/openwrt 目录"
fi

# DTS 文件存放路径 (Qualcommax)
DTS_DIR="target/linux/qualcommax/files/arch/arm64/boot/dts/qcom"
MAKEFILE_PATH="target/linux/qualcommax/image/ipq60xx.mk"

# 确保目录存在
mkdir -p "$DTS_DIR"

# ============================================================================
# 1. 下载 DTS 文件
# ============================================================================

# 依赖文件 (NSS 支持)
echo -e "${GREEN}[1/3] 下载依赖文件 (ipq6018-nss.dtsi)...${NC}"
wget -nv https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-nss.dtsi -O "$DTS_DIR/ipq6018-nss.dtsi"

# RE-CS-02 (雅典娜)
echo -e "${GREEN}[2/3] 下载 RE-CS-02 (雅典娜) DTS...${NC}"
wget -nv https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6010-re-cs-02.dts -O "$DTS_DIR/ipq6010-re-cs-02.dts"

# RE-SS-01 (亚瑟)
echo -e "${GREEN}[3/3] 下载 RE-SS-01 (亚瑟) DTS...${NC}"
wget -nv https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6000-re-ss-01.dts -O "$DTS_DIR/ipq6000-re-ss-01.dts"

# ============================================================================
# 3. 修改 Makefile
# ============================================================================
echo -e "${GREEN}[2/2] 修改 ipq60xx.mk 添加设备定义...${NC}"

if [ ! -f "$MAKEFILE_PATH" ]; then
    echo -e "${RED}❌ 错误: 未找到 $MAKEFILE_PATH${NC}"
    exit 1
fi

# 检查是否已经添加
if grep -q "jdcloud_re-cs-02" "$MAKEFILE_PATH"; then
    echo "  ⚠️  设备定义已存在，跳过修改"
else
    cat >> "$MAKEFILE_PATH" <<EOF

define Device/jdcloud_re-cs-02
	\$(call Device/FitImage)
	\$(call Device/UbiFit)
	DEVICE_VENDOR := JDCloud
	DEVICE_MODEL := RE-CS-02
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	DEVICE_DTS_CONFIG := config@cp02
	SOC := ipq6010
	DEVICE_PACKAGES := ipq-wifi-jdcloud_re-cs-02 ath11k-firmware-qcn9074 kmod-ath11k-pci luci-app-athena-led luci-i18n-athena-led-zh-cn
endef
TARGET_DEVICES += jdcloud_re-cs-02

define Device/jdcloud_re-ss-01
	\$(call Device/FitImage)
	\$(call Device/UbiFit)
	DEVICE_VENDOR := JDCloud
	DEVICE_MODEL := RE-SS-01
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	DEVICE_DTS_CONFIG := config@ac03
	SOC := ipq6000
	DEVICE_PACKAGES := ipq-wifi-jdcloud_re-ss-01 -kmod-ath11k-pci zram-swap
endef
TARGET_DEVICES += jdcloud_re-ss-01
EOF
    echo "  ✅ 设备定义已添加到 $MAKEFILE_PATH"
fi

echo ""
echo -e "${GREEN}✅ 自定义设备支持添加完成！${NC}"
