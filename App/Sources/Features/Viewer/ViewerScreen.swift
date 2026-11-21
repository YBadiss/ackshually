import SwiftUI
import UniformTypeIdentifiers

/// Root screen (M2 opens straight into the last PDF; S1 is M3): nav bar + adaptive viewer,
/// file importer and settings. Owns no answer logic; that's `ViewerModel`.
struct ViewerScreen: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    @State private var importing = false
    @State private var settings = false
    @AppStorage("demo") private var demo = false
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Group {
                if let rb = model.rulebook {
                    AdaptiveViewerLayout(model: model, voice: voice, document: rb.pdf)
                } else {
                    EmptyLibraryView(error: model.openError, onOpen: { importing = true }, onSample: { model.openSample() })
                }
            }
            .navigationTitle(model.rulebook?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { menu }
        }
        .tint(theme.colors.accent)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { model.importPicked(url) }
        }
        .sheet(isPresented: $settings) {
            SettingsView(keySource: keySource, demo: $demo,
                         onSaveKey: { Keychain.set($0, for: APIKeyStore.account) },
                         onClearKey: { Keychain.set(nil, for: APIKeyStore.account) },
                         onDone: { settings = false })
                .themed()
        }
    }

    private var keySource: String {
        if APIKeyStore.keychainKey != nil { return "saved in Keychain" }
        if APIKeyStore.environmentKey != nil { return "from ANTHROPIC_API_KEY" }
        return "none (demo answers)"
    }

    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Open a rulebook PDF…", systemImage: "doc") { importing = true }
                Button("Sample rulebook", systemImage: "book") { model.openSample() }
                Divider()
                Button("Settings", systemImage: "gearshape") { settings = true }
            } label: {
                Image(systemName: "ellipsis.circle").accessibilityLabel("More")
            }
            .accessibilityIdentifier("moreMenu")
        }
    }
}

#Preview { ViewerScreen(model: Fixtures.model(), voice: AskController()).themed() }
#Preview("Empty") { ViewerScreen(model: ViewerModel(), voice: AskController()).themed() }
