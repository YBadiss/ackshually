import Foundation

/// Turns streamed JSON text (SPEC §3) into progressive `AnswerEvent`s.
public struct JSONAnswerAssembler: Sendable {
    private var scanner = IncrementalJSONScanner()
    private var final: Answer?
    private var decodeError: String?

    public init() {}

    public var text: String { scanner.text }

    public mutating func feed(_ chunk: String) -> [AnswerEvent] {
        var events: [AnswerEvent] = []
        for c in scanner.feed(chunk) {
            let d = Data(c.rawJSON.utf8)
            let dec = JSONDecoder()
            switch c.path {
            case [.key("restated_question")]:
                if let s = try? dec.decode(String.self, from: d) { events.append(.restatedQuestion(s)) }
            case [.key("verdict")]:
                if let s = try? dec.decode(String.self, from: d) { events.append(.verdict(s)) }
            case [.key("confidence")]:
                if let s = try? dec.decode(Confidence.self, from: d) { events.append(.confidence(s)) }
            case let p where p.count == 2 && p[0] == .key("branches"):
                if var b = try? dec.decode(Branch.self, from: d) {
                    b.steps = b.steps.map { $0.mapEvidence { $0.normalized() } }
                    events.append(.branch(b))
                }
            case let p where p.count == 4 && p[0] == .key("steps") && p[2] == .key("evidence"):
                if case .index(let si) = p[1], case .index(let ei) = p[3],
                   let e = try? dec.decode(Evidence.self, from: d) {
                    events.append(.evidence(step: si, index: ei, e.normalized()))
                }
            case let p where p.count == 2 && p[0] == .key("steps"):
                if case .index(let si) = p[1], var s = try? dec.decode(Step.self, from: d) {
                    s.evidence = s.evidence.map { $0.normalized() }
                    events.append(.step(index: si, s))
                }
            case []:
                do {
                    var a = try dec.decode(Answer.self, from: d)
                    a.steps = a.steps.map { $0.mapEvidence { $0.normalized() } }
                    a.branches = a.branches.map { var b = $0; b.steps = b.steps.map { $0.mapEvidence { $0.normalized() } }; return b }
                    final = a
                } catch {
                    decodeError = "decode: \(error)"
                }
            default:
                break
            }
        }
        return events
    }

    /// Final answer, or an error description (truncated / invalid JSON).
    public func finish() -> Result<Answer, AssemblyError> {
        if let final { return .success(final) }
        if let decodeError { return .failure(.init(message: decodeError)) }
        return .failure(.init(message: scanner.finished ? "no answer object" : "incomplete JSON (\(scanner.text.count) chars)"))
    }
}

public struct AssemblyError: Error, Sendable, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}

extension Evidence {
    func normalized() -> Evidence {
        var e = self
        if let q = e.quote, q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { e.quote = nil }
        return e
    }
}

/// A page-located citation as returned by Claude's citations feature for PDFs.
public struct PageCitation: Codable, Sendable, Equatable {
    public var citedText: String
    public var startPageNumber: Int
    public var endPageNumber: Int  // exclusive

    enum CodingKeys: String, CodingKey {
        case citedText = "cited_text"
        case startPageNumber = "start_page_number"
        case endPageNumber = "end_page_number"
    }

    public init(citedText: String, startPageNumber: Int, endPageNumber: Int) {
        self.citedText = citedText
        self.startPageNumber = startPageNumber
        self.endPageNumber = endPageNumber
    }
}

/// Assembles the SPEC §3 contract from a line-based answer + native citations.
public struct CitationsAnswerAssembler: Sendable {
    private var lines: [String] = [""]
    private var lineCitations: [Int: [PageCitation]] = [:]
    /// Per content block: last line index that received non-newline text in that block.
    private var blockLine: [Int: Int] = [:]

    private var restated: String?
    private var verdict: String?
    private var confidence: Confidence?
    private var branches: [Branch] = []
    private var assumptions: [String] = []
    private var steps: [Step] = []
    private var needsWeb: Bool?

    public init() {}

    public var text: String { lines.joined(separator: "\n") }

    public mutating func feedText(block: Int, _ chunk: String) -> [AnswerEvent] {
        var events: [AnswerEvent] = []
        for ch in chunk {
            if ch == "\n" {
                events += completeLine(lines.count - 1)
                lines.append("")
            } else {
                lines[lines.count - 1].append(ch)
                blockLine[block] = lines.count - 1
            }
        }
        return events
    }

    public mutating func feedCitation(block: Int, _ c: PageCitation) {
        let line = blockLine[block] ?? (lines.count - 1)
        lineCitations[line, default: []].append(c)
    }

    public mutating func finish() -> (events: [AnswerEvent], result: Result<Answer, AssemblyError>) {
        let events = completeLine(lines.count - 1)
        guard let restated, let verdict, let confidence else {
            return (events, .failure(.init(message: "missing QUESTION/VERDICT/CONFIDENCE line")))
        }
        let a = Answer(restatedQuestion: restated, verdict: verdict, confidence: confidence,
                       branches: branches, assumptions: assumptions, steps: steps,
                       needsWeb: needsWeb ?? (confidence != .stated))
        return (events, .success(a))
    }

    private var completed: Set<Int> = []

    private mutating func completeLine(_ i: Int) -> [AnswerEvent] {
        guard !completed.contains(i) else { return [] }
        let raw = lines[i].trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return [] }
        completed.insert(i)
        func value(_ prefix: String) -> String? {
            let stripped = raw.replacingOccurrences(of: "**", with: "")
            guard stripped.uppercased().hasPrefix(prefix + ":") else { return nil }
            return String(stripped.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespaces)
        }
        if let v = value("QUESTION") { restated = v; return [.restatedQuestion(v)] }
        if let v = value("VERDICT") { verdict = v; return [.verdict(v)] }
        if let v = value("CONFIDENCE") {
            let c = Confidence(rawValue: v.lowercased().replacingOccurrences(of: " ", with: "_")) ?? .inferred
            confidence = c
            return [.confidence(c)]
        }
        if let v = value("BRANCH") {
            let parts = v.components(separatedBy: "=>")
            let b = Branch(condition: parts[0].trimmingCharacters(in: .whitespaces),
                           verdict: parts.dropFirst().joined(separator: "=>").trimmingCharacters(in: .whitespaces))
            branches.append(b)
            return [.branch(b)]
        }
        if let v = value("ASSUMPTION") { assumptions.append(v); return [] }
        if let v = value("NEEDS_WEB") { needsWeb = v.lowercased().hasPrefix("y") || v.lowercased() == "true"; return [] }
        if let v = value("STEP") {
            let ev = (lineCitations[i] ?? []).map {
                Evidence(page: $0.startPageNumber, quote: $0.citedText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let s = Step(text: v, evidence: ev)
            let idx = steps.count
            steps.append(s)
            return ev.enumerated().map { AnswerEvent.evidence(step: idx, index: $0.offset, $0.element) } + [.step(index: idx, s)]
        }
        return []
    }
}
