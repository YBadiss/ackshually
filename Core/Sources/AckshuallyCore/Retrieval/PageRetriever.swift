import Foundation

// Local page retrieval: rank rulebook pages for a question with BM25 over the PDF text layer, so the
// provider can send only the relevant pages (speed experiment, see docs/speed-report.md).

/// Tokenizer shared by indexing and queries: case/diacritic folding, split on non-alphanumerics,
/// stop words dropped, light English stemming. Same function on both sides, so stems only need to be
/// consistent, not linguistically right.
public enum RetrievalText {
    static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "if", "then", "so", "of", "to", "in", "on", "at", "by", "for",
        "with", "from", "into", "onto", "as", "is", "are", "was", "were", "be", "been", "being", "am", "it",
        "its", "this", "that", "these", "those", "there", "their", "they", "them", "he", "she", "his", "her",
        "you", "your", "yours", "we", "us", "our", "i", "me", "my", "mine", "im", "do", "does", "did", "doing",
        "have", "has", "had", "can", "could", "will", "would", "should", "shall", "may", "might", "must",
        "not", "no", "yes", "what", "which", "who", "whom", "when", "where", "why", "how", "all", "any",
        "each", "other", "some", "such", "only", "own", "same", "than", "too", "very", "just", "also", "now",
        "up", "down", "out", "about", "over", "again", "still", "anyway", "ok", "okay", "wait", "gotta", "gonna",
        "get", "got", "let", "lets", "s", "t", "d", "ll", "re", "ve", "don", "doesn", "isn", "aren", "can't",
        "dont", "cant", "like", "one", "two", "thing", "stuff", "guy", "even", "though", "both", "already",
    ]

    /// Cheap, game-agnostic table-talk → rulebook vocabulary. Applied to queries only, at half weight.
    static let synonyms: [String: [String]] = [
        "guys": ["warrior", "piece", "unit", "troop"],
        "fight": ["combat", "battle", "conflict"],
        "attack": ["battle", "combat", "attacker"],
        "spot": ["clearing", "space", "location", "city"],
        "tie": ["tied", "tiebreaker"],
        "tied": ["tie", "tiebreaker"],
        "win": ["winner", "victory", "wins"],
        "wins": ["winner", "victory"],
        "points": ["victory", "score", "vp"],
        "money": ["coin", "coins", "money", "elektro", "solari", "gold"],
        "pay": ["cost", "spend"],
        "cost": ["pay", "spend"],
        "chill": ["pass"],
        "skip": ["pass"],
        "dump": ["discard", "place"],
        "throw": ["place", "put"],
        "put": ["place"],
        "owns": ["rule", "rules", "control"],
        "own": ["rule", "rules", "control"],
        "walk": ["move", "movement"],
        "leave": ["move", "movement"],
        "end": ["end", "over"],
        "over": ["end"],
        "good": ["reward", "first"],
        "start": ["first", "begin"],
        "later": ["first", "round"],
    ]

    public static func terms(_ s: String) -> [String] {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
        var out: [String] = []
        var cur = ""
        func flush() {
            defer { cur = "" }
            guard !cur.isEmpty else { return }
            let w = cur.replacingOccurrences(of: "'", with: "")
            guard !stopWords.contains(w), !w.isEmpty else { return }
            if w.count < 2 && !w.allSatisfy(\.isNumber) { return }
            out.append(stem(w))
        }
        for ch in folded {
            if ch.isLetter || ch.isNumber || ch == "'" { cur.append(ch) } else { flush() }
        }
        flush()
        return out
    }

    /// Terms plus adjacent-term bigrams ("reveal_turn", "combat_spac"): rulebook headings and
    /// keywords are often two-word phrases, and bigrams separate the defining page from pages that
    /// only mention both words.
    public static func indexTerms(_ s: String) -> [String] {
        let t = terms(s)
        guard t.count > 1 else { return t }
        var out = t
        for i in 1..<t.count { out.append("\(t[i - 1])_\(t[i])") }
        return out
    }

    /// Raw (unstemmed) words of a query, for synonym lookup.
    static func words(_ s: String) -> [String] {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }

    /// Light suffix stripping (plural, -ing, -ed, -ly). Not Porter; good enough for BM25 on rulebooks.
    public static func stem(_ w: String) -> String {
        var s = w
        func strip(_ suf: String, minStem: Int = 3) -> Bool {
            guard s.hasSuffix(suf), s.count - suf.count >= minStem else { return false }
            s.removeLast(suf.count)
            return true
        }
        if strip("ies") { s += "y" }
        else if strip("sses") { s += "ss" }
        else if s.hasSuffix("s"), !s.hasSuffix("ss"), !s.hasSuffix("us"), !s.hasSuffix("is"), s.count > 3 { s.removeLast() }
        var stripped = strip("ing")
        if !stripped, s.hasSuffix("ed") {
            stripped = strip("ed")
            if !stripped { s.removeLast() } // tied → tie
        }
        if stripped {
            // undouble: running → runn → run, stopped → stopp → stop
            if let last = s.last, s.count >= 4, s.dropLast().last == last, !"lsz".contains(last) { s.removeLast() }
            if s.hasSuffix("e"), s.count > 3 { s.removeLast() }
        } else if s.hasSuffix("e"), s.count > 3 {
            s.removeLast() // place/placing → plac, move/moved/moving → mov
        }
        if strip("ly", minStem: 4) {}
        return s
    }
}

