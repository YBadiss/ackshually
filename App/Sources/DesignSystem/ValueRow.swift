import SwiftUI

/// Row label: leading label, trailing secondary value, chevron (or a checkmark when selected).
struct ValueRow: View {
    var title: String
    var systemImage: String?
    var value: String?
    var accessory: Accessory = .chevron
    enum Accessory { case chevron, checkmark, none }
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.m) {
            Group {
                if let systemImage {
                    Label { Text(title) } icon: { Image(systemName: systemImage).foregroundStyle(theme.colors.tint) }
                } else {
                    Text(title)
                }
            }
            .font(theme.font.row)
            .foregroundStyle(theme.colors.label)
            .layoutPriority(1)
            Spacer(minLength: theme.spacing.s)
            if let value {
                Text(value).font(theme.font.rowValue).foregroundStyle(theme.colors.secondaryLabel)
                    .multilineTextAlignment(.trailing)
            }
            switch accessory {
            case .chevron:
                Image(systemName: "chevron.forward")
                    .font(theme.font.footnote.weight(.semibold))
                    .foregroundStyle(theme.colors.tertiaryLabel)
            case .checkmark:
                Image(systemName: "checkmark").font(theme.font.rowValue.weight(.semibold)).foregroundStyle(theme.colors.tint)
            case .none:
                EmptyView()
            }
        }
        .contentShape(.rect)
    }
}

#Preview {
    List {
        ValueRow(title: "Model", value: "claude-sonnet-5-5")
        ValueRow(title: "Demo Answers", systemImage: "sparkles", accessory: .checkmark)
        ValueRow(title: "Plain", accessory: .none)
    }
    .themed()
}
#Preview("AX5, dark") {
    List { ValueRow(title: "Evidence", systemImage: "quote.opening", value: "JSON quotes") }
        .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
