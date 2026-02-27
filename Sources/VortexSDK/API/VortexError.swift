import Foundation

/// Errors that can occur during Vortex API operations
public enum VortexError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case encodingError(Error)
    case missingConfiguration
    case missingJWT
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(Self.detailedDecodingErrorMessage(error))"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .missingConfiguration:
            return "Widget configuration not found"
        case .missingJWT:
            return "JWT token is required"
        }
    }
    
    /// Extract detailed information from DecodingError for debugging.
    /// Swift's `localizedDescription` loses the key path and type mismatch details.
    private static func detailedDecodingErrorMessage(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        
        switch decodingError {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Type mismatch: expected \(type) at path '\(path)' — \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Value not found: expected \(type) at path '\(path)' — \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Key '\(key.stringValue)' not found at path '\(path)' — \(context.debugDescription)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Data corrupted at path '\(path)' — \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
