import XCTest
@testable import VibeIsland

@MainActor
final class ThemeManagerTests: XCTestCase {

    let pixel = ThemeManager(theme: .pixel)
    let glass = ThemeManager(theme: .glass)

    // MARK: - 文字颜色

    func testPrimaryText_bothThemesWhite() {
        XCTAssertEqual(pixel.primaryText, .white)
        XCTAssertEqual(glass.primaryText, .white)
    }

    func testSecondaryText_bothThemesSame() {
        XCTAssertEqual(pixel.secondaryText, glass.secondaryText)
    }

    func testTertiaryText_bothThemesSame() {
        XCTAssertEqual(pixel.tertiaryText, glass.tertiaryText)
    }

    func testMutedText_bothThemesSame() {
        XCTAssertEqual(pixel.mutedText, glass.mutedText)
    }

    // MARK: - 状态颜色

    func testStateColor_delegatesToSessionState() {
        for state in SessionState.allCases {
            XCTAssertEqual(pixel.stateColor(for: state), state.color)
            XCTAssertEqual(glass.stateColor(for: state), state.color)
        }
    }

    // MARK: - 上下文颜色

    func testContextColor_greenBelow40() {
        XCTAssertEqual(pixel.contextColor(percent: 0), .green)
        XCTAssertEqual(pixel.contextColor(percent: 20), .green)
        XCTAssertEqual(pixel.contextColor(percent: 39), .green)
    }

    func testContextColor_orangeBetween40And69() {
        XCTAssertEqual(pixel.contextColor(percent: 40), .orange)
        XCTAssertEqual(pixel.contextColor(percent: 55), .orange)
        XCTAssertEqual(pixel.contextColor(percent: 69), .orange)
    }

    func testContextColor_redAt70AndAbove() {
        XCTAssertEqual(pixel.contextColor(percent: 70), .red)
        XCTAssertEqual(pixel.contextColor(percent: 90), .red)
        XCTAssertEqual(pixel.contextColor(percent: 100), .red)
    }

    func testContextColor_glassSameAsPixel() {
        for percent in [0, 39, 40, 69, 70, 100] {
            XCTAssertEqual(
                pixel.contextColor(percent: percent),
                glass.contextColor(percent: percent),
                "percent=\(percent)"
            )
        }
    }

    func testProgressFill_matchesContextColor() {
        for percent in [0, 50, 80] {
            XCTAssertEqual(pixel.progressFill(for: percent), pixel.contextColor(percent: percent))
        }
    }

    // MARK: - 背景色

    func testCardBackground_differentBetweenThemes() {
        XCTAssertNotEqual(pixel.cardBackground, glass.cardBackground)
    }

    func testSelectedBackground_differentBetweenThemes() {
        XCTAssertNotEqual(pixel.selectedBackground, glass.selectedBackground)
    }

    func testNormalBackground_differentBetweenThemes() {
        XCTAssertNotEqual(pixel.normalBackground, glass.normalBackground)
    }

    // MARK: - 边框

    func testNormalBorder_differentBetweenThemes() {
        XCTAssertNotEqual(pixel.normalBorder, glass.normalBorder)
    }

    func testSelectedBorder_differentBetweenThemes() {
        XCTAssertNotEqual(pixel.selectedBorder, glass.selectedBorder)
    }

    func testHighlightBorder_pixelIsCyan_glassIsBlue() {
        XCTAssertEqual(pixel.highlightBorder, .cyan)
        XCTAssertEqual(glass.highlightBorder, .blue)
    }

    // MARK: - 圆角 / 间距 / padding

    func testCornerRadius_pixel6_glass8() {
        XCTAssertEqual(pixel.cornerRadius, 6)
        XCTAssertEqual(glass.cornerRadius, 8)
    }

    func testSpacing_pixel6_glass8() {
        XCTAssertEqual(pixel.spacing, 6)
        XCTAssertEqual(glass.spacing, 8)
    }

    func testPadding_pixel8_glass10() {
        XCTAssertEqual(pixel.padding, 8)
        XCTAssertEqual(glass.padding, 10)
    }

    // MARK: - AppTheme 扩展

    func testAppTheme_managerProperty() {
        XCTAssertNotNil(AppTheme.pixel.manager)
        XCTAssertNotNil(AppTheme.glass.manager)
    }

    // MARK: - 其他颜色属性一致性

    func testIconColor_bothThemesSame() {
        XCTAssertEqual(pixel.iconColor, glass.iconColor)
    }

    func testDisabledColor_bothThemesSame() {
        XCTAssertEqual(pixel.disabledColor, glass.disabledColor)
    }

    func testProgressBackground_differentBetweenThemes() {
        XCTAssertNotEqual(pixel.progressBackground, glass.progressBackground)
    }
}
