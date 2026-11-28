import XCTest
import SwiftUI
import AckshuallyCore
@testable import Ackshually

/// Rows with a cover and text (My Games' `GameRow`, Add Rulebooks' `ReviewBookRow`) at the largest text sizes:
/// they stack instead of squeezing the text beside the cover, so no word breaks mid-word (#27: "Opene / d now",
/// "Po / we / r" on a 13 mini at AX5, worse with the selection circle).
@MainActor
final class AccessibilityRowLayoutTests: XCTestCase {
    private var host: HostedView?

    override func tearDown() async throws { host?.close(); host = nil }

    /// Widths a row's content gets in a 375 pt list: browsing (insets and chevron) and selecting (plus the
    /// selection circle).
    private static let rowWidths: [CGFloat] = [295, 250]

    /// The widest word of `text` in `style` (semibold when `bold`) at `typeSize`.
    private func longestWord(_ text: String, _ style: UIFont.TextStyle, bold: Bool = false, typeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
        var font = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        if bold, let d = font.fontDescriptor.withSymbolicTraits(.traitBold) { font = UIFont(descriptor: d, size: font.pointSize) }
        return text.split(separator: " ").map { (String($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
    }

    private func hostRow(width: CGFloat, typeSize: DynamicTypeSize, @ViewBuilder _ row: () -> some View) async -> HostedView {
        let h = HostedView(size: CGSize(width: width, height: 1600), typeSize: typeSize) {
            row().frame(width: width).frame(maxHeight: .infinity, alignment: .top)
        }
        host = h
        await h.settle()
        return h
    }

    private func assertNoBrokenWords(_ h: HostedView, _ texts: [(id: String, text: String, style: UIFont.TextStyle, bold: Bool)],
                                     typeSize: DynamicTypeSize, context: String) throws {
        for t in texts {
            let frame = try XCTUnwrap(h.frame(t.id), "\(t.id) (\(context))")
            let word = longestWord(t.text, t.style, bold: t.bold, typeSize: typeSize)
            XCTAssertGreaterThanOrEqual(frame.width + 1, word, "\(t.id) is \(frame.width) pt wide, \"\(t.text)\" needs \(word) (\(context))")
        }
    }

    func testGameRowStacksAtAccessibilitySizes() async throws {
        let opened = Date.now.addingTimeInterval(-120)
        for typeSize in [DynamicTypeSize.accessibility3, .accessibility5] {
            for width in Self.rowWidths {
                let h = await hostRow(width: width, typeSize: typeSize) {
                    GameRow(title: "Power plant rush", books: "2 rulebooks", lastOpened: opened, cover: nil)
                }
                let detail = "Opened \(opened.formatted(.relative(presentation: .named)))"
                try assertNoBrokenWords(h, [("gameTitle", "Power plant rush", .body, true), ("gameBooks", "2 rulebooks", .subheadline, false),
                                            ("gameOpened", detail, .subheadline, false)],
                                        typeSize: typeSize, context: "\(typeSize), \(width) pt")
                h.close()
            }
        }
    }

    func testGameRowKeepsTheCoverBesideTheTextAtDefaultSizes() async throws {
        let h = await hostRow(width: 295, typeSize: .large) {
            GameRow(title: "Power plant rush", lastOpened: .now, cover: nil)
        }
        // The cover (44 pt, hidden from VoiceOver) sits on the leading side, the text after it.
        XCTAssertGreaterThan(try XCTUnwrap(h.frame("gameTitle")).minX, 44, "side by side")
    }

    func testReviewRowStacksAtAccessibilitySizes() async throws {
        let book = AddRulebooksFixtures.book("storms.pdf", "Storms: The Weather Expansion", reason: "expansion booklet")
        for width in Self.rowWidths {
            let h = await hostRow(width: width, typeSize: .accessibility5) {
                ReviewBookRow(book: book, cover: nil, role: .addOn, onRename: {}, onSetRole: { _ in })
            }
            try assertNoBrokenWords(h, [("reviewTitle", book.title, .body, false), ("reviewReason", "expansion booklet", .subheadline, false)],
                                    typeSize: .accessibility5, context: "\(width) pt")
            h.close()
        }
    }
}
