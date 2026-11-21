import Foundation

/// Path component inside a JSON document.
public enum JSONPathComponent: Hashable, Sendable, CustomStringConvertible {
    case key(String)
    case index(Int)

    public var description: String {
        switch self {
        case .key(let k): return k
        case .index(let i): return "[\(i)]"
        }
    }
}

/// Feed JSON text in arbitrary chunks; get told each time a value (at any depth) is complete,
/// with its path and raw JSON text. This is what lets us surface `restated_question`, `verdict`
/// and step 1 while the rest of the answer is still streaming.
///
/// Leading noise before the first `{` (e.g. a stray ```json fence) is ignored.
public struct IncrementalJSONScanner: Sendable {
    public struct Completed: Sendable {
        public let path: [JSONPathComponent]
        public let rawJSON: String
    }

    private enum Container {
        case object(key: String?, expectingKey: Bool, start: Int)
        case array(index: Int, start: Int)
    }

    private var buffer: [UInt8] = []
    private var stack: [Container] = []
    private var inString = false
    private var escape = false
    private var stringStart = 0
    private var literalStart: Int? = nil
    private var started = false
    public private(set) var finished = false

    public init() {}

    public var text: String { String(decoding: buffer, as: UTF8.self) }

    public mutating func feed(_ chunk: String) -> [Completed] {
        var out: [Completed] = []
        for byte in chunk.utf8 {
            let pos = buffer.count
            buffer.append(byte)
            if finished { continue }
            if !started {
                if byte == UInt8(ascii: "{") || byte == UInt8(ascii: "[") {
                    started = true
                } else {
                    continue
                }
            }
            if inString {
                if escape { escape = false; continue }
                if byte == UInt8(ascii: "\\") { escape = true; continue }
                if byte == UInt8(ascii: "\"") {
                    inString = false
                    let raw = String(decoding: buffer[stringStart...pos], as: UTF8.self)
                    if case .object(_, true, let s)? = stack.last {
                        let key = (try? JSONDecoder().decode(String.self, from: Data(raw.utf8))) ?? raw
                        stack[stack.count - 1] = .object(key: key, expectingKey: false, start: s)
                    } else {
                        out.append(Completed(path: currentPath(), rawJSON: raw))
                    }
                }
                continue
            }
            // Literal (number / true / false / null) termination.
            if let ls = literalStart, isDelimiter(byte) {
                let raw = String(decoding: buffer[ls..<pos], as: UTF8.self)
                literalStart = nil
                out.append(Completed(path: currentPath(), rawJSON: raw))
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
                stringStart = pos
            case UInt8(ascii: "{"):
                stack.append(.object(key: nil, expectingKey: true, start: pos))
            case UInt8(ascii: "["):
                stack.append(.array(index: 0, start: pos))
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                guard let top = stack.popLast() else { break }
                let start: Int
                switch top {
                case .object(_, _, let s): start = s
                case .array(_, let s): start = s
                }
                let raw = String(decoding: buffer[start...pos], as: UTF8.self)
                out.append(Completed(path: currentPath(), rawJSON: raw))
                if stack.isEmpty { finished = true }
            case UInt8(ascii: ","):
                if let top = stack.last {
                    switch top {
                    case .object(_, _, let s): stack[stack.count - 1] = .object(key: nil, expectingKey: true, start: s)
                    case .array(let i, let s): stack[stack.count - 1] = .array(index: i + 1, start: s)
                    }
                }
            case UInt8(ascii: ":"):
                if case .object(let k, _, let s)? = stack.last {
                    stack[stack.count - 1] = .object(key: k, expectingKey: false, start: s)
                }
            case UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: "\r"), UInt8(ascii: "\t"):
                break
            default:
                if literalStart == nil { literalStart = pos }
            }
        }
        return out
    }

    private func isDelimiter(_ b: UInt8) -> Bool {
        b == UInt8(ascii: ",") || b == UInt8(ascii: "}") || b == UInt8(ascii: "]")
            || b == UInt8(ascii: " ") || b == UInt8(ascii: "\n") || b == UInt8(ascii: "\r") || b == UInt8(ascii: "\t")
    }

    /// Path of the value currently being parsed (i.e. key/index in each enclosing container).
    private func currentPath() -> [JSONPathComponent] {
        stack.compactMap { c in
            switch c {
            case .object(let k, _, _): return k.map { .key($0) }
            case .array(let i, _): return .index(i)
            }
        }
    }
}
