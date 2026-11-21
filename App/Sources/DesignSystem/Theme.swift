import SwiftUI

/// Design tokens (spec §3), injected through the environment: `@Environment(\.theme)`.
/// Views use only these semantic tokens, so restyling (density, dark mode, alternates) is a
/// change here. Spacing and sizes are scaled with Dynamic Type by `ThemeProvider`.
struct Theme: Sendable {
    var colors: Colors
    var radius: Radius
    var spacing: Spacing
    var size: Sizes
    var font: Fonts
    var layout: Layout

    struct Colors: Sendable {
        var background: Color      // app chrome, nav, around the PDF
        var paper: Color
        var sheet: Color           // answer sheet: a shade darker than the page
        var card: Color            // step cards, rows, fields
        var ink: Color
        var muted: Color
        var line: Color            // borders, dividers, inactive dots
        var accent: Color          // primary actions, active dot, warnings
        var accentInk: Color
        var stated: Color
        var statedBG: Color
        var warning: Color
        var warningBG: Color
        var shadow: Color
        var highlightFill: Color   // evidence on the PDF
        var highlightOutline: Color
        var figureFill: Color
    }

    struct Radius: Sendable {
        var sheet: CGFloat = 16
        var card: CGFloat = 12
        var row: CGFloat = 10
        var button: CGFloat = 9
        var label: CGFloat = 6
        var field: CGFloat = 22
    }

    struct Spacing: Sendable {
        var xxs: CGFloat = 2
        var xs: CGFloat = 4
        var s: CGFloat = 6
        var m: CGFloat = 8
        var l: CGFloat = 12
        var xl: CGFloat = 16
        var xxl: CGFloat = 24

        func scaled(_ f: CGFloat) -> Spacing {
            Spacing(xxs: xxs * f, xs: xs * f, s: s * f, m: m * f, l: l * f, xl: xl * f, xxl: xxl * f)
        }
    }

    struct Sizes: Sendable {
        var micButton: CGFloat = 32
        var micButtonCompact: CGFloat = 26
        var cardMinHeight: CGFloat = 88
        var grabber = CGSize(width: 36, height: 5)
        var dot: CGFloat = 6
        var activeDot: CGFloat = 14
        var waveHeight: CGFloat = 18
        var waveBar: CGFloat = 2.5
        var hairline: CGFloat = 1
        var focusRing: CGFloat = 1.5
        var wordOutline: CGFloat = 1
        var figureOutline: CGFloat = 3
        var skeletonLine: CGFloat = 10
        var skeletonTitle: CGFloat = 16

        func scaled(_ f: CGFloat) -> Sizes {
            var s = self
            s.micButton *= f; s.micButtonCompact *= f; s.cardMinHeight *= f
            s.dot *= min(f, 1.4); s.activeDot *= min(f, 1.4); s.waveHeight *= f
            s.skeletonLine *= f; s.skeletonTitle *= f
            return s
        }
    }

    /// Text styles only (Dynamic Type).
    struct Fonts: Sendable {
        var verdict = Font.title2.weight(.bold)
        var verdictTracking: CGFloat = -0.4
        var restated = Font.footnote
        var question = Font.subheadline.weight(.semibold)
        var body = Font.subheadline
        var bodyStrong = Font.subheadline.weight(.medium)
        var cardTitle = Font.footnote.weight(.bold)
        var meta = Font.footnote
        var chip = Font.caption.weight(.semibold)
        var section = Font.caption.weight(.semibold)
        var pill = Font.footnote.weight(.semibold)
        var field = Font.body
        var fieldCompact = Font.subheadline
        var title = Font.title2.weight(.bold)
        var emoji = Font.title3
        var icon = Font.subheadline.weight(.bold)
    }

