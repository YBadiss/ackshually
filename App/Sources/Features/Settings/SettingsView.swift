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
                    Button("Save key") { onSaveKey(key.trimmingCharacters(in: .whitespacesAndNewlines)); key = "" }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove saved key", role: .destructive, action: onClearKey)
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("Current: \(keySource). Stored in the Keychain on this device only. On the simulator, ANTHROPIC_API_KEY from the launch environment also works.")
                }
                Section {
                    Toggle("Demo answers (no API calls)", isOn: $demo)
                } footer: {
                    Text("Streams a scripted answer for the sample rulebook. Used automatically when no key is set.")
                }
                Section("Answer engine") {
                    LabeledContent("Model", value: "claude-sonnet-5-5")
                    LabeledContent("Evidence", value: "json quotes")
                    LabeledContent("Effort", value: "low")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDone) } }
            .tint(theme.colors.accent)
        }
    }
}

#Preview {
    SettingsView(keySource: "none (demo answers)", demo: .constant(true), onSaveKey: { _ in }, onClearKey: {}, onDone: {})
        .themed()
}
