import Foundation

/// The "Add N Rulebooks" review (S14): picked files, already copied into the library but not in the index yet,
/// grouped into games. Files start under "Sorting…"; a suggestion (`RulebookSorter`) or its absence moves them
/// into groups; the user then moves, renames, re-roles or skips them. Nothing reaches the library until
/// `LibraryIndex.add(_:)`. Pure value type: the app's sheet renders it.
public struct ImportBatch: Sendable, Equatable {
    public struct Book: Sendable, Equatable, Identifiable {
        public var fileName: String
        public var title: String
        public var role: BookRole
        /// Why the suggestion put it here (or flagged it as not a rulebook).
        public var reason: String?
        public var id: String { fileName }

        public init(fileName: String, title: String, role: BookRole = .core, reason: String? = nil) {
            self.fileName = fileName
            self.title = title
            self.role = role
            self.reason = reason
        }
    }

    public enum Target: Sendable, Equatable, Hashable {
        /// A game in My Games (its id).
        case existing(String)
        case new
    }

    public struct Group: Sendable, Equatable, Identifiable {
        public var id: String
        public var target: Target
        /// The game's name (editable for a new game; an existing game's current name).
        public var name: String
        public var books: [Book]

        public var isNew: Bool { target == .new }
    }

    /// How the groups came about, for the note under the sheet.
    public enum Origin: Sendable, Equatable {
        /// Waiting for the suggestion.
        case sorting
        case suggested
        /// No suggestion (no server route, offline, an error): one game per file, the user sorts.
        case unsorted
    }

    public private(set) var sorting: [Book]
    public private(set) var groups: [Group] = []
    /// Not added (flagged as not a rulebook, or skipped by hand). Their copies are removed on Add.
    public private(set) var skipped: [Book] = []
    public private(set) var origin: Origin = .sorting
    /// Started from this game's "Playing with" list: unsorted files go there, as add-ons.
    public let preferredGameID: String?
    private var nextGroup = 1

    /// `files`: (copied file name, title from the PDF title or the file name).
    public init(files: [(fileName: String, title: String)], preferredGameID: String? = nil) {
        sorting = files.map { Book(fileName: $0.fileName, title: $0.title) }
        self.preferredGameID = preferredGameID
    }

    public var isSorting: Bool { !sorting.isEmpty }
    /// Every copied file, in any state.
    public var fileNames: [String] { (sorting + groups.flatMap(\.books) + skipped).map(\.fileName) }
    /// Books that Add would add.
    public var bookCount: Int { groups.reduce(0) { $0 + $1.books.count } }
    public var newGameCount: Int { groups.filter(\.isNew).count }

    public func group(_ id: String) -> Group? { groups.first { $0.id == id } }
    public func group(containing fileName: String) -> Group? { groups.first { $0.books.contains { $0.fileName == fileName } } }

    // MARK: Suggestions

