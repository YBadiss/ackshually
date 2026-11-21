import Foundation

/// Minimal order-preserving JSON value. Used to build request bodies byte-for-byte deterministically
/// (stable prompt-cache prefix) and to keep schema property order (= streaming order).
public indirect enum JSONValue: Sendable, Equatable,
    ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([(String, JSONValue)])

    public init(stringLiteral v: String) { self = .string(v) }
    public init(integerLiteral v: Int) { self = .int(v) }
    public init(floatLiteral v: Double) { self = .double(v) }
    public init(booleanLiteral v: Bool) { self = .bool(v) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(elements) }
    public init(nilLiteral: ()) { self = .null }

    public static func == (a: JSONValue, b: JSONValue) -> Bool { a.serialized() == b.serialized() }

    public func serialized() -> String {
        var s = ""
        write(into: &s)
        return s
    }

    public var data: Data { Data(serialized().utf8) }

    private func write(into s: inout String) {
        switch self {
        case .string(let v): JSONValue.escape(v, into: &s)
        case .int(let v): s += String(v)
        case .double(let v): s += String(v)
        case .bool(let v): s += v ? "true" : "false"
        case .null: s += "null"
        case .array(let a):
            s += "["
            for (i, v) in a.enumerated() {
                if i > 0 { s += "," }
                v.write(into: &s)
            }
            s += "]"
        case .object(let o):
            s += "{"
            for (i, (k, v)) in o.enumerated() {
                if i > 0 { s += "," }
                JSONValue.escape(k, into: &s)
                s += ":"
                v.write(into: &s)
            }
            s += "}"
        }
    }

    private static func escape(_ str: String, into s: inout String) {
        s += "\""
        for scalar in str.unicodeScalars {
            switch scalar {
            case "\"": s += "\\\""
            case "\\": s += "\\\\"
            case "\n": s += "\\n"
            case "\r": s += "\\r"
            case "\t": s += "\\t"
            default:
                if scalar.value < 0x20 {
                    s += String(format: "\\u%04x", scalar.value)
                } else {
                    s.unicodeScalars.append(scalar)
                }
            }
        }
        s += "\""
    }
}
