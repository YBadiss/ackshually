import Foundation
import Observation
import AckshuallyCore

/// Evidence → `Highlight`, resolved once per passage and cached for the session. Matching runs off the main
/// thread (Core's `QuoteMatcher` may scan the whole book) through `HighlightPlacer`; `onResolved` tells the
/// coordinator when a highlight lands, so the PDF can move to it if it is the one on screen.
@MainActor
@Observable
final class HighlightStore {
    typealias Placer = @Sendable (Evidence) -> Highlight

    private(set) var highlights: [String: Highlight] = [:]

    @ObservationIgnored var onResolved: (Evidence, Highlight) -> Void = { _, _ in }
    @ObservationIgnored private var resolving: Set<String> = []
    @ObservationIgnored private var place: Placer?
    /// Bumped by `reset`: a placement still running for the old document is dropped.
    @ObservationIgnored private var generation = 0

    /// Places evidence with Core's matcher on this rulebook (nil: nothing to match against).
    convenience init(matcher: QuoteMatcher?) {
        guard let matcher else { self.init(place: nil); return }
        self.init(place: Self.placer(matcher))
    }

    /// Unit tests: a counting or instant placer.
    init(place: Placer?) {
        self.place = place
    }

    subscript(_ e: Evidence) -> Highlight? { highlights[Self.key(e)] }

    /// Another document (the books in play changed): earlier placements are of the old pages.
    func reset(place: Placer?) {
        self.place = place
        highlights = [:]
        resolving = []
        generation += 1
    }

    /// Core's matcher on `matcher`'s document.
    static func placer(_ matcher: QuoteMatcher) -> Placer {
        { @Sendable e in HighlightPlacer.place(e, matcher: matcher) }
    }

    /// Starts placing `e` off the main thread unless it is placed or being placed.
    func resolve(_ e: Evidence) {
        let k = Self.key(e)
        guard highlights[k] == nil, !resolving.contains(k), let place else { return }
        resolving.insert(k)
        let gen = generation
        Task { [weak self] in
            let h = await Task.detached(priority: .userInitiated) { place(e) }.value
            guard let self, self.generation == gen else { return }
            self.resolving.remove(k)
            self.highlights[k] = h
            self.onResolved(e, h)
        }
    }

    /// Places `e` right away on this thread (previews, `-present` screenshots).
    @discardableResult
    func placeNow(_ e: Evidence) -> Highlight? {
        guard let place else { return nil }
        let h = place(e)
        highlights[Self.key(e)] = h
        return h
    }

    nonisolated static func key(_ e: Evidence) -> String {
        "\(e.page)|\(e.quote ?? "")|\(e.box.map { "\($0.x),\($0.y),\($0.w),\($0.h)" } ?? "")"
    }
}
