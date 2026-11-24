import Foundation

/// One rulebook PDF of a game (S13). `fileName` is relative to the app's rulebook folder (container paths
/// change between installs) and is the book's identity: a file belongs to one game.
public struct LibraryBook: Codable, Hashable, Sendable, Identifiable {
    public var fileName: String
    public var title: String
    public var role: BookRole
    /// Add-ons: ticked the last time the game was played, so the "Playing with" list starts from there.
    /// Ignored for core books, which are always in play.
    public var ticked: Bool

    public var id: String { fileName }
    public var inPlay: Bool { role == .core || ticked }

    public init(fileName: String, title: String, role: BookRole = .core, ticked: Bool = true) {
        self.fileName = fileName
        self.title = title
        self.role = role
        self.ticked = ticked
    }
}

/// One game in My Games (S1): its rulebooks in the user's order, each core or an add-on. `id` never changes
/// (games from before several books existed keep their file name as their id, so routes and covers carry over).
public struct LibraryEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var added: Date
    public var lastOpened: Date
    public var books: [LibraryBook]

    public init(id: String, title: String, added: Date, lastOpened: Date, books: [LibraryBook]) {
        self.id = id
        self.title = title
        self.added = added
        self.lastOpened = lastOpened
        self.books = books
    }

    /// A game with one core book (the file name is its id).
    public init(fileName: String, title: String, added: Date, lastOpened: Date) {
        self.init(id: fileName, title: title, added: added, lastOpened: lastOpened,
                  books: [LibraryBook(fileName: fileName, title: title)])
    }

    /// The cover is the first core book's first page.
    public var coverBook: LibraryBook? { books.first { $0.role == .core } ?? books.first }
    public var addOns: [LibraryBook] { books.filter { $0.role == .addOn } }
    /// Only games with add-ons ask what you play with (S13).
    public var hasAddOns: Bool { books.contains { $0.role == .addOn } }
    /// Core books and ticked add-ons, in the user's order: what answers use.
    public var booksInPlay: [LibraryBook] { books.filter(\.inPlay) }
    public var notInPlay: [LibraryBook] { books.filter { !$0.inPlay } }
    public var coreCount: Int { books.filter { $0.role == .core }.count }

    public func book(_ fileName: String) -> LibraryBook? { books.first { $0.fileName == fileName } }

    /// The game's only book: removing it means deleting the game.
    public func isOnlyBook(_ fileName: String) -> Bool { books.count == 1 && books[0].fileName == fileName }

    /// A game keeps at least one core book: its last one can't be removed or become an add-on.
    public func isLastCore(_ fileName: String) -> Bool {
        book(fileName)?.role == .core && coreCount == 1
    }

    // Index files from before several books (version 1) have `fileName` and no `books`.
    enum CodingKeys: String, CodingKey { case id, title, added, lastOpened, books, fileName }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        added = try c.decode(Date.self, forKey: .added)
        lastOpened = try c.decode(Date.self, forKey: .lastOpened)
        if let books = try c.decodeIfPresent([LibraryBook].self, forKey: .books) {
            self.books = books
            id = try c.decodeIfPresent(String.self, forKey: .id) ?? books.first?.fileName ?? UUID().uuidString
        } else {
            let file = try c.decode(String.self, forKey: .fileName)
            id = try c.decodeIfPresent(String.self, forKey: .id) ?? file
            books = [LibraryBook(fileName: file, title: title)]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(added, forKey: .added)
        try c.encode(lastOpened, forKey: .lastOpened)
        try c.encode(books, forKey: .books)
    }
}

/// The list behind My Games: a small JSON file, newest-used first. Pure value type; the app
/// decides where the file lives and which files the books point to.
public struct LibraryIndex: Codable, Equatable, Sendable {
    /// 2: games hold several books (S13). Version 1 files load as games with one core book.
    public static let currentVersion = 2

    public var version: Int
    /// Always sorted by `lastOpened`, most recent first.
    public private(set) var entries: [LibraryEntry]

    public init(entries: [LibraryEntry] = []) {
        version = Self.currentVersion
        self.entries = entries
        sort()
    }

    public var isEmpty: Bool { entries.isEmpty }

    public func entry(id: String) -> LibraryEntry? {
        entries.first { $0.id == id }
    }

    /// The game a rulebook file belongs to.
    public func game(containing fileName: String) -> LibraryEntry? {
        entries.first { $0.book(fileName) != nil }
    }

    /// Every rulebook file in the library.
    public var fileNames: [String] { entries.flatMap { $0.books.map(\.fileName) } }

    // MARK: Games

    /// Adds a game with one core book (id = the file name), or (re-import of the same file as a new game)
    /// updates its title and marks it opened now.
    public mutating func record(fileName: String, title: String, at date: Date = .now) {
        if let i = entries.firstIndex(where: { $0.id == fileName }) {
            entries[i].title = title
            if let b = entries[i].books.firstIndex(where: { $0.fileName == fileName }) { entries[i].books[b].title = title }
            entries[i].lastOpened = date
        } else {
            removeBookEverywhere(fileName)
            entries.append(LibraryEntry(fileName: fileName, title: title, added: date, lastOpened: date))
        }
        sort()
    }

