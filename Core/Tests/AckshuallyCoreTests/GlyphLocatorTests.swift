import XCTest
import CoreGraphics
@testable import AckshuallyCore

/// PDFKit's character geometry skips the line breaks in `PDFPage.string` (and can drift a few
/// more characters), so boxes taken at string indices land several words late. See GlyphLocator.
final class GlyphLocatorTests: XCTestCase {
    /// Lays `lines` out like a page (12 pt lines, widths by character class) and returns the
    /// page string plus a geometry lookup indexed the way PDFKit does: no entries for "\n",
    /// `drift` extra entries at the start.
    private func page(_ lines: [String], drift: Int = 0) -> (NSString, (Int) -> CGRect, [CGRect]) {
        var geometry: [CGRect] = Array(repeating: CGRect(x: 500, y: 700, width: 4, height: 9), count: drift)
        var lineRects: [CGRect] = []
        for (n, line) in lines.enumerated() {
            var x: CGFloat = 40
            let y = CGFloat(700 - n * 14)
            var r = CGRect.null
            for u in line.utf16 {
                let w = CGFloat(GlyphLocator.width(of: u) * 10)
                let b = CGRect(x: x, y: y, width: w, height: 10)
                geometry.append(b)
                if !GlyphLocator.isSpace(u) { r = r.union(b) }
                x += w
            }
            lineRects.append(r)
        }
        let s = lines.joined(separator: "\n") as NSString
        return (s, { $0 >= 0 && $0 < geometry.count ? geometry[$0] : .zero }, lineRects)
    }

    private let text = [
        "The starting player places the starting player marker in the",
        "center of the table and then takes the first turn. Play then",
        "continues clockwise.",
        "On your turn, you must pick tiles in one of the following ways:",
        "EITHER",
        "Pick all tiles of the same color from any one Factory display",
    ]

    func testSkipsLineBreaksLikePDFKit() throws {
        let (s, bounds, lines) = page(text)
        let r = s.range(of: "On your turn, you must pick tiles in one of the following ways")
        // The naive lookup (string index) lands three characters late: the bug seen on Azul p.3 (14 line breaks there).
        XCTAssertGreaterThan(bounds(r.location).minX, lines[3].minX + 10)
        let located = try XCTUnwrap(GlyphLocator.locate(range: r, in: s, bounds: bounds))
        XCTAssertEqual(located.rects.count, 1)
        XCTAssertEqual(located.rects[0].minX, lines[3].minX, accuracy: 0.5)
        XCTAssertEqual(located.rects[0].minY, lines[3].minY, accuracy: 0.5)
        XCTAssertGreaterThan(located.score, 0.8)
    }

    func testQuoteAcrossLinesWithDrift() throws {
        let (s, bounds, lines) = page(text, drift: 3)
        let r = s.range(of: "takes the first turn. Play then\ncontinues clockwise.")
        let located = try XCTUnwrap(GlyphLocator.locate(range: r, in: s, bounds: bounds))
        XCTAssertEqual(located.rects.count, 2)
        XCTAssertEqual(located.rects[0].midY, lines[1].midY, accuracy: 0.5)
        XCTAssertEqual(located.rects[0].maxX, lines[1].maxX, accuracy: 0.5)
        XCTAssertEqual(located.rects[1], lines[2])
    }

    func testNoGeometryWhenNothingFits() {
        let s = "On your turn, you must pick tiles in one of the following ways" as NSString
        // Every box the same width: no mapping can be checked, so no (possibly wrong) rects.
        let located = GlyphLocator.locate(range: NSRange(location: 0, length: s.length), in: s) { _ in CGRect(x: 0, y: 0, width: 5, height: 10) }
        XCTAssertNil(located)
    }
}