/// BM25 index over the pages of one rulebook. Pages are 1-based everywhere in the public API.
public struct PageIndex: Sendable {
    public let pageCount: Int
    let termFreqs: [[String: Int]]
    let lengths: [Int]
    let docFreq: [String: Int]
    let avgLength: Double
    public var k1 = 1.2
    public var b = 0.75

    /// `headings`: per-page heading text (optional); its terms count `headingBoost` extra times,
    /// so the page that *defines* a rule ("Moving Around the Map") beats pages that only mention it.
    public init(pageTexts: [String], headings: [String] = [], headingBoost: Int = 3) {
        pageCount = pageTexts.count
        var tfs: [[String: Int]] = []
        var lens: [Int] = []
        var df: [String: Int] = [:]
        for (i, t) in pageTexts.enumerated() {
            let terms = RetrievalText.indexTerms(t)
            var tf: [String: Int] = [:]
            for x in terms { tf[x, default: 0] += 1 }
            if i < headings.count {
                for x in RetrievalText.terms(headings[i]) { tf[x, default: 0] += headingBoost }
            }
            for x in tf.keys { df[x, default: 0] += 1 }
            tfs.append(tf)
            lens.append(terms.count)
        }
        termFreqs = tfs
        lengths = lens
        docFreq = df
        let total = lens.reduce(0, +)
        avgLength = pageTexts.isEmpty ? 1 : max(1, Double(total) / Double(pageTexts.count))
    }

    /// Weighted query terms: the question at weight 1, synonyms at 0.5, earlier questions in the
    /// conversation at 0.5 (follow-ups like "and if we also have the same money?" lean on them).
    nonisolated(unsafe) public static var bigramWeight = 1.0

    public static func queryTerms(question: String, history: [String] = []) -> [String: Double] {
        var q: [String: Double] = [:]
        func add(_ text: String, weight: Double) {
            // Bare numbers ("2 pieces", "3 plants") match tables and examples everywhere: drop them.
            for t in RetrievalText.indexTerms(text) where !t.split(separator: "_").contains(where: { $0.allSatisfy(\.isNumber) }) { q[t] = max(q[t] ?? 0, weight * (t.contains("_") ? bigramWeight : 1)) }
            for w in RetrievalText.words(text) {
                for syn in RetrievalText.synonyms[w] ?? [] {
                    for t in RetrievalText.terms(syn) { q[t] = max(q[t] ?? 0, weight * 0.5) }
                }
            }
        }
        for h in history { add(h, weight: 0.5) }
        add(question, weight: 1)
        return q
    }

    /// BM25 score per page (index 0 = page 1).
    public func scores(_ query: [String: Double]) -> [Double] {
        let n = Double(pageCount)
        return (0..<pageCount).map { i in
            var s = 0.0
            let len = Double(lengths[i])
            for (term, w) in query {
                guard let f = termFreqs[i][term], f > 0 else { continue }
                let df = Double(docFreq[term] ?? 0)
                let idf = log(1 + (n - df + 0.5) / (df + 0.5))
                let tf = Double(f)
                s += w * idf * tf * (k1 + 1) / (tf + k1 * (1 - b + b * len / avgLength))
            }
            return s
        }
    }

