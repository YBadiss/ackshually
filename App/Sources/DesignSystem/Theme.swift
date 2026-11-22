import SwiftUI
import UIKit

/// Design tokens (spec §3, "native iOS, warm"), injected through the environment:
/// `@Environment(\.theme)`. Views use only these semantic tokens. Every color is a dynamic
/// light/dark pair, so the same token also works inside UIKit (PDFKit) and follows the
/// appearance by itself. Spacing and sizes are scaled with Dynamic Type by `ThemeProvider`.
struct Theme: Sendable {
    var colors: Colors
    var radius: Radius
    var spacing: Spacing
    var size: Sizes
    var font: Fonts
    var layout: Layout

    struct Colors: Sendable {
        /// App tint (brick red): buttons, links, selection.
        var tint: Color
        /// Navigation bar: a clearly darker warm tone than the sheet and the canvas, so bar, PDF
        /// and answer panel read as separate surfaces (owner feedback 2026-11-21, landscape).
        var navigationBar: Color
        /// Hairline under the navigation bar and between the PDF and the answer column.
        var chromeSeparator: Color
        /// Canvas around the PDF pages.
        var canvas: Color
        /// Answer sheet / inspector background (warm, a shade off the page).
        var sheet: Color
        /// Grouped backgrounds outside the sheet (empty state, settings).
        var groupedBackground: Color
        /// Step cards and grouped rows on the sheet.
        var card: Color
        /// Inline text field fill on the sheet (follow-up).
        var fieldFill: Color
        var label: Color
        var secondaryLabel: Color
        var tertiaryLabel: Color
        var separator: Color
        /// Proof line symbol per confidence.
        var stated: Color
        var inferred: Color
        var notCovered: Color
        /// Web findings that disagree (S10).
        var warning: Color
        var dot: Color
        var dotActive: Color
        /// Spotlight on the cited passage: the rest of the evidence page is dimmed with this…
        var spotlightDim: Color
        /// …and the passage (word lines or figure box) gets a solid outline in the app tint
        /// (brick), a colour rulebooks don't use for their own frames.
        var highlightOutline: Color
    }

    struct Radius: Sendable {
        /// Step cards (App Store / Music shelf cards).
        var card: CGFloat = 18
        /// Inline field on the sheet.
        var field: CGFloat = 20
        /// Grouped sections (inset-grouped rows, like Settings).
        var group: CGFloat = 22
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
        /// HIG minimum tap area.
        var minTapTarget: CGFloat = 44
        var cardMinHeight: CGFloat = 92
        var dot: CGFloat = 7
        var waveHeight: CGFloat = 18
        var waveBar: CGFloat = 2.5
        /// Outline widths in PDF page points (they zoom with the page).
        var wordOutline: CGFloat = 1.6
        var figureOutline: CGFloat = 2.4
        /// Space between the cited text and its outline, in PDF page points.
        var highlightPadding: CGFloat = 2.5

        func scaled(_ f: CGFloat) -> Sizes {
            var s = self
            s.cardMinHeight *= f
            s.dot *= min(f, 1.4)
            s.waveHeight *= f
            return s
        }
    }

    /// Text styles only (Dynamic Type). Hierarchy comes from size and weight, not decoration.
    struct Fonts: Sendable {
        var verdict = Font.title3.weight(.bold)
        var proof = Font.subheadline
        var question = Font.subheadline
        var cardCaption = Font.footnote.weight(.semibold)
        var cardBody = Font.callout
        var cardStrong = Font.callout.weight(.semibold)
        var row = Font.body
        var rowValue = Font.subheadline
        var footnote = Font.footnote
        var sectionHeader = Font.footnote.weight(.semibold)
        var field = Font.body
        var waiting = Font.subheadline.weight(.semibold)
        var feedback = Font.title3
    }

    /// Relative layout rules (fractions, thresholds), never absolute frames.
    struct Layout: Sendable {
        /// Each neighbour card peeks this fraction of the carousel width.
        var cardPeekFraction: CGFloat = 0.08
        /// Medium detent: content-sized, capped at this fraction of the window height.
        var sheetMediumMaxFraction: CGFloat = 0.7
        /// Collapsed detent never taller than this fraction (AX sizes).
        var sheetCollapsedMaxFraction: CGFloat = 0.3
        /// Side-by-side (inspector) when the viewer is at least this wide and wider than tall…
        var sideBySideMinWidth: CGFloat = 640
        /// …with the inspector column in this range, ideally this fraction of the width.
        var inspectorFraction: CGFloat = 0.38
        var inspectorWidthRange: ClosedRange<CGFloat> = 320...460
        /// Readable width for the floating ask field on wide windows.
        var askFieldMaxWidth: CGFloat = 640
        var holdToTalkDelay: Duration = .milliseconds(280)
        var slideToCancelFraction: CGFloat = 0.18
        var pdfMoveDuration: TimeInterval = 0.35
        /// Verdict in the header: at most this many lines (the full text is in the expanded view).
        var verdictMaxLines = 3
        /// Step card text: at most this many lines; all cards take the height of the tallest one
        /// and longer text truncates with "More".
        var cardMaxLines = 5
        /// Largest text size for the answer header: past this it would push the cards off the sheet.
        var maxHeaderTypeSize: DynamicTypeSize = .accessibility2
        /// Evidence zoom: never more than this × the page-width scale.
        var maxEvidenceZoom: CGFloat = 3.2
        /// Wait this long after the sheet stops moving before re-centering the PDF.
        var sheetSettleDelay: Duration = .milliseconds(160)
    }

    var sheetAnimation: Animation { .snappy(duration: 0.3) }
}

extension Theme {
    /// Warm but restrained: brick tint, warm bars / sheet / grouped backgrounds; text and
    /// separators are the system's own so hierarchy reads as iOS.
    static let warm = Theme(
        colors: Colors(
            tint: Color(light: 0xA2412B, dark: 0xE2775C),
            navigationBar: Color(light: 0xE2D3BD, dark: 0x0E0C0A),
            chromeSeparator: Color(light: 0xC9B79E, dark: 0x3A332C),
            canvas: Color(light: 0xF3ECE1, dark: 0x1C1916),
            sheet: Color(light: 0xF6EFE4, dark: 0x221E1A),
            groupedBackground: Color(light: 0xF3ECE1, dark: 0x14110F),
            card: Color(light: 0xFFFDF9, dark: 0x2F2A25),
            fieldFill: Color(light: 0xEDE3D4, dark: 0x3A342D),
            label: Color(uiColor: .label),
            secondaryLabel: Color(uiColor: .secondaryLabel),
            tertiaryLabel: Color(uiColor: .tertiaryLabel),
            separator: Color(uiColor: .separator),
            stated: Color(uiColor: .systemGreen),
            inferred: Color(uiColor: .systemOrange),
            notCovered: Color(uiColor: .secondaryLabel),
            warning: Color(light: 0xA2412B, dark: 0xE2775C),
            dot: Color(uiColor: .tertiaryLabel),
            dotActive: Color(uiColor: .label),
            spotlightDim: Color(light: 0x1A1410, dark: 0x000000, alpha: 0.34),
            highlightOutline: Color(light: 0xA2412B, dark: 0xE2775C)),
        radius: Radius(), spacing: Spacing(), size: Sizes(), font: Fonts(), layout: Layout())

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
    /// A dynamic color that resolves per appearance (also inside UIKit views).
    init(light: UInt32, dark: UInt32, alpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light, alpha: alpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
