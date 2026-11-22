import SwiftUI

/// A masked credential field with Save and, once one is saved, Remove. Pasting works as in any secure field.
/// Two Form rows: the field, then the actions.
struct CredentialField: View {
    var title: String
    var prompt: String
    var isSaved: Bool
    var fieldID: String
    var onSave: (String) -> Void
    var onRemove: () -> Void
    @State private var value = ""
    @Environment(\.theme) private var theme

    private var trimmed: String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(title)
                .font(theme.font.footnote.weight(.semibold))
                .foregroundStyle(theme.colors.secondaryLabel)
            SecureField(title, text: $value, prompt: Text(prompt))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(save)
                .accessibilityIdentifier(fieldID)
        }
        .accessibilityElement(children: .contain)
        HStack {
            Button(isSaved ? "Replace" : "Save", action: save)
                .disabled(trimmed.isEmpty)
                .accessibilityIdentifier("\(fieldID).save")
            Spacer()
            if isSaved {
                Button("Remove", role: .destructive, action: onRemove)
                    .accessibilityIdentifier("\(fieldID).remove")
            }
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        value = ""
    }
}

#Preview {
    Form {
        CredentialField(title: "Access Token Override", prompt: "ack_…", isSaved: false, fieldID: "tokenOverrideField",
                        onSave: { _ in }, onRemove: {})
        CredentialField(title: "Anthropic API Key", prompt: "sk-ant-…", isSaved: true, fieldID: "apiKeyField",
                        onSave: { _ in }, onRemove: {})
    }
    .themed()
}

#Preview("Dark, AX5") {
    Form {
        CredentialField(title: "Anthropic API Key", prompt: "sk-ant-…", isSaved: true, fieldID: "apiKeyField",
                        onSave: { _ in }, onRemove: {})
    }
    .themed()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
