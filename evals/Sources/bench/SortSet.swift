import Foundation
import AckshuallyCore

/// `bench sort`: runs `RulebookSorter` (S14) on a set of PDFs and scores its grouping against an expected one.
/// Two scenarios: an empty library, and the `existing` games already in My Games (their `replaces` file is left
/// out of the batch, and the other files of that game must go to it).
struct SortError: Error, CustomStringConvertible { var description: String }

enum SortSet {
    struct Spec: Decodable {
        struct File: Decodable {
            var pdf: String
            var game: String?
            var role: BookRole?
            var not_a_rulebook: Bool?
        }
        struct Existing: Decodable {
            var id: String
            var game: String
            var books: [String]
            var replaces: String?
        }
        var description: String?
        var files: [File]
        var existing: [Existing]?
    }

    /// One file's outcome in one scenario.
    struct Row: Codable {
        var scenario: String
        var file: String
        var expected: String
        var got: String
        var groupRight: Bool
        var roleRight: Bool
        var flagRight: Bool
        var title: String
        var reason: String
        var right: Bool { groupRight && roleRight && flagRight }
    }

    /// Two made-up non-rulebooks (nothing copied from a real game).
    static let generated: [String: [FixtureRulebook.Page]] = [
        "score-sheet": [FixtureRulebook.Page(title: "Score Sheet", paragraphs: [
            "Player name: ____________   Date: ________",
            "Round 1 ____  Round 2 ____  Round 3 ____  Round 4 ____  Round 5 ____  Round 6 ____",
            "End bonus: complete rows ____  complete columns ____  complete colours ____",
            "Floor line penalties ____   Final total ____",
        ])],
        "player-aid": [FixtureRulebook.Page(title: "Player Aid — Turn Summary", paragraphs: [
            "Morning: refresh your exhausted cards and collect income.",
            "Day: take up to three actions. Move, fight, build or recruit.",
            "Night: draw one card, then discard down to five.",
            "Icons: sword = fight, boot = move, hammer = build, flag = recruit.",
        ])],
    ]

