import SwiftUI

/// ⋯ → Answer Details: each step's evidence with its match status, and "Copy JSON" (the raw
/// answer plus match results) so a missing highlight can be investigated from a real run.
struct AnswerDetailsView: View {
    var reports: [EvidenceReport]
    /// Which route answered: "ackshually server · host", "Anthropic API (own key)", "Demo answers".
    var route: String?
    var onCopy: () -> Void
    var onDone: () -> Void
    @State private var copied = false

    private var sections: [(title: String, rows: [EvidenceReport])] { EvidenceReport.sections(reports) }

    private var summary: String {
        let spotlit = reports.filter { $0.match?.isSpotlit == true }.count
        return "\(spotlit) of \(reports.count) passages highlighted"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let route {
                        LabeledContent("Answered by") {
                            Text(route).accessibilityIdentifier("answerRoute")
                        }
                    }
                    Text(summary).accessibilityIdentifier("detailsSummary")
                }
                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.rows) { EvidenceStatusRow(report: $0) }
                    }
                }
            }
            .navigationTitle("Answer Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(copied ? "Copied" : "Copy JSON", systemImage: copied ? "checkmark" : "doc.on.doc", action: copy)
                        .accessibilityIdentifier("copyAnswerJSON")
                }
            }
        }
    }

    private func copy() {
        onCopy()
        withAnimation(.snappy) { copied = true }
    }
}

#Preview {
    AnswerDetailsView(reports: Fixtures.evidenceReports, route: "ackshually server · ackshually.badyass.xyz", onCopy: {}, onDone: {})
        .themed()
}

#Preview("Dark, AX3") {
    AnswerDetailsView(reports: Fixtures.evidenceReports, route: "Anthropic API (own key)", onCopy: {}, onDone: {})
        .themed()
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
