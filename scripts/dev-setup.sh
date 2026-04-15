#!/bin/bash
# Vibe Island Development Setup Script
# 用法: ./scripts/dev-setup.sh

set -e

echo "🏝️  Vibe Island Development Setup"
echo "===================================="

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 1. 检查依赖
echo "🔍 检查依赖..."

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
  echo "❌ 未安装 Homebrew"
  echo "   请先安装: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi
echo "   ✅ Homebrew"

# 检查 XcodeGen
if ! command -v xcodegen &> /dev/null; then
  echo "   ⚠️  未安装 XcodeGen，正在安装..."
  brew install xcodegen
fi
echo "   ✅ XcodeGen"

# 检查 Swift 版本
SWIFT_VERSION=$(swift --version | grep -o "Swift version [0-9.]*" | head -1)
echo "   ✅ $SWIFT_VERSION"

echo ""

# 2. 生成 Xcode 项目
echo "🔨 生成 Xcode 项目..."
xcodegen generate
echo "   ✅ VibeIsland.xcodeproj"
echo ""

# 3. 编译 CLI 工具
echo "🛠️  编译 CLI 工具..."
cd "$PROJECT_DIR/Sources/CLI"
swiftc -typecheck -target arm64-apple-macosx14.0 \
  vibe-island.swift HookHandler.swift SharedModels.swift \
  && echo "   ✅ CLI 编译检查通过" \
  || echo "   ❌ CLI 编译失败"
echo ""

# 4. 创建必要的目录
echo "📁 创建运行时目录..."
mkdir -p ~/.vibe-island/sessions
mkdir -p ~/.vibe-island/bin
echo "   ✅ ~/.vibe-island/"
echo ""

# 5. 安装 CLI（可选）
read -p "是否安装 vibe-island CLI 到 /usr/local/bin? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  swiftc -O -target arm64-apple-macosx14.0 \
    vibe-island.swift HookHandler.swift SharedModels.swift \
    -o /tmp/vibe-island
  
  if [ -f /tmp/vibe-island ]; then
    sudo mv /tmp/vibe-island /usr/local/bin/vibe-island
    sudo chmod +x /usr/local/bin/vibe-island
    echo "✅ CLI 已安装到 /usr/local/bin/vibe-island"
  fi
fi
echo ""

# 6. 完成
echo "===================================="
echo "✨ 开发环境设置完成！"
echo "===================================="
echo ""
echo "📖 下一步:"
echo "   1. 打开项目: open VibeIsland.xcodeproj"
echo "   2. 在 Xcode 中运行 (Cmd+R)"
echo "   3. 测试 CLI: vibe-island --help"
echo ""