    /// Places every file still sorting: by its suggestion when there is one; otherwise as if unsorted.
    /// New games with the same name (ignoring case) share a group; existing games get one group each.
    public mutating func apply(_ suggestions: [RulebookSorter.Suggestion], games: [LibraryEntry]) {
        let byFile = Dictionary(suggestions.map { ($0.fileName, $0) }, uniquingKeysWith: { a, _ in a })
        let pending = sorting
        sorting = []
        var placed = false
        for var book in pending {
            guard let s = byFile[book.fileName] else { placeUnsorted(book, games: games); continue }
            placed = true
            book.title = s.title
            book.role = s.role
            book.reason = s.reason.isEmpty ? nil : s.reason
            if s.notARulebook { skipped.append(book); continue }
            switch s.target {
            case .existing(let id):
                guard let game = games.first(where: { $0.id == id }) else { placeUnsorted(book, games: games); continue }
                append(book, toExisting: game)
            case .new(let name):
                if let i = groups.firstIndex(where: { $0.isNew && $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    groups[i].books.append(book)
                } else {
                    newGroup(name: name, books: [book])
                }
            }
        }
        origin = placed ? .suggested : .unsorted
        fixCore()
    }

    /// No suggestion: each file is its own new game, core (or, from a game's "Playing with", that game's
    /// add-on).
    public mutating func leaveUnsorted(games: [LibraryEntry]) {
        let pending = sorting
        sorting = []
        for b in pending { placeUnsorted(b, games: games) }
        origin = .unsorted
    }

    private mutating func placeUnsorted(_ book: Book, games: [LibraryEntry]) {
        var book = book
        book.reason = nil
        if let id = preferredGameID, let game = games.first(where: { $0.id == id }) {
            book.role = .addOn
            append(book, toExisting: game)
        } else {
            book.role = .core
            newGroup(name: book.title, books: [book])
        }
    }

    private mutating func append(_ book: Book, toExisting game: LibraryEntry) {
        if let i = groups.firstIndex(where: { $0.target == .existing(game.id) }) {
            groups[i].books.append(book)
        } else {
            groups.append(Group(id: "game:\(game.id)", target: .existing(game.id), name: game.title, books: [book]))
        }
    }

    @discardableResult
    private mutating func newGroup(name: String, books: [Book]) -> String {
        let id = "new:\(nextGroup)"
        nextGroup += 1
        groups.append(Group(id: id, target: .new, name: name, books: books))
        return id
    }

    // MARK: Editing

    /// Drag or Move to… another group (at the end, or before `before`).
    public mutating func move(_ fileName: String, toGroup id: String, before: String? = nil) {
        guard group(id) != nil, let book = take(fileName), let g = groups.firstIndex(where: { $0.id == id }) else { return }
        if let before, let i = groups[g].books.firstIndex(where: { $0.fileName == before }) {
            groups[g].books.insert(book, at: i)
        } else {
            groups[g].books.append(book)
        }
        cleanUp()
    }

    /// Move to… a game in My Games that has no group in this batch yet (or has one: same as `move`).
    public mutating func move(_ fileName: String, toGame game: LibraryEntry) {
        if let g = groups.first(where: { $0.target == .existing(game.id) }) { return move(fileName, toGroup: g.id) }
        guard var book = take(fileName) else { return }
        book.role = .addOn
        append(book, toExisting: game)
        cleanUp()
    }

    /// Move to… → New Game: the book on its own, as core, named after it. Returns the new group's id.
    @discardableResult
    public mutating func moveToNewGame(_ fileName: String) -> String? {
        guard var book = take(fileName) else { return nil }
        book.role = .core
        let id = newGroup(name: book.title, books: [book])
        cleanUp()
        return id
    }

    public mutating func skip(_ fileName: String) {
        guard let book = take(fileName) else { return }
        skipped.append(book)
        cleanUp()
    }

    /// A new game keeps at least one core book: its last one can't become an add-on.
    public mutating func setRole(_ fileName: String, _ role: BookRole) {
        guard !(role == .addOn && isLastCore(fileName)) else { return }
        update(fileName) { $0.role = role }
    }

    /// The only core book of a new game (its Add-on choice is off).
    public func isLastCore(_ fileName: String) -> Bool {
        guard let g = group(containing: fileName), g.isNew else { return false }
        let cores = g.books.filter { $0.role == .core }
        return cores.count == 1 && cores[0].fileName == fileName
    }

    public mutating func renameBook(_ fileName: String, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        update(fileName) { $0.title = t }
    }

    /// Only new games are renamed here (an existing game is renamed in "Playing with").
    public mutating func renameGroup(_ id: String, to name: String) {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = groups.firstIndex(where: { $0.id == id }), groups[i].isNew else { return }
        groups[i].name = t
    }

    private mutating func update(_ fileName: String, _ change: (inout Book) -> Void) {
        for g in groups.indices {
            if let b = groups[g].books.firstIndex(where: { $0.fileName == fileName }) { change(&groups[g].books[b]); return }
        }
        if let b = skipped.firstIndex(where: { $0.fileName == fileName }) { change(&skipped[b]) }
    }

    /// Takes a book out of wherever it is (not while sorting).
    private mutating func take(_ fileName: String) -> Book? {
        for g in groups.indices {
            if let b = groups[g].books.firstIndex(where: { $0.fileName == fileName }) { return groups[g].books.remove(at: b) }
        }
        if let b = skipped.firstIndex(where: { $0.fileName == fileName }) { return skipped.remove(at: b) }
        return nil
    }

    private mutating func cleanUp() {
        groups.removeAll { $0.books.isEmpty }
        fixCore()
    }

    /// A new game needs a core book: its first book becomes one if none is.
    private mutating func fixCore() {
        for g in groups.indices where groups[g].isNew && !groups[g].books.contains(where: { $0.role == .core }) {
            if !groups[g].books.isEmpty { groups[g].books[0].role = .core }
        }
    }
}
