import SwiftUI
import AckshuallyCore

/// Branch pills (S5/S9): "No Battery? Discard all 3. ›". Tapping one switches the cards to that
/// branch; "‹ Main answer" returns.
struct BranchPills: View {
    var branches: [Branch]
    var active: Int?
    var onSelect: (Int?) -> Void

    var body: some View {
        if active != nil {
            OutlinePill(text: "‹ Main answer") { onSelect(nil) }
        }
        ForEach(Array(branches.enumerated()), id: \.offset) { i, b in
            OutlinePill(text: "\(b.condition)? \(b.verdict) ›", active: active == i) {
                onSelect(active == i ? nil : i)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        FlowRow(spacing: 6) { BranchPills(branches: Fixtures.branches, active: nil) { _ in } }
        FlowRow(spacing: 6) { BranchPills(branches: Fixtures.branches, active: 0) { _ in } }
    }
    .padding()
    .themed()
}
