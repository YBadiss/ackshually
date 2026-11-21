import SwiftUI

/// Settings bound to the Keychain and the demo flag.
struct SettingsSheet: View {
    var onDone: () -> Void
    @AppStorage("demo") private var demo = false
    @State private var revision = 0

    var body: some View {
        SettingsView(keySource: keySource, demo: $demo,
                     onSaveKey: { Keychain.set($0, for: APIKeyStore.account); revision += 1 },
                     onClearKey: { Keychain.set(nil, for: APIKeyStore.account); revision += 1 },
                     onDone: onDone)
            .id(revision)
    }

    private var keySource: String {
        if APIKeyStore.keychainKey != nil { return "saved in Keychain" }
        if APIKeyStore.environmentKey != nil { return "from ANTHROPIC_API_KEY" }
        return "none (demo answers)"
    }
}