    /// Opening a game moves it to the top. Unknown ids are ignored.
    public mutating func markOpened(_ id: String, at date: Date = .now) {
        guard let i = index(of: id) else { return }
        entries[i].lastOpened = date
        sort()
    }

    public mutating func renameGame(_ id: String, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = index(of: id), !t.isEmpty else { return }
        entries[i].title = t
        sort()
    }

    @discardableResult
    public mutating func remove(_ id: String) -> LibraryEntry? {
        guard let i = index(of: id) else { return nil }
        return entries.remove(at: i)
    }

    /// Edit → Delete: several games at once. Returns the games removed (their files are the caller's to delete).
    @discardableResult
    public mutating func remove(_ ids: some Sequence<String>) -> [LibraryEntry] {
        ids.compactMap { remove($0) }
    }

    /// Settings → Developer → Remove All Games. Returns every game that was there.
    @discardableResult
    public mutating func removeAll() -> [LibraryEntry] {
        defer { entries = [] }
        return entries
    }

    /// Add on the "Add N Rulebooks" sheet (S14): books for existing games go after their others (ticked), each
    /// new group becomes a game (its id is its first core book's file name). Skipped files are not added.
    /// Returns the ids of the new games, in the batch's order.
    @discardableResult
    public mutating func add(_ batch: ImportBatch, at date: Date = .now) -> [String] {
        var created: [String] = []
        for g in batch.groups where !g.books.isEmpty {
            let books = g.books.map { LibraryBook(fileName: $0.fileName, title: $0.title, role: $0.role, ticked: true) }
            switch g.target {
            case .existing(let id):
                guard index(of: id) != nil else { fallthrough }
                for b in books { addBook(b, to: id) }
            case .new:
                var books = books
                if !books.contains(where: { $0.role == .core }) { books[0].role = .core }
                for b in books { removeBookEverywhere(b.fileName) }
                let id = books.first { $0.role == .core }?.fileName ?? books[0].fileName
                entries.removeAll { $0.id == id }
                entries.append(LibraryEntry(id: id, title: g.name, added: date, lastOpened: date, books: books))
                created.append(id)
            }
        }
        sort()
        return created
    }

    // MARK: Books

    /// Adds a book to a game, after its others ("Add to <game>"). A file already in another game moves here.
    public mutating func addBook(_ book: LibraryBook, to id: String) {
        guard index(of: id) != nil else { return }
        removeBookEverywhere(book.fileName, except: id)
        guard let i = index(of: id) else { return }
        if let b = entries[i].books.firstIndex(where: { $0.fileName == book.fileName }) {
            entries[i].books[b] = book
        } else {
            entries[i].books.append(book)
        }
    }

    /// Removes a book from its game (not the game's last core book). Returns whether it was removed.
    @discardableResult
    public mutating func removeBook(_ fileName: String, from id: String) -> Bool {
        guard let i = index(of: id), !entries[i].isLastCore(fileName) else { return false }
        let before = entries[i].books.count
        entries[i].books.removeAll { $0.fileName == fileName }
        return entries[i].books.count < before
    }

    public mutating func renameBook(_ fileName: String, in id: String, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        update(fileName, in: id) { $0.title = t }
    }

    /// Make Core / Make Add-on. The last core book stays core. A book made an add-on stays in play (ticked).
    public mutating func setRole(_ fileName: String, in id: String, to role: BookRole) {
        guard let e = entry(id: id), !(role == .addOn && e.isLastCore(fileName)) else { return }
        update(fileName, in: id) { b in
            if b.role != role { b.ticked = true }
            b.role = role
        }
    }

    /// Ticks or unticks an add-on for tonight (remembered for next time). Core books can't be unticked.
    public mutating func setTicked(_ fileName: String, in id: String, _ ticked: Bool) {
        update(fileName, in: id) { b in
            guard b.role == .addOn else { return }
            b.ticked = ticked
        }
    }

    /// Drops books whose file is gone (deleted outside the app, e.g. in the Files app), then games with no
    /// books left. A game that lost its core books gets its first remaining book as core.
    public mutating func prune(keeping exists: (String) -> Bool) {
        for i in entries.indices {
            entries[i].books.removeAll { !exists($0.fileName) }
            if entries[i].coreCount == 0, !entries[i].books.isEmpty {
                entries[i].books[0].role = .core
            }
        }
        entries.removeAll { $0.books.isEmpty }
    }

    private func index(of id: String) -> Int? { entries.firstIndex { $0.id == id } }

    private mutating func update(_ fileName: String, in id: String, _ change: (inout LibraryBook) -> Void) {
        guard let i = index(of: id), let b = entries[i].books.firstIndex(where: { $0.fileName == fileName }) else { return }
        change(&entries[i].books[b])
    }

    /// A file belongs to one game: take it out of any other (dropping a game left with no books).
    private mutating func removeBookEverywhere(_ fileName: String, except id: String? = nil) {
        for i in entries.indices where entries[i].id != id {
            entries[i].books.removeAll { $0.fileName == fileName }
            if entries[i].coreCount == 0, !entries[i].books.isEmpty { entries[i].books[0].role = .core }
        }
        entries.removeAll { $0.books.isEmpty }
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
