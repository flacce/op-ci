#!/bin/bash
#
# ============================================================================
# 脚本名称: 08-organize-files.sh
# 功能描述: 整理固件文件（支持多设备配置）
# ============================================================================
# 作用:
#   1. 查找所有固件输出目录
#   2. 删除 packages 目录（只保留固件文件，节省空间）
#   3. 将所有固件文件集中到一个目录
#   4. 输出固件文件路径
# ============================================================================
# 输出:
#   - FIRMWARE_DIR: 固件文件所在目录的绝对路径
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "📦 整理固件文件..."
echo "========================================="

# 进入 OpenWrt 源码目录
cd openwrt

# 查找固件输出目录（支持多设备配置）
TARGET_DIR=$(find bin/targets -type d -name "qualcommax" -o -name "ipq60xx" | head -1)
if [ -z "$TARGET_DIR" ]; then
    echo "❌ 错误：未找到固件输出目录！"
    exit 1
fi

# 找到架构目录
ARCH_DIR=$(find bin/targets -type d -maxdepth 2 | grep -E "bin/targets/[^/]+/[^/]+$" | head -1)
echo "[1/3] 固件架构目录: $ARCH_DIR"

# 创建固件收集目录
FIRMWARE_DIR="$PWD/$ARCH_DIR/firmware"
mkdir -p "$FIRMWARE_DIR"

echo "[2/3] 收集所有固件文件..."
# 查找所有设备的固件文件（.bin, .img, .tar.gz 等）并复制到收集目录
find "$ARCH_DIR" -type f \( -name "*.bin" -o -name "*.img" -o -name "*.tar.gz" -o -name "*.manifest" -o -name "*sysupgrade*" -o -name "*factory*" \) -exec cp {} "$FIRMWARE_DIR/" \;

# 同时复制元数据文件
find "$ARCH_DIR" -maxdepth 1 -type f \( -name "*.buildinfo" -o -name "sha256sums" -o -name "version.buildinfo" \) -exec cp {} "$FIRMWARE_DIR/" \; 2>/dev/null || true

echo "[3/3] 删除 packages 目录（节省空间）..."
find "$ARCH_DIR" -type d -name "packages" -exec rm -rf {} + 2>/dev/null || true

# 输出固件文件列表
echo ""
echo "========================================="
echo "固件文件列表:"
echo "========================================="
ls -lh "$FIRMWARE_DIR"

# 统计固件数量
FIRMWARE_COUNT=$(find "$FIRMWARE_DIR" -type f \( -name "*.bin" -o -name "*.img" \) | wc -l)
echo ""
echo "📊 统计信息："
echo "  - 固件映像数量: $FIRMWARE_COUNT"
echo "  - 总文件数: $(ls -1 "$FIRMWARE_DIR" | wc -l)"

# 将固件目录路径输出到环境变量（供 GitHub Actions 使用）
echo "FIRMWARE_DIR=$FIRMWARE_DIR"

echo ""
echo "✅ 固件整理完成！"

