#!/bin/bash
# Vibe Island 测试运行脚本
# 用法: ./scripts/run-tests.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🏝️  Vibe Island 单元测试"
echo "=========================="
echo ""

# 1. 运行 Swift 脚本测试
echo "📝 运行 Hook 格式测试..."
swift Tests/VibeIslandTests/hook_format_test.swift
echo ""

# 2. 运行 Xcode 测试（如果 Xcode 可用）
if command -v xcodebuild &> /dev/null; then
    echo "🧪 运行 Xcode 单元测试..."
    xcodebuild test \
        -scheme VibeIsland \
        -destination 'platform=macOS' \
        -configuration Debug \
        -only-testing:VibeIslandTests \
        -quiet \
        2>&1 | grep -E "(Test Case.*|passed|failed|error:|BUILD)" | tail -30
    echo ""
fi

echo "=========================="
echo "✅ 测试完成！"
echo ""
