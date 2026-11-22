import SwiftUI

/// The error header's buttons: Try Again, plus Open Settings first when the failure is fixed there
/// (a rejected access token or API key). Laid out by the caller (row, or column when it doesn't fit).
struct FailureActions: View {
    var onRetry: () -> Void
    var onSettings: (() -> Void)?

    var body: some View {
        if let onSettings {
            Button("Open Settings", action: onSettings)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("failureSettings")
            Button("Try Again", action: onRetry)
                .buttonStyle(.bordered)
        } else {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack { FailureActions(onRetry: {}, onSettings: {}) }
        HStack { FailureActions(onRetry: {}) }
    }
    .padding()
    .themed()
}
