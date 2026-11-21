import SwiftUI

/// Branch rows (S5/S9): "Without a Battery … Discard all 3. ›". Tapping one switches the step
/// cards to that branch; while a branch is shown, "Main Answer" leads the group and returns.
struct BranchRows: View {
    var rows: [BranchRow]
    var onSelect: (Int?) -> Void

    private var showingBranch: Bool { rows.contains(where: \.isActive) }

    var body: some View {
        GroupedSection(title: "If…") {
            if showingBranch {
                Button { onSelect(nil) } label: {
                    ValueRow(title: "Main Answer", systemImage: "arrow.uturn.backward", value: nil, accessory: .none)
                }
                .accessibilityIdentifier("mainAnswer")
            }
            ForEach(rows) { row in
                Button { onSelect(row.isActive ? nil : row.index) } label: {
                    ValueRow(title: row.condition, systemImage: "arrow.triangle.branch", value: row.verdict,
                             accessory: row.isActive ? .checkmark : .chevron)
                }
                .accessibilityAddTraits(row.isActive ? .isSelected : [])
                .accessibilityIdentifier("branch-\(row.index)")
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Rows") {
    ScrollView {
        VStack(spacing: 24) {
            BranchRows(rows: Fixtures.branchRows(active: nil)) { _ in }
            BranchRows(rows: Fixtures.branchRows(active: 0)) { _ in }
            StepListRows(rows: Fixtures.stepRows, current: 1) { _ in }
            AssumptionRows(assumptions: Fixtures.answer.assumptions)
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
}

#Preview("AX5") {
    ScrollView {
        VStack(spacing: 24) {
            BranchRows(rows: Fixtures.branchRows(active: nil)) { _ in }
            StepListRows(rows: Fixtures.stepRows, current: 0) { _ in }
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
    .dynamicTypeSize(.accessibility5)
}

#Preview("Dark") {
    ScrollView {
        VStack(spacing: 24) {
            BranchRows(rows: Fixtures.branchRows(active: 0)) { _ in }
            StepListRows(rows: Fixtures.stepRows, current: 1) { _ in }
        }
        .padding()
    }
    .themeBackground(\.sheet)
    .themed()
    .preferredColorScheme(.dark)
}
