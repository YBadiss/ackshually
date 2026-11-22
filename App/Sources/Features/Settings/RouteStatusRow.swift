import SwiftUI

/// Settings' first row: which service answers, in plain words. Nothing to fill in.
struct RouteStatusRow: View {
    var status: RouteStatus
    @Environment(\.theme) private var theme

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(status.title)
                    .font(theme.font.row.weight(.semibold))
                    .foregroundStyle(theme.colors.label)
                    .accessibilityIdentifier("activeRoute")
                Text(status.detail)
                    .font(theme.font.footnote)
                    .foregroundStyle(theme.colors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("activeRouteDetail")
            }
        } icon: {
            Image(systemName: status.systemImage)
                .foregroundStyle(status.isSetUp ? theme.colors.tint : theme.colors.secondaryLabel)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    Form {
        RouteStatusRow(status: Fixtures.routeBundled)
        RouteStatusRow(status: Fixtures.routeOverride)
        RouteStatusRow(status: Fixtures.routeAPIKey)
        RouteStatusRow(status: Fixtures.routeNone)
    }
    .themed()
}

#Preview("Dark, AX5") {
    Form { RouteStatusRow(status: Fixtures.routeNone) }
        .themed()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility5)
}
