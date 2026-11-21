import AckshuallyCore

/// How each confidence level reads on the proof line.
extension Confidence {
    var symbol: String {
        switch self {
        case .stated: "checkmark.seal.fill"
        case .inferred: "exclamationmark.triangle.fill"
        case .notCovered: "questionmark.circle.fill"
        }
    }

    var phrase: String {
        switch self {
        case .stated: "Stated in the rules"
        case .inferred: "Inferred from the rules"
        case .notCovered: "Not covered by the rules"
        }
    }
}
