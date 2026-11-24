import Foundation
import AckshuallyCore

struct QuestionSet: Codable {
    var description: String?
    var games: [GameQuestions]
}

struct GameQuestions: Codable {
    var id: String
    var name: String
    /// Repo-relative (or absolute) path to the PDF (a game with one rulebook).
    var pdf: String?
    /// If `pdf` is missing, pick the first PDF in its folder whose lowercased name contains all of these.
    var pdfMatch: [String]?
    /// A game with several rulebooks (S13), in document order: core books are always sent, add-ons only
    /// when a question ticks them (`add_ons`). Used instead of `pdf`.
    var books: [BookSpec]?
    var questions: [Question]

    enum CodingKeys: String, CodingKey {
        case id, name, pdf, questions, books
        case pdfMatch = "pdf_match"
    }

    /// Every book as a spec (a one-PDF game is one core book).
    var bookSpecs: [BookSpec] {
        books ?? [BookSpec(id: id, title: name, role: .core, pdf: pdf ?? "", pdfMatch: pdfMatch)]
    }
}

/// One rulebook of a several-book game.
struct BookSpec: Codable {
    /// Short id used by `add_ons` and `expected_book_pages` ("riverfolk").
    var id: String
    /// Title as the app shows it and the prompt names it ("Riverfolk").
    var title: String
    var role: BookRole
    var pdf: String
    var pdfMatch: [String]?

    enum CodingKeys: String, CodingKey {
        case id, title, role, pdf
        case pdfMatch = "pdf_match"
    }
}

/// A page of one book (1-based, physical page of that book's PDF).
struct BookPageSpec: Codable {
    var book: String
    var page: Int
}

struct Question: Codable {
    var id: String
    var question: String
    var expectedVerdict: String
    /// "stated" | "inferred" | "not_covered" (expected rulebook confidence), optional.
    var expectedConfidence: String?
    var tags: [String]?
    /// URL for forum-sourced questions, or "own".
    var source: String
    /// Physical PDF pages (1-based) that hold the evidence. Empty/missing = TODO.
    var expectedPages: [Int]?
    /// A passage that should be cited (TODO when missing).
    var expectedQuote: String?
    /// For figure questions: expected region (normalized, top-left origin) on `expectedPages[0]`.
    var expectedBox: NormalizedBox?
    /// Id of the previous question in a follow-up chain (same session, conversation context).
    var follows: String?
    var notes: String?
    /// Several-book games: ids of the add-ons ticked for this question (nil/empty = none; core books are always sent).
    var addOns: [String]?
    /// Several-book games: expected evidence as book + page (mapped to pages of the sent document).
    var expectedBookPages: [BookPageSpec]?

    enum CodingKeys: String, CodingKey {
        case id, question, tags, source, follows, notes
        case addOns = "add_ons"
        case expectedBookPages = "expected_book_pages"
        case expectedVerdict = "expected_verdict"
        case expectedConfidence = "expected_confidence"
        case expectedPages = "expected_pages"
        case expectedQuote = "expected_quote"
        case expectedBox = "expected_box"
    }
}

enum Paths {
    /// Walk up from `start` to the directory containing `.git` (repo root).
    static func repoRoot(from start: URL) -> URL? {
        var dir = start.hasDirectoryPath ? start : start.deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    static func resolve(_ path: String, questionsFile: URL) -> URL {
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [repoRoot(from: questionsFile), repoRoot(from: cwd), questionsFile.deletingLastPathComponent(), cwd]
            .compactMap { $0 }.map { $0.appendingPathComponent(path).standardizedFileURL }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidates[0]
    }

    static func findPDF(for g: GameQuestions, questionsFile: URL) -> URL? {
        findPDF(g.pdf ?? "", match: g.pdfMatch, questionsFile: questionsFile)
    }

    static func findPDF(for b: BookSpec, questionsFile: URL) -> URL? {
        findPDF(b.pdf, match: b.pdfMatch, questionsFile: questionsFile)
    }

    static func findPDF(_ path: String, match: [String]?, questionsFile: URL) -> URL? {
        let direct = resolve(path, questionsFile: questionsFile)
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        guard let keys = match, !keys.isEmpty else { return nil }
        let dir = direct.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let hit = files.sorted().first { f in
            let l = f.lowercased()
            return l.hasSuffix(".pdf") && keys.allSatisfy { l.contains($0.lowercased()) }
        }
        return hit.map { dir.appendingPathComponent($0) }
    }
}
