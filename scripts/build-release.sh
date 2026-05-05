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
VOLUME_NAME="Vibe Island"

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

# 5. 创建带拖拽引导的 DMG
echo "💿 创建 DMG 安装包..."

# 清理旧产物
rm -f "$PROJECT_DIR/build/${DMG_NAME}.dmg"

# 创建临时目录
TMP_DIR=$(mktemp -d)
DMG_TEMP="$TMP_DIR/vibe-island-temp.dmg"

# 5.1 创建可读写临时 DMG（比最终大小稍大）
echo "   创建临时 DMG..."

# 确保 CLI 在 app bundle 的 Resources 中
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  cp "$PROJECT_DIR/build/vibe-island" "$APP_PATH/Contents/Resources/vibe-island"
  chmod +x "$APP_PATH/Contents/Resources/vibe-island"
fi

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$APP_PATH" \
  -fs HFS+ \
  -format UDRW \
  -size 50m \
  "$DMG_TEMP" \
  > /dev/null 2>&1

# 5.2 挂载 DMG，捕获实际挂载点
echo "   挂载 DMG..."
PLIST_FILE=$(mktemp)
hdiutil attach "$DMG_TEMP" -nobrowse -plist > "$PLIST_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "❌ DMG 挂载失败"
  rm -f "$PLIST_FILE"
  rm -rf "$TMP_DIR"
  exit 1
fi

MOUNT_POINT=$(plutil -extract "system-entities.0.mount-point" raw "$PLIST_FILE" 2>/dev/null || echo "")
rm -f "$PLIST_FILE"

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
  echo "❌ 无法获取 DMG 挂载点"
  rm -rf "$TMP_DIR"
  exit 1
fi

# 5.3 创建 Applications 别名
echo "   添加 Applications 别名..."
osascript -e "
  tell application \"Finder\"
    tell disk \"$VOLUME_NAME\"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set the bounds of container window to {100, 100, 700, 500}
      set theViewOptions to the icon view options of container window
      set arrangement of theViewOptions to not arranged
      set icon size of theViewOptions to 80
      set text size of theViewOptions to 12
      set background color of theViewOptions to {10230, 10230, 10230}
      set position of item \"VibeIsland.app\" of container window to {180, 200}
      make new alias file at container window to POSIX file \"/Applications\" with properties {name:\"Applications\"}
      set position of item \"Applications\" of container window to {420, 200}
      update without registering applications
      delay 3
      close
    end tell
  end tell
" 2>/dev/null || echo "   ⚠️  Finder 布局设置可能未完全生效（不影响安装功能）"

# 5.4 复制 CLI 工具到 DMG（如果编译成功）
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  echo "   添加 CLI 工具..."
  cp "$PROJECT_DIR/build/vibe-island" "$MOUNT_POINT/"
fi

# 5.5 卸载 DMG
echo "   卸载 DMG..."
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || hdiutil detach "$MOUNT_POINT" -force -quiet

# 5.6 压缩为只读 DMG
echo "   压缩 DMG..."
hdiutil convert \
  "$DMG_TEMP" \
  -format UDZO \
  -o "$PROJECT_DIR/build/${DMG_NAME}.dmg" \
  > /dev/null 2>&1

# 清理临时文件
rm -rf "$TMP_DIR"

echo "✅ DMG 创建完成"
echo ""

# 6. 输出结果
echo "================================"
echo "🎉 构建完成！"
echo "================================"
echo ""
echo "📦 产物:"
echo "   DMG:  $PROJECT_DIR/build/${DMG_NAME}.dmg"
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  echo "   CLI:  $PROJECT_DIR/build/vibe-island"
fi
echo ""

# 7. 显示文件信息
echo "📊 文件信息:"
ls -lh "$PROJECT_DIR/build/${DMG_NAME}.dmg" 2>/dev/null || true
echo ""

echo "✨ 提示: 打开 DMG 文件，将 VibeIsland.app 拖拽到 Applications 文件夹即可安装"
