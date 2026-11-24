import Foundation
import CoreGraphics
import CoreText

/// A small fake rulebook ("Power Plant Rush") with a real text layer, used for tests and for
/// smoke-running the bench before the real rulebook PDFs exist. Includes the SPEC's
/// energy/Battery example, a hyphenated line break, an exception on another page and a figure.
public enum FixtureRulebook {
    public struct Page: Sendable {
        public var title: String
        public var paragraphs: [String]
        /// Figure rect normalized 0–1, origin top-left.
        public var figure: (box: NormalizedBox, label: String)?
    }

    public static let pages: [Page] = [
        Page(title: "Power Plant Rush — Rules", paragraphs: [
            "Power Plant Rush is a game for 2 to 4 players. Each player builds power plants and produces energy to score victory points.",
            "Contents: 40 energy cubes, 12 plant cards, 4 player boards, 1 scoring track.",
        ]),
        Page(title: "1. Turn order", paragraphs: [
            "Each round has three phases: Build, Produce and Clean-up. Players take turns in clockwise order starting with the first player.",
            "Build: you may buy one plant card by paying its cost in coins. You may never own more than three plants.",
            "Produce: each plant you own produces the number of energy cubes shown on its card.",
        ]),
        Page(title: "2. End of turn", paragraphs: [
            "Clean-up: at the end of your turn you must discard all unused energy. Discarded energy cubes return to the general supply.",
            "Energy may not be traded between players at any time, unless a card explicitly says so.",
            "Scoring: every 3 energy spent on a contract scores 1 victory point.",
        ]),
        Page(title: "3. Special plants", paragraphs: [
            // Long run-on paragraph so the line breaker splits words (hyphenation-like breaks).
            "Battery: the Battery is a storage plant. At the end of your turn, a player who owns a Battery keeps up to 2 unused energy instead of discarding them. Any additional energy is discarded as normal.",
            "Windmill: produces 1 energy, or 2 energy if no other player owns a Windmill.",
        ], figure: (NormalizedBox(x: 0.15, y: 0.55, w: 0.7, h: 0.3), "Figure 1: scoring track")),
    ]

    /// A made-up add-on for the sample ("Solar Expansion"), for several-rulebook tests and previews (S13).
    /// Its Battery rule overrides the base game's on purpose.
    public static let expansionPages: [Page] = [
        Page(title: "Solar Expansion — Rules", paragraphs: [
            "The Solar Expansion adds 4 solar plant cards and a weather die. Shuffle the solar plants into the plant deck.",
            "Solar plants produce 2 energy on a sunny roll of the weather die and nothing otherwise.",
        ]),
        Page(title: "Changes to the base game", paragraphs: [
            "Storage: with this expansion, a player who owns a Battery keeps up to 3 unused energy at the end of the turn.",
            "Weather: the first player rolls the weather die at the start of each round.",
        ]),
    ]

    /// Writes the fixture PDF (the base game, or `pages` such as `expansionPages`) and returns its URL.
    @discardableResult
    public static func write(to url: URL, pages: [Page] = pages) throws -> URL {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw AssemblyError(message: "cannot create PDF context at \(url.path)")
        }
        let body = CTFontCreateWithName("Helvetica" as CFString, 13, nil)
        let head = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
        for page in pages {
            ctx.beginPDFPage(nil)
            let text = NSMutableAttributedString()
            text.append(NSAttributedString(string: page.title + "\n\n", attributes: [.init(kCTFontAttributeName as String): head]))
            for p in page.paragraphs {
                text.append(NSAttributedString(string: p + "\n\n", attributes: [.init(kCTFontAttributeName as String): body]))
            }
            let setter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
            // Text in the top half (narrow column → more line breaks).
            let textRect = CGRect(x: 72, y: 792 * 0.5, width: 300, height: 792 * 0.5 - 60)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: textRect, transform: nil), nil)
            CTFrameDraw(frame, ctx)
            if let fig = page.figure {
                let r = CGRect(x: fig.box.x * 612, y: (1 - fig.box.y - fig.box.h) * 792, width: fig.box.w * 612, height: fig.box.h * 792)
                ctx.setStrokeColor(CGColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1))
                ctx.setLineWidth(3)
                ctx.stroke(r)
                for i in 0..<10 {
                    let cell = CGRect(x: r.minX + 10 + CGFloat(i) * (r.width - 20) / 10, y: r.midY - 15, width: (r.width - 20) / 10 - 4, height: 30)
                    ctx.setFillColor(CGColor(red: 0.9, green: 0.7 - Double(i) * 0.05, blue: 0.2, alpha: 1))
                    ctx.fill(cell)
                }
            }
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }
}
