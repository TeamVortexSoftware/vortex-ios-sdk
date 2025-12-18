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
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .missingConfiguration:
            return "Widget configuration not found"
        case .missingJWT:
            return "JWT token is required"
        }
    }
}
