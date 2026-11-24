import SwiftUI

/// Row label: leading label, trailing secondary value, chevron (or a checkmark when selected).
/// A value too long to sit beside the label (a branch's whole-sentence verdict) goes under it.
struct ValueRow: View {
    var title: String
    var systemImage: String?
    var value: String?
    var accessory: Accessory = .chevron
    enum Accessory { case chevron, checkmark, none }
    @Environment(\.theme) private var theme
    /// Lines a stacked value up with the title text, past the label's icon.
    @ScaledMetric(relativeTo: .body) private var iconIndent: CGFloat = 28

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.m) {
            // Side by side when both fit on one line; otherwise stacked (side by side, the title's
            // priority squeezed a long value to one letter per line).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.m) {
                    titleLabel.layoutPriority(1)
                    Spacer(minLength: theme.spacing.s)
                    valueText?.multilineTextAlignment(.trailing)
                }
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    titleLabel
                    valueText?.padding(.leading, systemImage == nil ? 0 : iconIndent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            accessoryView
        }
        .contentShape(.rect)
    }

    private var titleLabel: some View {
        Group {
            if let systemImage {
                Label { Text(title) } icon: { Image(systemName: systemImage).foregroundStyle(theme.colors.tint) }
            } else {
                Text(title)
            }
        }
        .font(theme.font.row)
        .foregroundStyle(theme.colors.label)
    }

    private var valueText: Text? {
        value.map { Text($0).font(theme.font.rowValue).foregroundStyle(theme.colors.secondaryLabel) }
    }

    @ViewBuilder private var accessoryView: some View {
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
}

#Preview {
    List {
        ValueRow(title: "Model", value: "claude-sonnet-5-5")
        ValueRow(title: "Demo Answers", systemImage: "sparkles", accessory: .checkmark)
        ValueRow(title: "Plain", accessory: .none)
        ValueRow(title: "If you meant bird cards (the suit) rather than the Eyrie faction", systemImage: "arrow.triangle.branch",
                 value: "Bird cards score nothing by themselves; they count toward the Decree.")
    }
    .themed()
}
#Preview("AX5, dark") {
    List { ValueRow(title: "Evidence", systemImage: "quote.opening", value: "JSON quotes") }
        .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
