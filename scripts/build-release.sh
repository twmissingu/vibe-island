#!/bin/bash
# Vibe Island Release Build Script
# 用法: ./scripts/build-release.sh
# 输出: build/VibeIsland-<arch>.tar.gz

set -e

echo "🏝️  Vibe Island Release Build"
echo "================================"

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="VibeIsland"
CONFIGURATION="Release"

ARCH_NAME=$(uname -m)
TAR_NAME="VibeIsland-${ARCH_NAME}"

echo "📁 项目目录: $PROJECT_DIR"
echo "📦 架构: $ARCH_NAME"
echo ""

# 1. 生成 Xcode 项目
echo "🔨 生成 Xcode 项目..."
cd "$PROJECT_DIR"
xcodegen generate --quiet
echo "✅ 项目生成完成"
echo ""

# 2. 编译 Release 版本
echo "🚀 编译 Release 版本..."
BUILD_OUTPUT=$(xcodebuild clean build \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -skipPackagePluginValidation \
  ONLY_ACTIVE_ARCH=YES \
  2>&1)

BUILD_STATUS=$?
echo "$BUILD_OUTPUT" | grep -E "(warning:|error:)" | tail -10

if [ $BUILD_STATUS -ne 0 ]; then
  echo "❌ 编译失败"
  echo "$BUILD_OUTPUT" | grep "error:" | head -5
  exit 1
fi
echo "✅ 编译完成"
echo ""

# 3. 获取产物路径
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Products/Release/VibeIsland.app" -type d 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  echo "❌ 未找到 VibeIsland.app"
  exit 1
fi

echo "📱 App 路径: $APP_PATH"
echo ""

# 4. 编译 CLI 工具
echo "🛠️  编译 CLI 工具..."
cd "$PROJECT_DIR/Sources/CLI"
swiftc -O -target arm64-apple-macosx14.0 \
  vibe-island.swift HookHandler.swift SharedModels.swift \
  -o "$PROJECT_DIR/build/vibe-island" 2>/dev/null \
  || echo "⚠️  CLI 编译失败（可手动编译）"
echo ""

# 5. 嵌入 CLI 到 app bundle
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  cp "$PROJECT_DIR/build/vibe-island" "$APP_PATH/Contents/Resources/vibe-island"
  chmod +x "$APP_PATH/Contents/Resources/vibe-island"
fi

# 6. 签名 + 清理 quarantine
echo "🔏 签名 App（ad-hoc）..."
sudo xattr -cr "$APP_PATH" 2>/dev/null || true
codesign --force --deep --sign - "$APP_PATH" 2>/dev/null && echo "   ✅ 签名完成"
echo ""

# 清理旧产物
rm -f "$PROJECT_DIR/build/${TAR_NAME}.tar.gz"

# 7. 打包 .tar.gz
echo "📦 创建 ${TAR_NAME}.tar.gz..."
cd "$PROJECT_DIR/build"
tar czf "${TAR_NAME}.tar.gz" -C "$(dirname "$APP_PATH")" "VibeIsland.app"
echo "   ✅ ${TAR_NAME}.tar.gz 创建完成"
echo ""

# 8. 输出结果
echo "================================"
echo "🎉 构建完成！"
echo "================================"
echo ""
echo "📦 产物:"
echo "   TAR: $PROJECT_DIR/build/${TAR_NAME}.tar.gz"
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  echo "   CLI: $PROJECT_DIR/build/vibe-island"
fi
echo ""

echo "📊 文件信息:"
ls -lh "$PROJECT_DIR/build/${TAR_NAME}.tar.gz"
echo ""

echo "📖 安装方式:"
echo ""
echo "  方式 1（推荐）— 一键脚本:"
echo "    curl -fsSL https://raw.githubusercontent.com/twmissingu/vibe-island/main/scripts/install.sh | bash"
echo ""
echo "  方式 2 — 手动安装:"
echo "    tar xzf ${TAR_NAME}.tar.gz"
echo "    cp -r VibeIsland.app /Applications/"
echo "    xattr -cr /Applications/VibeIsland.app"
echo "    open /Applications/VibeIsland.app"
