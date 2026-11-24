import SwiftUI

/// Settings: which service answers (the bundled token, nothing to enter), demo mode, and a Developer
/// disclosure with a token override and "use my own Anthropic API key". Keychain writes are the caller's.
struct SettingsView: View {
    var status: RouteStatus
    @Binding var demo: Bool
    var onSave: (String, CredentialItem) -> Void
    var onRemove: (CredentialItem) -> Void
    var onDone: () -> Void
    /// Games in My Games (Developer → Remove All Games).
    var gameCount = 0
    var onRemoveAllGames: () -> Void = {}
    @State private var confirmingRemoveAll = false
    /// Seeded once: open when nothing is set up, so the way to fix it is on screen.
    @State private var showsDeveloper: Bool
    @Environment(\.theme) private var theme

    init(status: RouteStatus, demo: Binding<Bool>, onSave: @escaping (String, CredentialItem) -> Void,
         onRemove: @escaping (CredentialItem) -> Void, onDone: @escaping () -> Void,
         gameCount: Int = 0, onRemoveAllGames: @escaping () -> Void = {}) {
        self.gameCount = gameCount
        self.onRemoveAllGames = onRemoveAllGames
        self.status = status
        _demo = demo
        self.onSave = onSave
        self.onRemove = onRemove
        self.onDone = onDone
        _showsDeveloper = State(initialValue: !status.isSetUp)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RouteStatusRow(status: status)
                } footer: {
                    if let footer = status.footer { Text(footer) }
                }
                .listRowBackground(theme.colors.card)
                Section {
                    Toggle("Demo Answers", isOn: $demo)
                } footer: {
                    Text("Streams a scripted answer for the sample rulebook, with no API calls.")
                }
                .listRowBackground(theme.colors.card)
                Section {
                    DisclosureGroup("Developer", isExpanded: $showsDeveloper) {
                        CredentialField(title: "Access Token Override", prompt: "ack_…", isSaved: status.tokenOverrideSaved,
                                        fieldID: "tokenOverrideField", onSave: { onSave($0, .tokenOverride) },
                                        onRemove: { onRemove(.tokenOverride) })
                        CredentialField(title: "Use My Own Anthropic API Key", prompt: "sk-ant-…", isSaved: status.apiKeySaved,
                                        fieldID: "apiKeyField", onSave: { onSave($0, .apiKey) },
                                        onRemove: { onRemove(.apiKey) })
                        Button("Remove All Games", role: .destructive) { confirmingRemoveAll = true }
                            .disabled(gameCount == 0)
                            .accessibilityIdentifier("removeAllGames")
                    }
                    .accessibilityIdentifier("developerSection")
                } footer: {
                    if showsDeveloper {
                        Text("For development. The token built into the app comes first, then a token override (sent to the ackshually server), then your own API key (calls Anthropic directly). Both are stored in this device's Keychain only.")
                    }
                }
                .listRowBackground(theme.colors.card)
                Section("Answer Engine") {
                    LabeledContent("Model", value: "claude-sonnet-5-5")
                    LabeledContent("Evidence", value: "JSON quotes")
                    LabeledContent("Effort", value: "Low")
                }
                .listRowBackground(theme.colors.card)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.groupedBackground)
            .confirmationDialog("Remove all \(gameCount) games?", isPresented: $confirmingRemoveAll, titleVisibility: .visible) {
                Button("Remove All Games", role: .destructive, action: onRemoveAllGames)
            } message: {
                Text("Every rulebook PDF in My Games is removed from this device.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(role: .confirm, action: onDone) } }
        }
    }
}

#Preview("Bundled token") {
    SettingsView(status: Fixtures.routeBundled, demo: .constant(false), onSave: { _, _ in }, onRemove: { _ in }, onDone: {})
        .themed()
}
#Preview("Nothing set up") {
    SettingsView(status: Fixtures.routeNone, demo: .constant(false), onSave: { _, _ in }, onRemove: { _ in }, onDone: {},
                 gameCount: 4)
        .themed()
}
#Preview("Own key, dark, AX5") {
    SettingsView(status: Fixtures.routeAPIKey, demo: .constant(true), onSave: { _, _ in }, onRemove: { _ in }, onDone: {})
        .themed()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility5)
}
