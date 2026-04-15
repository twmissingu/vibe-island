#!/bin/bash
# Vibe Island Release Build Script
# 用法: ./scripts/build-release.sh

set -e

echo "🏝️  Vibe Island Release Build"
echo "================================"

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="VibeIsland"
CONFIGURATION="Release"
ARCHIVE_PATH="$PROJECT_DIR/build/VibeIsland.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/export"
EXPORT_OPTIONS="$PROJECT_DIR/scripts/ExportOptions.plist"
DMG_NAME="VibeIsland"

echo "📁 项目目录: $PROJECT_DIR"
echo "📦 归档路径: $ARCHIVE_PATH"
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

# 5. 创建 DMG
echo "💿 创建 DMG 安装包..."
mkdir -p "$PROJECT_DIR/build/dmg"

# 复制 App 到 DMG 目录
cp -R "$APP_PATH" "$PROJECT_DIR/build/dmg/"

# 如果 CLI 编译成功，也复制进去
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  cp "$PROJECT_DIR/build/vibe-island" "$PROJECT_DIR/build/dmg/"
fi

# 创建 DMG
hdiutil create \
  -volname "$DMG_NAME" \
  -srcfolder "$PROJECT_DIR/build/dmg" \
  -ov -format UDZO \
  "$PROJECT_DIR/build/${DMG_NAME}.dmg" \
  || { echo "❌ DMG 创建失败"; exit 1; }

echo "✅ DMG 创建完成"
echo ""

# 6. 输出结果
echo "================================"
echo "🎉 构建完成！"
echo "================================"
echo ""
echo "📦 产物:"
echo "   App:  $APP_PATH"
echo "   DMG:  $PROJECT_DIR/build/${DMG_NAME}.dmg"
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  echo "   CLI:  $PROJECT_DIR/build/vibe-island"
fi
echo ""

# 7. 显示文件信息
echo "📊 文件信息:"
ls -lh "$PROJECT_DIR/build/${DMG_NAME}.dmg" 2>/dev/null || true
echo ""

echo "✨ 提示: 打开 DMG 文件即可安装 Vibe Island"
