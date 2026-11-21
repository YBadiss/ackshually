import Foundation

/// USD per million tokens. First-party API list prices (cached 2026-11). Cache write = 5-minute TTL (1.25x input); 1-hour TTL writes cost 2x input.
public struct ModelPricing: Sendable {
    public let input: Double
    public let output: Double
    public let cacheRead: Double
    public let cacheWrite: Double

    public static func forModel(_ model: String) -> ModelPricing? {
        switch model {
        case "claude-opus-5-5": return .init(input: 4, output: 20, cacheRead: 0.20, cacheWrite: 5)
        case "claude-sonnet-5-5": return .init(input: 2, output: 10, cacheRead: 0.10, cacheWrite: 2.5)
        // Haiku 5.5: prompts ≤100K tokens. Above that $0.50/$2.50 (see cost(…)).
        case "claude-haiku-5-5": return .init(input: 0.10, output: 0.50, cacheRead: 0.01, cacheWrite: 0.125)
        case "claude-fable-5-2": return .init(input: 8, output: 40, cacheRead: 0.20, cacheWrite: 10)
        case "claude-opus-5": return .init(input: 5, output: 25, cacheRead: 0.50, cacheWrite: 6.25)
        case "claude-sonnet-5": return .init(input: 2, output: 10, cacheRead: 0.20, cacheWrite: 2.5)
        default: return nil
        }
    }

    public static func cost(model: String, usage u: TokenUsage) -> Double? {
        guard var p = forModel(model) else { return nil }
        let promptTokens = u.inputTokens + u.cacheReadInputTokens + u.cacheCreationInputTokens
        if model == "claude-haiku-5-5", promptTokens > 100_000 {
            p = .init(input: 0.50, output: 2.50, cacheRead: 0.05, cacheWrite: 0.625)
        }
        let m = 1_000_000.0
        return Double(u.inputTokens) * p.input / m
            + Double(u.outputTokens) * p.output / m
            + Double(u.cacheReadInputTokens) * p.cacheRead / m
            + Double(u.cacheCreationInputTokens - u.cacheCreation1hInputTokens) * p.cacheWrite / m
            + Double(u.cacheCreation1hInputTokens) * p.input * 2 / m
    }
}
