import SwiftUI

// MARK: - Vibe Island 字体系统

extension Font {
    /// 10pt medium — compact island labels
    static let islandCompact = Font.system(size: 10, weight: .medium)
    /// 11pt regular — captions, timestamps
    static let islandCaption = Font.system(size: 11)
    /// 12pt regular — card body text
    static let islandBody = Font.system(size: 12)
    /// 13pt semibold — section headings
    static let islandHeading = Font.system(size: 13, weight: .semibold)
    /// 15pt bold — card titles
    static let islandTitle = Font.system(size: 15, weight: .bold)
}

extension Font {
    /// Monospaced variant of islandCaption
    static let islandCaptionMono = Font.system(size: 11, design: .monospaced)
    /// Monospaced variant of islandBody
    static let islandBodyMono = Font.system(size: 12, design: .monospaced)
}
