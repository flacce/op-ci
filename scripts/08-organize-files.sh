#!/bin/bash
#
# ============================================================================
# 脚本名称: 08-organize-files.sh
# 功能描述: 整理固件文件（简化版）
# ============================================================================
# 作用:
#   1. 进入固件输出目录
#   2. 删除 packages 目录（节省空间）
#   3. 输出固件目录路径
# ============================================================================
# 输出:
#   - FIRMWARE_DIR: 固件文件所在目录的绝对路径
#   - BUILD_DATE: 当前日期（用于 Release 命名）
#   - status: success（成功标记）
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "📦 整理固件文件..."
echo "========================================="

# 智能检测 OpenWrt 目录
if [ -d "openwrt" ]; then
    cd openwrt
    echo "📂 进入 openwrt 目录"
elif [ -f "feeds.conf.default" ]; then
    echo "📂 当前已在 openwrt 目录"
else
    # 尝试在 build/openwrt 查找 (适配本地构建)
    if [ -d "build/openwrt" ]; then
        cd build/openwrt
        echo "📂 进入 build/openwrt 目录"
    fi
fi

# 找到固件输出目录（bin/targets/架构/型号）
FIRMWARE_PATH=$(find bin/targets -type d -maxdepth 2 | grep -E "bin/targets/[^/]+/[^/]+$" | head -1)

if [ -z "$FIRMWARE_PATH" ]; then
    echo "❌ 错误：未找到固件输出目录！"
    exit 1
fi

echo "[1/4] 固件目录: $FIRMWARE_PATH"

# 删除 packages 目录（节省空间）
echo "[2/4] 删除 packages 目录..."
find "$FIRMWARE_PATH" -type d -name "packages" -exec rm -rf {} + 2>/dev/null || true

# 获取绝对路径（使用 realpath 处理软链接）
FIRMWARE_DIR=$(realpath "$FIRMWARE_PATH")

# 列出所有固件文件
echo "[3/4] 固件文件列表:"
echo "========================================="
ls -lh "$FIRMWARE_DIR"

# 统计固件数量
FIRMWARE_COUNT=$(find "$FIRMWARE_DIR" -type f \( -name "*.bin" -o -name "*.img" -o -name "*sysupgrade*" -o -name "*factory*" \) | wc -l)
TOTAL_FILES=$(ls -1 "$FIRMWARE_DIR" | wc -l)

echo ""
echo "📊 统计信息："
echo "  - 固件映像数量: $FIRMWARE_COUNT"
echo "  - 总文件数: $TOTAL_FILES"
echo "  - 固件目录: $FIRMWARE_DIR"

# 如果没有找到固件映像，给出警告
if [ "$FIRMWARE_COUNT" -eq 0 ]; then
    echo ""
    echo "⚠️ 警告：未找到固件映像文件！"
    echo "可能的原因："
    echo "1. 编译配置问题（未选择生成固件映像）"
    echo "2. 编译失败但未报错"
    echo ""
    echo "正在检查子目录..."
    find "$FIRMWARE_DIR" -type f -name "*.bin" -o -name "*.img" | head -20
fi

# 获取当前日期（用于 Release 命名）
BUILD_DATE=$(TZ=Asia/Shanghai date '+%Y-%m-%d')

echo ""
echo "[4/4] 输出环境变量..."
# 输出环境变量供 GitHub Actions 使用
echo "FIRMWARE_DIR=$FIRMWARE_DIR"
echo "BUILD_DATE=$BUILD_DATE"
echo "status=success"

echo ""
echo "✅ 固件整理完成！"

