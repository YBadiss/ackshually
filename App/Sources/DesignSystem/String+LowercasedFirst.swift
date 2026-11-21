import Foundation

extension String {
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}
