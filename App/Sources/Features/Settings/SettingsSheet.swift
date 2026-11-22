import SwiftUI

/// Settings bound to the Keychain (`CredentialStore`) and the demo flag.
struct SettingsSheet: View {
    var onDone: () -> Void
    @AppStorage("demo") private var demo = false
    @State private var status = RouteStatus.current

    var body: some View {
        SettingsView(status: status, demo: $demo,
                     onSave: { CredentialStore.save($0, $1); status = .current },
                     onRemove: { CredentialStore.save(nil, $0); status = .current },
                     onDone: onDone)
    }
}