    /// Relative layout rules (fractions, thresholds), never absolute frames.
    struct Layout: Sendable {
        /// Each neighbour card peeks this fraction of the carousel width (card ≈ 84%).
        var cardPeekFraction: CGFloat = 0.08
        /// Medium detent: content-sized, capped at this fraction of the available height.
        var sheetMediumMaxFraction: CGFloat = 0.62
        /// Expanded detent: this fraction of the available height.
        var sheetExpandedFraction: CGFloat = 0.94
        /// Side-by-side when the viewer is at least this wide and wider than tall…
        var sideBySideMinWidth: CGFloat = 640
        /// …with the answer panel taking this fraction of the width, within these bounds.
        var sidePanelFraction: CGFloat = 0.38
        var sidePanelWidthRange: ClosedRange<CGFloat> = 320...460
        /// Readable width for the bottom sheet on very wide-but-short windows.
        var sheetMaxWidth: CGFloat = 720
        var holdToTalkDelay: Duration = .milliseconds(280)
        var slideToCancelFraction: CGFloat = 0.18
        var pdfMoveDuration: TimeInterval = 0.35
        /// Largest text size for the answer header: past this it would push the cards off the sheet.
        var maxHeaderTypeSize: DynamicTypeSize = .accessibility2
        /// Evidence zoom: never more than this × the page-width scale.
        var maxEvidenceZoom: CGFloat = 3.2
    }

    var sheetAnimation: Animation { .snappy(duration: 0.3) }
}

extension Theme {
    static let warm = Theme(
        colors: Colors(background: Color(hex: 0xEFE4D0), paper: Color(hex: 0xFBF5E9), sheet: Color(hex: 0xF4E9D5),
                       card: Color(hex: 0xFFFAF0), ink: Color(hex: 0x33261B), muted: Color(hex: 0x8A735C),
                       line: Color(hex: 0xD8C6A8), accent: Color(hex: 0xA2412B), accentInk: Color(hex: 0xFFF7EC),
                       stated: Color(hex: 0x3F6B2A), statedBG: Color(hex: 0xE3EFD9),
                       warning: Color(hex: 0xA2412B), warningBG: Color(hex: 0xA2412B).opacity(0.1),
                       shadow: .black.opacity(0.16),
                       highlightFill: Color(hex: 0xF2B134).opacity(0.42), highlightOutline: Color(hex: 0xD39320),
                       figureFill: Color(hex: 0xF2B134).opacity(0.12)),
        radius: Radius(), spacing: Spacing(), size: Sizes(), font: Fonts(), layout: Layout())

    /// Provisional: dark mode isn't designed yet (spec §8). Same hues, dimmed chrome.
    static let warmDark: Theme = {
        var t = warm
        t.colors = Colors(background: Color(hex: 0x1F1A15), paper: Color(hex: 0x2A241E), sheet: Color(hex: 0x29221B),
                          card: Color(hex: 0x372E25), ink: Color(hex: 0xF1E6D4), muted: Color(hex: 0xB39D84),
                          line: Color(hex: 0x4D4134), accent: Color(hex: 0xD0674D), accentInk: Color(hex: 0x1F1A15),
                          stated: Color(hex: 0xA8D08D), statedBG: Color(hex: 0x2F3E26),
                          warning: Color(hex: 0xE07A5F), warningBG: Color(hex: 0xE07A5F).opacity(0.16),
                          shadow: .black.opacity(0.5),
                          highlightFill: Color(hex: 0xF2B134).opacity(0.42), highlightOutline: Color(hex: 0xD39320),
                          figureFill: Color(hex: 0xF2B134).opacity(0.12))
        return t
    }()

    /// Spacing and control sizes grow with text (clamped so AX sizes stay usable).
    func scaled(for size: DynamicTypeSize) -> Theme {
        let f = Self.scale(for: size)
        var t = self
        t.spacing = spacing.scaled(min(f, 1.6))
        t.size = self.size.scaled(f)
        return t
    }

    static func scale(for size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        return min(max(UIFontMetrics(forTextStyle: .body).scaledValue(for: 1, compatibleWith: traits), 0.85), 2.2)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
