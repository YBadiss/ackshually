import Foundation

/// One imported rulebook in My Games (S1). `fileName` is relative to the app's rulebook folder
/// (container paths change between installs), and is the entry's identity.
public struct LibraryEntry: Codable, Hashable, Sendable, Identifiable {
    public var fileName: String
    public var title: String
    public var added: Date
    public var lastOpened: Date

    public var id: String { fileName }

    public init(fileName: String, title: String, added: Date, lastOpened: Date) {
        self.fileName = fileName
        self.title = title
        self.added = added
        self.lastOpened = lastOpened
    }
}

/// The list behind My Games: a small JSON file, newest-used first. Pure value type; the app
/// decides where the file lives and which files the entries point to.
public struct LibraryIndex: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    /// Always sorted by `lastOpened`, most recent first.
    public private(set) var entries: [LibraryEntry]

    public init(entries: [LibraryEntry] = []) {
        version = Self.currentVersion
        self.entries = entries
        sort()
    }

    public var isEmpty: Bool { entries.isEmpty }

    public func entry(named fileName: String) -> LibraryEntry? {
        entries.first { $0.fileName == fileName }
    }

    /// Adds a game, or (re-import of the same file) updates its title and marks it opened now.
    public mutating func record(fileName: String, title: String, at date: Date = .now) {
        if let i = entries.firstIndex(where: { $0.fileName == fileName }) {
            entries[i].title = title
            entries[i].lastOpened = date
        } else {
            entries.append(LibraryEntry(fileName: fileName, title: title, added: date, lastOpened: date))
        }
        sort()
    }

    /// Opening a game moves it to the top. Unknown names are ignored.
    public mutating func markOpened(_ fileName: String, at date: Date = .now) {
        guard let i = entries.firstIndex(where: { $0.fileName == fileName }) else { return }
        entries[i].lastOpened = date
        sort()
    }

    @discardableResult
    public mutating func remove(_ fileName: String) -> LibraryEntry? {
        guard let i = entries.firstIndex(where: { $0.fileName == fileName }) else { return nil }
        return entries.remove(at: i)
    }

    /// Drops entries whose file is gone (deleted outside the app, e.g. in the Files app).
    public mutating func prune(keeping exists: (String) -> Bool) {
        entries.removeAll { !exists($0.fileName) }
    }

    private mutating func sort() {
        // Ties (same instant) fall back to the name, so the order is stable across launches.
        entries.sort { ($0.lastOpened, $1.title) > ($1.lastOpened, $0.title) }
    }

    // MARK: File

    public func data() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    public init(data: Data) throws {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        let decoded = try d.decode(LibraryIndex.self, from: data)
        self.init(entries: decoded.entries)
    }

    /// Missing file → nil (first launch, or before migration). A corrupt file throws.
    public static func load(from url: URL) throws -> LibraryIndex? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try LibraryIndex(data: Data(contentsOf: url))
    }

    public func save(to url: URL) throws {
        try data().write(to: url, options: .atomic)
    }
}
