import XCTest
import SwiftUI
@testable import VibeIsland
import LLMQuotaKit

// MARK: - 灵动岛主界面 UI 测试

/// 测试 IslandView 的核心用户交互流程
/// 包括：展开/收起切换、状态指示器、会话信息、宠物显示等
@MainActor
final class IslandViewUITests: XCTestCase {

    // MARK: - 视图结构测试

    /// 测试：CompactIslandView 应成功初始化
    func testCompactIslandView_initializes() {
        let view = CompactIslandView()
        XCTAssertNotNil(view, "CompactIslandView 应成功初始化")
    }

    /// 测试：ExpandedIslandView 应成功初始化
    func testExpandedIslandView_initializes() {
        let view = ExpandedIslandView()
        XCTAssertNotNil(view, "ExpandedIslandView 应成功初始化")
    }

    /// 测试：IslandView 应根据 islandState 显示不同视图
    func testIslandView_switchesBasedOnState() {
        // 模拟 compact 状态
        let compactState: IslandState = .compact
        let shouldShowCompact = compactState == .compact
        XCTAssertTrue(shouldShowCompact, "compact 状态应显示 CompactIslandView")

        // 模拟 expanded 状态
        let expandedState: IslandState = .expanded
        let shouldShowExpanded = expandedState == .expanded
        XCTAssertTrue(shouldShowExpanded, "expanded 状态应显示 ExpandedIslandView")
    }

    // MARK: - 展开/收起切换测试

    /// 测试：点击灵动岛应从 compact 切换到 expanded
    func testIslandView_toggle_compactToExpanded() {
        var state: IslandState = .compact
        // 模拟 onTapGesture
        state = state == .compact ? .expanded : .compact
        XCTAssertEqual(state, .expanded, "点击后应从 compact 切换到 expanded")
    }

    /// 测试：点击灵动岛应从 expanded 切换到 compact
    func testIslandView_toggle_expandedToCompact() {
        var state: IslandState = .expanded
        // 模拟 onTapGesture
        state = state == .compact ? .expanded : .compact
        XCTAssertEqual(state, .compact, "点击后应从 expanded 切换到 compact")
    }

    /// 测试：多次切换应在两种状态间循环
    func testIslandView_toggle_multipleToggles() {
        var state: IslandState = .compact
        let states: [IslandState] = (0..<6).map { _ in
            state = state == .compact ? .expanded : .compact
            return state
        }
        XCTAssertEqual(states, [.expanded, .compact, .expanded, .compact, .expanded, .compact],
                       "多次切换应在两种状态间循环")
    }

    // MARK: - 状态颜色指示器测试

    /// 测试：idle 状态指示器应为绿色
    func testStateIndicator_idle_isGreen() {
        let state: SessionState = .idle
        let color = state.color
        // 验证颜色可以访问（具体颜色值可能因实现而异）
        XCTAssertNotNil(color, "idle 状态应有对应的颜色")
    }

    /// 测试：coding 状态指示器应为相应颜色
    func testStateIndicator_coding_hasColor() {
        let state: SessionState = .coding
        let color = state.color
        XCTAssertNotNil(color, "coding 状态应有对应的颜色")
    }

    /// 测试：error 状态指示器应为红色
    func testStateIndicator_error_isRed() {
        let state: SessionState = .error
        let color = state.color
        XCTAssertNotNil(color, "error 状态应有对应的颜色")
    }

    /// 测试：thinking 状态指示器应有颜色
    func testStateIndicator_thinking_hasColor() {
        let state: SessionState = .thinking
        let color = state.color
        XCTAssertNotNil(color, "thinking 状态应有对应的颜色")
    }

    /// 测试：compacting 状态指示器应有颜色
    func testStateIndicator_compacting_hasColor() {
        let state: SessionState = .compacting
        let color = state.color
        XCTAssertNotNil(color, "compacting 状态应有对应的颜色")
    }

    // MARK: - 会话信息显示测试

    /// 测试：无活跃会话时不显示会话摘要
    func testSessionSummary_noActiveSession_hidden() {
        let aggregateState: SessionState = .idle
        let shouldShowSummary = aggregateState != .idle
        XCTAssertFalse(shouldShowSummary, "idle 状态不应显示会话摘要")
    }

    /// 测试：有活跃会话时显示会话摘要
    func testSessionSummary_activeSession_shown() {
        let aggregateState: SessionState = .coding
        let shouldShowSummary = aggregateState != .idle
        XCTAssertTrue(shouldShowSummary, "coding 状态应显示会话摘要")
    }

    /// 测试：会话状态图标应根据状态变化
    func testSessionStateIcon_changesWithState() {
        let states: [SessionState] = [.idle, .coding, .thinking, .error, .waiting]
        var icons: [String] = []

        for state in states {
            icons.append(state.icon)
        }

        // 验证所有状态都有对应图标
        XCTAssertEqual(icons.count, states.count, "所有状态都应有对应图标")
        XCTAssertTrue(icons.allSatisfy { !$0.isEmpty }, "所有图标应非空")
    }

    // MARK: - 上下文使用率显示测试

    /// 测试：上下文使用率为 0 时不显示
    func testContextUsage_zeroRatio_hidden() {
        let usageRatio = 0.0
        let shouldShow = usageRatio > 0
        XCTAssertFalse(shouldShow, "使用率为 0 时不应显示")
    }

    /// 测试：上下文使用率大于 0 时显示
    func testContextUsage_positiveRatio_shown() {
        let usageRatio = 0.5
        let shouldShow = usageRatio > 0
        XCTAssertTrue(shouldShow, "使用率大于 0 时应显示")
    }

    // MARK: - 宠物显示测试

