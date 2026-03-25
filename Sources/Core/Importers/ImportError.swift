import Foundation

public enum ImportError: Error, CustomStringConvertible {
    case missingField(String)
    case invalidData(String)
    case fileNotFound(String)

    public var description: String {
        switch self {
        case .missingField(let f): "Missing required field: \(f)"
        case .invalidData(let d): "Invalid data: \(d)"
        case .fileNotFound(let p): "File not found: \(p)"
        }
    }
}
