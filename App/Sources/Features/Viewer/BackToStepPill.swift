import SwiftUI

/// "Back to Step N" (S8): a glass button over the PDF once the user pinches/pans away.
struct BackToStepPill: View {
    var step: Int
    var action: () -> Void

    var body: some View {
        Button("Back to Step \(step)", systemImage: "arrow.uturn.backward", action: action)
            .buttonStyle(.glass)
            .accessibilityIdentifier("backToStep")
    }
}

#Preview {
    VStack(spacing: 12) {
        BackToStepPill(step: 2) {}
        BackToStepPill(step: 2) {}.dynamicTypeSize(.accessibility3)
        BackToStepPill(step: 2) {}.environment(\.colorScheme, .dark)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Fixtures.pageBackdrop)
    .themed()
}
