import Foundation
import Observation

/// Settings' state: the answer route and the demo toggle, read from and written to the injected credentials
/// and settings (the Keychain and UserDefaults in the app).
@MainActor
@Observable
final class SettingsModel {
    private(set) var status: RouteStatus
    var demoAnswers: Bool {
        didSet { settings.demoAnswers = demoAnswers }
    }

    @ObservationIgnored private let credentials: any CredentialAccess
    @ObservationIgnored private let settings: any AppSettings

    init(credentials: any CredentialAccess, settings: any AppSettings) {
        self.credentials = credentials
        self.settings = settings
        status = credentials.status
        demoAnswers = settings.demoAnswers
    }

    /// nil removes the item.
    func save(_ value: String?, for item: CredentialItem) {
        credentials.save(value, for: item)
        status = credentials.status
    }
}
