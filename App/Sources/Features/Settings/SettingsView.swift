import SwiftUI

/// Dev-only settings (M2): API key (stored in the Keychain by the caller), demo mode.
struct SettingsView: View {
    var keySource: String
    @Binding var demo: Bool
    var onSaveKey: (String) -> Void
    var onClearKey: () -> Void
    var onDone: () -> Void
    @State private var key = ""
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("apiKeyField")
                    Button("Save Key") { onSaveKey(key.trimmingCharacters(in: .whitespacesAndNewlines)); key = "" }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove Saved Key", role: .destructive, action: onClearKey)
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Current: \(keySource). Stored in the Keychain on this device only. On the simulator, ANTHROPIC_API_KEY from the launch environment also works.")
                }
                .listRowBackground(theme.colors.card)
                Section {
                    Toggle("Demo Answers", isOn: $demo)
                } footer: {
                    Text("Streams a scripted answer for the sample rulebook, with no API calls. Used for the sample when no key is set; your own rulebooks need an API key.")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(role: .confirm, action: onDone) } }
        }
    }
}

#Preview {
    SettingsView(keySource: "none (demo answers)", demo: .constant(true), onSaveKey: { _ in }, onClearKey: {}, onDone: {})
        .themed()
}
#Preview("Dark, AX5") {
    SettingsView(keySource: "none (demo answers)", demo: .constant(true), onSaveKey: { _ in }, onClearKey: {}, onDone: {})
        .themed()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility5)
}