    static func run(spec specURL: URL, resolve: (String) -> URL, credential: Credential, baseURL: URL, model: String,
                    outDir: URL) async throws -> [Row] {
        let spec = try JSONDecoder().decode(Spec.self, from: Data(contentsOf: specURL))
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        var urls: [String: URL] = [:]
        for f in spec.files {
            if f.pdf.hasPrefix("generated:") {
                let name = String(f.pdf.dropFirst("generated:".count))
                guard let pages = generated[name] else { throw SortError(description: "unknown generated file \(name)") }
                urls[f.pdf] = try FixtureRulebook.write(to: outDir.appending(path: "\(name).pdf"), pages: pages)
            } else {
                urls[f.pdf] = resolve(f.pdf)
            }
        }
        let sorter = RulebookSorter(credential: credential, baseURL: baseURL, model: model, timeout: 60)
        var rows: [Row] = []
        let scenarios: [(String, [Spec.Existing])] = [("empty", []), ("existing", spec.existing ?? [])]
        for (scenario, existing) in scenarios where scenario == "empty" || !existing.isEmpty {
            let replaced = Set(existing.compactMap(\.replaces))
            let batch = spec.files.filter { !replaced.contains($0.pdf) }
            var files: [RulebookSorter.File] = []
            for f in batch {
                guard let u = urls[f.pdf], let file = RulebookSorter.File(fileName: u.lastPathComponent, url: u) else {
                    throw SortError(description: "not a PDF: \(f.pdf) (symlink assets/rulebooks into the worktree)")
                }
                files.append(file)
            }
            let games = existing.map { RulebookSorter.Game(id: $0.id, title: $0.game, books: $0.books) }
            let started = Date()
            let suggestions = try await sorter.sort(files, games: games)
            log("\(scenario): \(suggestions.count)/\(files.count) suggestions in \(String(format: "%.1f", Date().timeIntervalSince(started))) s")
            rows += score(batch: batch, files: files, suggestions: suggestions, existing: existing, scenario: scenario)
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(rows).write(to: outDir.appending(path: "results.json"))
        return rows
    }

    /// A file's group is right when the files sharing its predicted group are exactly the files sharing its
    /// expected game (and, with existing games, it went to the existing game, not a new one of the same name).
    static func score(batch: [Spec.File], files: [RulebookSorter.File], suggestions: [RulebookSorter.Suggestion],
                      existing: [Spec.Existing], scenario: String) -> [Row] {
        let byFile = Dictionary(suggestions.map { ($0.fileName, $0) }, uniquingKeysWith: { a, _ in a })
        func expectedKey(_ f: Spec.File) -> String {
            if f.not_a_rulebook == true { return "skip" }
            if let e = existing.first(where: { $0.game == f.game }) { return "existing:\(e.id)" }
            return "new:\(f.game ?? "?")"
        }
        func gotKey(_ s: RulebookSorter.Suggestion?) -> String {
            guard let s else { return "missing" }
            if s.notARulebook { return "skip" }
            switch s.target {
            case .existing(let id): return "existing:\(id)"
            case .new(let name): return "new:\(name.lowercased())"
            }
        }
        let expected = batch.map(expectedKey)
        let got = files.map { gotKey(byFile[$0.fileName]) }
        return batch.indices.map { i in
            let f = batch[i]
            let s = byFile[files[i].fileName]
            let flagRight = (s?.notARulebook ?? false) == (f.not_a_rulebook ?? false)
            let groupRight: Bool
            if f.not_a_rulebook == true {
                groupRight = got[i] == "skip"
            } else {
                let sameExpected = Set(batch.indices.filter { expected[$0] == expected[i] })
                let sameGot = Set(batch.indices.filter { got[$0] == got[i] })
                let kindRight = expected[i].hasPrefix("existing:") ? got[i] == expected[i] : got[i].hasPrefix("new:")
                groupRight = kindRight && sameExpected == sameGot
            }
            let roleRight = f.role.map { $0 == s?.role } ?? true
            return Row(scenario: scenario, file: files[i].fileName,
                       expected: f.not_a_rulebook == true ? "not a rulebook" : "\(f.game ?? "?") · \(f.role?.rawValue ?? "?")",
                       got: s.map { $0.notARulebook ? "not a rulebook (\(Self.label($0.target)))" : "\(Self.label($0.target)) · \($0.role.rawValue)" } ?? "—",
                       groupRight: groupRight, roleRight: roleRight, flagRight: flagRight,
                       title: s?.title ?? "", reason: s?.reason ?? "")
        }
    }

    static func label(_ t: RulebookSorter.Suggestion.Target) -> String {
        switch t {
        case .existing(let id): "existing \(id)"
        case .new(let name): "new “\(name)”"
        }
    }

    static func report(_ rows: [Row], config: String) -> String {
        var s = "# Sorter bench (S14)\n\n\(config)\n\n"
        for scenario in Array(NSOrderedSet(array: rows.map(\.scenario))) as! [String] {
            let r = rows.filter { $0.scenario == scenario }
            s += "## Scenario: \(scenario)\n\n"
            s += "**\(r.filter(\.right).count)/\(r.count) files right** (group \(r.filter(\.groupRight).count), role \(r.filter(\.roleRight).count), not-a-rulebook flag \(r.filter(\.flagRight).count))\n\n"
            s += "| File | Expected | Suggested | Title | Reason | OK |\n|---|---|---|---|---|---|\n"
            for x in r {
                let ok = x.right ? "✅" : "❌ " + [x.groupRight ? nil : "group", x.roleRight ? nil : "role", x.flagRight ? nil : "flag"].compactMap { $0 }.joined(separator: ", ")
                s += "| \(x.file) | \(x.expected) | \(x.got) | \(x.title) | \(x.reason.replacingOccurrences(of: "|", with: "/")) | \(ok) |\n"
            }
            s += "\n"
        }
        return s
    }
}
