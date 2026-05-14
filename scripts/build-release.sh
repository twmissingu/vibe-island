#!/bin/bash
# Vibe Island Release Build Script
# 用法: ./scripts/build-release.sh
# 输出: build/VibeIsland-<arch>.tar.gz (主要), build/VibeIsland.dmg (备选)

set -e

echo "🏝️  Vibe Island Release Build"
echo "================================"

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="VibeIsland"
CONFIGURATION="Release"
ARCHIVE_PATH="$PROJECT_DIR/build/VibeIsland.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/export"
DMG_NAME="VibeIsland"
VOLUME_NAME="Vibe Island"

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
rm -f "$PROJECT_DIR/build/${DMG_NAME}.dmg"
rm -f "$PROJECT_DIR/build/${TAR_NAME}.tar.gz"

# 7. 创建 .tar.gz（主要分发格式）
echo "📦 创建 ${TAR_NAME}.tar.gz..."
cd "$PROJECT_DIR/build"
tar czf "${TAR_NAME}.tar.gz" -C "$(dirname "$APP_PATH")" "VibeIsland.app"
echo "   ✅ ${TAR_NAME}.tar.gz 创建完成"
echo ""

# 8. 创建 DMG（备选）
echo "💿 创建 DMG 安装包..."
TMP_DIR=$(mktemp -d)
DMG_TEMP="$TMP_DIR/vibe-island-temp.dmg"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$APP_PATH" \
  -fs HFS+ \
  -format UDRW \
  -size 50m \
  "$DMG_TEMP" \
  > /dev/null 2>&1

# 挂载
PLIST_FILE=$(mktemp)
hdiutil attach "$DMG_TEMP" -nobrowse -plist > "$PLIST_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "   ⚠️ DMG 挂载失败，跳过 DMG 创建"
else
  MOUNT_POINT=$(plutil -extract "system-entities.0.mount-point" raw "$PLIST_FILE" 2>/dev/null || echo "")
  rm -f "$PLIST_FILE"

  if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
    # 添加 Applications 别名
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
          delay 2
          close
        end tell
      end tell
    " 2>/dev/null || true

    # 复制 CLI 到 DMG
    if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
      cp "$PROJECT_DIR/build/vibe-island" "$MOUNT_POINT/"
    fi

    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || hdiutil detach "$MOUNT_POINT" -force -quiet
  fi

  # 压缩为只读 DMG
  hdiutil convert \
    "$DMG_TEMP" \
    -format UDZO \
    -o "$PROJECT_DIR/build/${DMG_NAME}.dmg" \
    > /dev/null 2>&1

  echo "   ✅ DMG 创建完成"
fi

rm -rf "$TMP_DIR"
echo ""

# 9. 输出结果
echo "================================"
echo "🎉 构建完成！"
echo "================================"
echo ""
echo "📦 产物:"
echo "   TAR: $PROJECT_DIR/build/${TAR_NAME}.tar.gz"
if [ -f "$PROJECT_DIR/build/${DMG_NAME}.dmg" ]; then
  echo "   DMG: $PROJECT_DIR/build/${DMG_NAME}.dmg"
fi
if [ -f "$PROJECT_DIR/build/vibe-island" ]; then
  echo "   CLI: $PROJECT_DIR/build/vibe-island"
fi
echo ""

echo "📊 文件信息:"
ls -lh "$PROJECT_DIR/build/${TAR_NAME}.tar.gz"
if [ -f "$PROJECT_DIR/build/${DMG_NAME}.dmg" ]; then
  ls -lh "$PROJECT_DIR/build/${DMG_NAME}.dmg"
fi
echo ""

echo "📖 安装方式:"
echo ""
echo "  方式 1（推荐）— 一键脚本:"
echo "    curl -fsSL https://github.com/twmissingu/vibe-island/releases/latest/download/install.sh | bash"
echo ""
echo "  方式 2 — 手动安装:"
echo "    tar xzf ${TAR_NAME}.tar.gz"
echo "    cp -r VibeIsland.app /Applications/"
echo "    xattr -cr /Applications/VibeIsland.app"
echo "    open /Applications/VibeIsland.app"
echo ""
echo "  方式 3 — DMG:"
echo "    1. 打开 VibeIsland.dmg"
echo "    2. 拖拽 VibeIsland.app 到 Applications"
echo "    3. 首次打开: 右键 → 打开（不要双击）"
echo "    4. 点击「打开」按钮"