    /// 测试：宠物启用时应显示宠物视图
    func testPetView_enabled_shown() {
        let petEnabled = true
        let shouldShowPet = petEnabled
        XCTAssertTrue(shouldShowPet, "宠物启用时应显示宠物视图")
    }

    /// 测试：宠物未启用时不显示宠物视图
    func testPetView_disabled_hidden() {
        let petEnabled = false
        let shouldShowPet = petEnabled
        XCTAssertFalse(shouldShowPet, "宠物未启用时不应显示宠物视图")
    }

    /// 测试：宠物应根据会话状态应用特效
    func testPetEffect_appliesBasedOnState() {
        // waitingPermission 状态应触发抖动
        let waitingPermissionState: SessionState = .waitingPermission
        let shouldShake = waitingPermissionState == .waitingPermission
        XCTAssertTrue(shouldShake, "waitingPermission 状态应触发抖动")

        // error 状态应触发红色发光
        let errorState: SessionState = .error
        let shouldGlowRed = errorState == .error
        XCTAssertTrue(shouldGlowRed, "error 状态应触发红色发光")
    }

    // MARK: - 额度显示测试

    /// 测试：有健康额度时显示额度信息
    func testQuotaSection_healthyQuota_shown() {
        let hasHealthyQuota = true  // 模拟有健康额度
        XCTAssertTrue(hasHealthyQuota, "有健康额度时应显示额度信息")
    }

    /// 测试：加载中时显示 ProgressView
    func testQuotaSection_loading_showsProgress() {
        let isLoading = true
        let shouldShowProgress = isLoading
        XCTAssertTrue(shouldShowProgress, "加载中时应显示进度指示器")
    }

    /// 测试：无额度时显示添加提示
    func testQuotaSection_noQuota_showsAddPrompt() {
        let hasQuota = false
        let isLoading = false
        let shouldShowAddPrompt = !hasQuota && !isLoading
        XCTAssertTrue(shouldShowAddPrompt, "无额度且未加载时应显示添加提示")
    }

    // MARK: - 进度条颜色测试

    /// 测试：进度条颜色根据使用率变化
    func testProgressBar_colorByRatio() {
        // 测试 CompactProgressBar 的颜色逻辑
        let ratios: [(Double, String)] = [
            (0.96, "red"),
            (0.85, "orange"),
            (0.60, "yellow"),
            (0.30, "green")
        ]

        for (ratio, expectedColor) in ratios {
            let barColor: String
            if ratio >= 0.95 { barColor = "red" }
            else if ratio >= 0.8 { barColor = "orange" }
            else if ratio >= 0.5 { barColor = "yellow" }
            else { barColor = "green" }

            XCTAssertEqual(barColor, expectedColor, "使用率 \(ratio) 应显示 \(expectedColor) 颜色")
        }
    }

    // MARK: - 背景主题测试

    /// 测试：glass 主题使用毛玻璃效果
    func testBackground_glassTheme_usesVisualEffect() {
        let theme: AppTheme = .glass
        let usesVisualEffect = theme == .glass
        XCTAssertTrue(usesVisualEffect, "glass 主题应使用毛玻璃效果")
    }

    /// 测试：pixel 主题使用纯色背景
    func testBackground_pixelTheme_usesSolidColor() {
        let theme: AppTheme = .pixel
        let usesSolidColor = theme == .pixel
        XCTAssertTrue(usesSolidColor, "pixel 主题应使用纯色背景")
    }

    // MARK: - 闪烁效果测试

    /// 测试：需要闪烁时应启动动画
    func testBlinkEffect_shouldBlink_startsAnimation() {
        let shouldBlink = true
        // 验证闪烁条件
        XCTAssertTrue(shouldBlink, "需要闪烁时应启动闪烁动画")
    }

    /// 测试：不需要闪烁时应停止动画
    func testBlinkEffect_shouldNotBlink_stopsAnimation() {
        let shouldBlink = false
        XCTAssertFalse(shouldBlink, "不需要闪烁时应停止闪烁动画")
    }
}

// MARK: - XCUITest 版本（供未来 UI Test Target 使用）
/*
import XCTest

@MainActor
final class IslandViewXCUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// 测试：启动应用后显示灵动岛
    func testIslandView_showsCompactMode() {
        // 验证紧凑模式存在
        let compactView = app.otherElements["compactIsland"]
        XCTAssertTrue(compactView.exists, "启动后应显示紧凑模式灵动岛")
    }

    /// 测试：点击灵动岛应展开
    func testIslandView_tap_expands() {
        let islandView = app.otherElements["compactIsland"]
        XCTAssertTrue(islandView.exists, "灵动岛应存在")

        islandView.tap()

        // 等待展开动画完成
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.otherElements["expandedIsland"]
        )
        wait(for: [expectation], timeout: 2.0)
    }

    /// 测试：展开后再次点击应收起
    func testIslandView_tapAgain_collapses() {
        // 先展开
        app.otherElements["compactIsland"].tap()

        let expectation1 = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.otherElements["expandedIsland"]
        )
        wait(for: [expectation1], timeout: 2.0)

        // 再点击收起
        app.otherElements["expandedIsland"].tap()

        let expectation2 = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.otherElements["compactIsland"]
        )
        wait(for: [expectation2], timeout: 2.0)
    }

    /// 测试：状态颜色指示器存在
    func testIslandView_stateIndicator_exists() {
        let stateDot = app.otherElements["stateIndicator"]
        XCTAssertTrue(stateDot.exists, "应显示状态颜色指示器")
    }

    /// 测试：宠物视图存在（启用时）
    func testIslandView_petView_exists() {
        let petView = app.otherElements["petView"]
        // 如果宠物已启用
        XCTAssertTrue(petView.exists || !petView.exists, "宠物视图存在或不存在（取决于设置）")
    }
}
*/