    /// Per-term BM25 contribution on one page (debugging retrieval misses), largest first.
    public func explain(_ query: [String: Double], page: Int) -> [(term: String, score: Double)] {
        guard page >= 1, page <= pageCount else { return [] }
        return query.keys.compactMap { t -> (String, Double)? in
            let one = scores([t: query[t]!])[page - 1]
            return one > 0 ? (t, one) : nil
        }.sorted { $0.1 > $1.1 }
    }

    public func scores(question: String, history: [String] = []) -> [Double] {
        scores(Self.queryTerms(question: question, history: history))
    }
}

/// How many pages to pick and when to give up and send the whole PDF.
public struct PageSelectionOptions: Sendable, Equatable, Codable {
    /// Best-ranked pages to keep.
    public var topK: Int
    /// Pages either side of each top page to add (rules often run over a page break).
    public var neighbors: Int
    /// Hard cap on pages sent (ranked pages first, then neighbours in rank order). nil = no cap.
    public var maxPages: Int?
    /// If the selection would cover at least this share of the book, send the full PDF instead
    /// (nothing to gain, and the full PDF caches across questions).
    public var fullIfCoverage: Double
    /// Below this retrieval confidence (0–1) send the full PDF. 0 = never.
    public var minConfidence: Double
    /// Excerpt said not_covered → re-ask with the full PDF (subset events are held until
    /// confidence arrives, so the UI never sees the discarded attempt).
    public var fallbackOnNotCovered: Bool
    /// How the pages are sent.
    public var representation: ExcerptRepresentation

    public init(topK: Int = 4, neighbors: Int = 0, maxPages: Int? = nil, fullIfCoverage: Double = 0.75,
                minConfidence: Double = 0, fallbackOnNotCovered: Bool = true, representation: ExcerptRepresentation = .pdf) {
        self.topK = topK
        self.neighbors = neighbors
        self.maxPages = maxPages
        self.fullIfCoverage = fullIfCoverage
        self.minConfidence = minConfidence
        self.fallbackOnNotCovered = fallbackOnNotCovered
        self.representation = representation
    }
}

public enum ExcerptRepresentation: String, Sendable, Codable, CaseIterable {
    /// A sub-PDF of the selected pages (text + page images, so diagrams survive).
    case pdf
    /// Only the extracted text of the selected pages (smallest; loses diagrams).
    case text
}

/// Which pages a request sends. Default everywhere: the full document (M1 behaviour).
public enum PageSelectionMode: Sendable, Equatable {
    case fullDocument
    /// Rank pages locally and send the best ones.
    case automatic(PageSelectionOptions)
    /// Send exactly these original pages (1-based).
    case pages([Int], representation: ExcerptRepresentation = .pdf)
}

/// The pages chosen for one request, plus the map between excerpt positions and original pages.
public struct PageSelection: Sendable, Equatable, Codable {
    /// Original 1-based page numbers, ascending. Equal to 1...pageCount when `isFullDocument`.
    public var pages: [Int]
    public var pageCount: Int
    /// Pages ranked by score (best first, original numbers), score > 0 only.
    public var ranked: [Int]
    /// Pages added because the conversation already cited them.
    public var pinned: [Int]
    /// 0–1: how peaked the scores are (top score vs. the median). Flat scores → low.
    public var confidence: Double
    public var isFullDocument: Bool
    /// Why the full document was chosen, if it was.
    public var reason: String?

    public init(pages: [Int], pageCount: Int, ranked: [Int] = [], pinned: [Int] = [], confidence: Double = 1,
                isFullDocument: Bool = false, reason: String? = nil) {
        self.pages = pages
        self.pageCount = pageCount
        self.ranked = ranked
        self.pinned = pinned
        self.confidence = confidence
        self.isFullDocument = isFullDocument
        self.reason = reason
    }

    public static func full(pageCount: Int, reason: String? = nil) -> PageSelection {
        PageSelection(pages: Array(1...max(pageCount, 1)), pageCount: pageCount, isFullDocument: true, reason: reason)
    }

