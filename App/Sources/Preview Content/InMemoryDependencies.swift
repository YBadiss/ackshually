import UIKit
import Synchronization
import AckshuallyCore

// In-memory dependencies for previews and unit tests: nothing touches the Keychain, UserDefaults or the
// library folder.

extension AppDependencies {
    /// Previews' default (also the environment's): no credential, demo answers for the sample, an empty library.
    static let preview = AppDependencies.inMemory()

    static func inMemory(credentials: InMemoryCredentials = InMemoryCredentials(),
                         settings: InMemorySettings = InMemorySettings(),
                         library: InMemoryLibraryStorage = InMemoryLibraryStorage(),
                         providers: (any AnswerProviderFactory)? = nil) -> AppDependencies {
        AppDependencies(credentials: credentials, settings: settings, library: library,
                        providers: providers ?? LiveAnswerProviders(credentials: credentials, settings: settings))
    }
}

final class InMemoryCredentials: CredentialAccess {
    private let saved = Mutex<[CredentialItem: String]>([:])
    let bundledToken: String?
    let serverURL: URL

    init(bundledToken: String? = nil, serverURL: URL = URL(string: "https://ackshually.badyass.xyz")!) {
        self.bundledToken = bundledToken
        self.serverURL = serverURL
    }

    var route: AnswerRoute? {
        let s = saved.withLock { $0 }
        return AnswerRoute.resolve(bundledToken: bundledToken, tokenOverride: s[.tokenOverride], apiKey: s[.apiKey], serverURL: serverURL)
    }

    var status: RouteStatus {
        let s = saved.withLock { $0 }
        let active: ActiveCredential = bundledToken != nil ? .bundledToken
            : s[.tokenOverride] != nil ? .tokenOverride : s[.apiKey] != nil ? .apiKey(fromEnvironment: false) : .none
        return RouteStatus(active: active, serverHost: serverURL.host() ?? "", tokenOverrideSaved: s[.tokenOverride] != nil,
                           apiKeySaved: s[.apiKey] != nil)
    }

    func save(_ value: String?, for item: CredentialItem) {
        let v = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.withLock { $0[item] = (v?.isEmpty ?? true) ? nil : v }
    }
}

final class InMemorySettings: AppSettings {
    private let demo: Mutex<Bool>
    let demoAnswer: Answer?
    let demoPace: Double

    init(demoAnswers: Bool = false, demoAnswer: Answer? = nil, demoPace: Double = 1) {
        demo = Mutex(demoAnswers)
        self.demoAnswer = demoAnswer
        self.demoPace = demoPace
    }

    var demoAnswers: Bool {
        get { demo.withLock { $0 } }
        set { demo.withLock { $0 = newValue } }
    }
}

/// A library in a throwaway folder; the index lives only in memory.
final class InMemoryLibraryStorage: LibraryStorage {
    private let index: Mutex<LibraryIndex>
    let folder: URL

    init(index: LibraryIndex = LibraryIndex(),
         folder: URL = FileManager.default.temporaryDirectory.appending(path: "preview-library", directoryHint: .isDirectory)) {
        self.index = Mutex(index)
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func loadIndex() -> LibraryIndex { index.withLock { $0 } }
    func save(_ i: LibraryIndex) { index.withLock { $0 = i } }
    func reset() -> LibraryIndex { index.withLock { $0 = LibraryIndex(); return $0 } }
    func url(for fileName: String) -> URL { folder.appending(path: fileName) }
    func title(of url: URL) -> String { LoadedRulebook.prettyTitle(from: url, pdfTitle: nil) }
    func delete(fileName: String) async { try? FileManager.default.removeItem(at: url(for: fileName)) }
    func cover(for url: URL, pixelWidth: Int) async -> UIImage? { nil }

    func importPDF(from picked: URL) throws -> URL {
        let dest = url(for: picked.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: picked, to: dest)
        return dest
    }

    func sampleRulebook() throws -> URL {
        let u = url(for: Library.sampleFileName)
        if !FileManager.default.fileExists(atPath: u.path) { try FixtureRulebook.write(to: u) }
        return u
    }
}
