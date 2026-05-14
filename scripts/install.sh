#!/bin/bash
# VibeIsland 一键安装脚本
# 用法: curl -fsSL https://github.com/twmissingu/vibe-island/releases/latest/download/install.sh | bash
#
# 此脚本处理 macOS Gatekeeper 拦截问题（没有 Apple Developer 开发者账号的 app 需要手动移除 quarantine）

set -e

echo "🏝️  VibeIsland 安装中..."

# 检测架构
ARCH=$(uname -m)
case "$ARCH" in
    arm64) ARCH_NAME="arm64" ;;
    x86_64) ARCH_NAME="x86_64" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
esac

# 从 GitHub API 获取最新 release 的下载地址
REPO="twmissingu/vibe-island"
echo "📡 获取最新版本..."
LATEST=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tag_name'])")
TAR_URL="https://github.com/$REPO/releases/download/$LATEST/VibeIsland-$ARCH_NAME.tar.gz"

# 创建临时目录
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

echo "📥 下载 VibeIsland $LATEST..."
curl -fsSL "$TAR_URL" -o VibeIsland.tar.gz

echo "📦 解压..."
tar xzf VibeIsland.tar.gz

echo "📋 复制到 /Applications..."
cp -r VibeIsland.app /Applications/

echo "🔓 移除 Gatekeeper 隔离属性（无需开发者签名即可运行）..."
xattr -cr /Applications/VibeIsland.app 2>/dev/null || true

# 清理
cd /
rm -rf "$TMP_DIR"

echo ""
echo "✅ 安装完成！正在启动 VibeIsland..."
open /Applications/VibeIsland.app