    /// Original page for a 1-based position in the excerpt.
    public func originalPage(excerptPage p: Int) -> Int? {
        p >= 1 && p <= pages.count ? pages[p - 1] : nil
    }

    /// Page number the model wrote → original page. The prompt asks for original numbers; if the
    /// model wrote one that is not in the excerpt but is a valid excerpt position, it counted excerpt
    /// pages, so map it.
    public func resolveModelPage(_ p: Int) -> Int {
        if isFullDocument || pages.contains(p) { return p }
        return originalPage(excerptPage: p) ?? p
    }

    public func remap(_ e: Evidence) -> Evidence {
        var e = e
        e.page = resolveModelPage(e.page)
        return e
    }

    public func remap(_ s: Step) -> Step {
        s.mapEvidence(remap)
    }

    public func remap(_ a: Answer) -> Answer {
        var a = a
        a.steps = a.steps.map(remap)
        a.branches = a.branches.map { var b = $0; b.steps = b.steps.map(remap); return b }
        return a
    }

    /// Prompt note telling the model which original page each excerpt page is.
    func excerptNote(title: String, fullDocumentFollows: Bool = true) -> String {
        let list = pages.enumerated().map { "excerpt page \($0.offset + 1) = rulebook page \($0.element)" }.joined(separator: ", ")
        return """
        The attached document is an EXCERPT of the rulebook "\(title)" (\(pageCount) pages in full): only the \
        pages most relevant to the question were sent. It contains rulebook pages \(pages.map(String.init).joined(separator: ", ")) \
        (\(list)). In evidence, cite the RULEBOOK page number (the physical page index in the full rulebook file, \
        i.e. one of \(pages.map(String.init).joined(separator: ", "))), never the position inside the excerpt. \
        Use "inferred" only when the ruling follows from rules that ARE on these pages. If a rule you need is not \
        on these pages (for example the general rule for the action asked about), set confidence to "not_covered" \
        instead of guessing\(fullDocumentFollows ? ": the full rulebook will then be checked" : "").
        """
    }
}

public extension PageIndex {
    /// Pick pages for a question. `pinned` = pages the conversation already cited (always sent).
    func select(question: String, history: [String] = [], pinned: [Int] = [], options o: PageSelectionOptions) -> PageSelection {
        guard pageCount > 0 else { return .full(pageCount: 0, reason: "empty document") }
        let s = scores(question: question, history: history)
        let ranked = s.indices.filter { s[$0] > 0 }.sorted { s[$0] > s[$1] || (s[$0] == s[$1] && $0 < $1) }.map { $0 + 1 }
        let sorted = s.sorted()
        let top = sorted.last ?? 0
        let median = sorted[sorted.count / 2]
        let confidence = top > 0 ? (top - median) / top : 0
        let pins = pinned.filter { $0 >= 1 && $0 <= pageCount }

        guard !ranked.isEmpty else { return .full(pageCount: pageCount, reason: "no keyword hits") }
        if confidence < o.minConfidence {
            var f = PageSelection.full(pageCount: pageCount, reason: String(format: "low retrieval confidence %.2f", confidence))
            f.ranked = ranked; f.confidence = confidence
            return f
        }
        var chosen: [Int] = []
        func add(_ p: Int) {
            guard p >= 1, p <= pageCount, !chosen.contains(p) else { return }
            if let cap = o.maxPages, chosen.count >= cap + pins.count { return }
            chosen.append(p)
        }
        pins.forEach(add)
        let tops = Array(ranked.prefix(max(1, o.topK)))
        tops.forEach(add)
        for p in tops {
            for d in 1...max(1, o.neighbors) where o.neighbors > 0 {
                add(p + d)   // rules more often continue on the next page
                add(p - d)
            }
        }
        let pages = chosen.sorted()
        if Double(pages.count) >= o.fullIfCoverage * Double(pageCount) {
            var f = PageSelection.full(pageCount: pageCount, reason: "selection covers \(pages.count)/\(pageCount) pages")
            f.ranked = ranked; f.confidence = confidence; f.pinned = pins
            return f
        }
        return PageSelection(pages: pages, pageCount: pageCount, ranked: ranked, pinned: pins, confidence: confidence)
    }
}
