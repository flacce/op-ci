#!/bin/bash
#
# ============================================================================
# 脚本名称: 04-clean-conflicts.sh
# 功能描述: 清理冲突插件（核心步骤！）
# ============================================================================
# 作用:
#   删除所有可能导致编译冲突的"毒瘤插件"
#   包括: SSR、Passwall、SmartDNS、MosDNS、iStore 等
# ============================================================================
#

set -e  # 遇到错误立即退出

echo "========================================="
echo "🧹 清理冲突插件..."
echo "========================================="

# 进入 OpenWrt 源码目录
cd openwrt

# ----------------------------------------------------------------------------
# 1️⃣ 删除 VPN/代理类冲突插件
# ----------------------------------------------------------------------------
echo "[1/5] 删除 VPN/代理类冲突插件..."
# - Bypass：科学上网插件（与 HomeProxy 冲突）
# - SSR Plus：ShadowsocksR 插件（已过时）
# - Passwall/Passwall2：代理插件（依赖 v2ray-geodata）
# - IPsec VPN：VPN 服务器插件
# - Trojan Plus：Trojan 代理
# - Strongswan：IPsec VPN 后端（包括 swanctl）
# - VSSR：V2Ray/SSR 集成插件
# - FcHomo：代理插件
# - Nikki：代理相关
# - DAE/DAED：代理加速引擎（依赖 v2ray-geodata）
find feeds/ -name "luci-app-bypass" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-ssr-plus" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-passwall" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-passwall2" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-ipsec-server" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-ipsec-vpnd" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-strongswan-swanctl" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "trojan-plus" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "strongswan*" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-vssr" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-fchomo" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "nikki" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "dae" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "daed" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-dae" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-daed" -exec rm -rf {} + 2>/dev/null || true

# ----------------------------------------------------------------------------
# 2️⃣ 删除多拨/负载均衡类冲突插件
# ----------------------------------------------------------------------------
echo "[2/5] 删除多拨/负载均衡类冲突插件..."
# - MultiAccount Dial：多账号多拨
# - SyncDial：多拨同步
# - Prometheus Node Exporter：监控插件（Lua 版本冲突）
# - Mwan3：多 WAN 负载均衡
find feeds/ -name "luci-app-multiaccountdial" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-syncdial" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "prometheus-node-exporter-lua" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-mwan3" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "mwan3" -exec rm -rf {} + 2>/dev/null || true

# ----------------------------------------------------------------------------
# 3️⃣ 删除 iStore/Docker/QoS 类冲突插件
# ----------------------------------------------------------------------------
echo "[3/5] 删除 iStore/Docker/QoS 类冲突插件..."
# - QuickStart：iStore 快速启动页
# - RouterDog：路由器管理
# - iStore：应用商店（与 APK 包管理器冲突）
# - SQM：智能队列管理（QoS）
# - BandwidthD：带宽监控
# - Natflow：流量加速（部分场景冲突）
find feeds/ -name "luci-app-quickstart" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-routerdog" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-store" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-sqm" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "sqm-scripts" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-bandwidthd" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "natflow" -exec rm -rf {} + 2>/dev/null || true

# ----------------------------------------------------------------------------
# 4️⃣ 删除 DNS 解析类冲突插件（按用户要求删除）
# ----------------------------------------------------------------------------
echo "[4/5] 删除 DNS 解析类冲突插件..."
# - SmartDNS：智能 DNS 解析
# - MosDNS：模块化 DNS 分流
# - v2ray-geodata：V2Ray 地理位置数据（MosDNS 依赖）
find feeds/ -name "luci-app-smartdns" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "smartdns" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "luci-app-mosdns" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "mosdns" -exec rm -rf {} + 2>/dev/null || true
find feeds/ -name "v2ray-geodata" -exec rm -rf {} + 2>/dev/null || true

# ----------------------------------------------------------------------------
# 5️⃣ 删除其他问题依赖
# ----------------------------------------------------------------------------
echo "[5/5] 删除其他问题依赖..."
# - GNUnet：去中心化网络框架（编译时间过长）
# - OnionShare CLI：暗网文件分享工具（依赖复杂）
# - adguardhome (feeds)：将使用 Git 最新版本替代
# - homeproxy (feeds)：删除以使用 VIKINGYFY 自定义版本
# - passwall：代理插件（已在步骤 1 删除，此处再次确认）

# 使用更可靠的删除方法
rm -rf feeds/packages/net/adguardhome 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-adguardhome 2>/dev/null || true
rm -rf feeds/packages/net/gnunet* 2>/dev/null || true
rm -rf feeds/packages/net/onionshare-cli 2>/dev/null || true

# 删除 feeds homeproxy（使用自定义版本）
rm -rf feeds/packages/net/homeproxy 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-homeproxy 2>/dev/null || true

# 删除 passwall（避免冲突）
rm -rf feeds/luci/applications/luci-app-passwall 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-passwall2 2>/dev/null || true

echo "✅ 已删除以下问题包："
echo "  - GNUnet (编译耗时)"
echo "  - OnionShare CLI (依赖缺失)"
echo "  - AdGuardHome feeds 版本 (使用 Git 版本)"
echo "  - HomeProxy feeds 版本 (使用 VIKINGYFY 版本)"
echo "  - PassWall 系列 (避免冲突)"

# 刷新 feeds 索引，确保清理生效
echo "刷新 feeds 索引..."
./scripts/feeds update -i

echo "✅ 冲突插件清理完成！"
