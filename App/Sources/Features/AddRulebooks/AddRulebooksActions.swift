import AckshuallyCore

/// What the "Add N Rulebooks" sheet (S14) can ask for. Glue (`AddRulebooksScreen`) forwards each to
/// `LibraryModel`; previews and tests pass `.none`.
struct AddRulebooksActions {
    var move: (_ fileNames: [String], _ toGroup: String, _ before: String?) -> Void
    var moveTo: (_ fileName: String, AddRulebooksContent.MoveTarget.Kind) -> Void
    var moveToNewGame: (String) -> Void
    var skip: ([String]) -> Void
    var setRole: (String, BookRole) -> Void
    var renameBook: (String, String) -> Void
    var renameGroup: (String, String) -> Void
    var add: () -> Void
    var cancel: () -> Void

    @MainActor static let none = AddRulebooksActions(move: { _, _, _ in }, moveTo: { _, _ in }, moveToNewGame: { _ in }, skip: { _ in },
                                          setRole: { _, _ in }, renameBook: { _, _ in }, renameGroup: { _, _ in },
                                          add: {}, cancel: {})
}
