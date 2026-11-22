import Foundation
import AckshuallyCore

/// What the spotlight shows on one page: the cited regions (normalized, origin top-left) and how.
struct Spotlight: Equatable {
    enum Shape: Equatable {
        /// Quote lines: each gets a rounded outline.
        case lines
        /// A figure box: one thicker outline.
        case figure
    }
    var regions: [NormalizedBox]
    var shape: Shape
}
