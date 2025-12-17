import Foundation

// MARK: - API Response Types

/// Response from widget configuration endpoint
public struct WidgetConfigurationResponse: Codable {
    public let data: WidgetConfiguration
    public let sessionAttestation: String?
}

/// Response from create invitation endpoint
public struct CreateInvitationResponse: Codable {
    public let success: Bool
    public let invitationId: String?
    public let message: String?
}

/// Response from shareable link endpoint
public struct ShareableLinkResponse: Codable {
    public let link: String
    public let expiresAt: String?
}

/// Group information for invitations
public struct GroupDTO: Codable {
    public let id: String?
    public let groupId: String?
    public let type: String
    public let name: String
    
    public init(id: String?, groupId: String?, type: String, name: String) {
        self.id = id
        self.groupId = groupId
        self.type = type
        self.name = name
    }
}

// MARK: - Vortex Client

/// Main API client for communicating with Vortex backend
@MainActor
public class VortexClient {
    private let baseURL: URL
    private let clientName: String
    private let clientVersion: String
    private let sessionId: String
    private var sessionAttestation: String?
    
    /// Initialize a new Vortex API client
    /// - Parameters:
    ///   - baseURL: Base URL of the Vortex API (e.g., "https://client-api.vortexsoftware.com")
    ///   - clientName: Name of the client application
    ///   - clientVersion: Version of the client SDK
    ///   - sessionId: Unique session identifier
    public init(
        baseURL: URL,
        clientName: String = "VortexSDK-iOS",
        clientVersion: String = "1.0.0",
        sessionId: String = UUID().uuidString
    ) {
        self.baseURL = baseURL
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.sessionId = sessionId
    }
    
    // MARK: - Widget Configuration
    
    /// Fetch widget configuration from the API
    /// - Parameters:
    ///   - componentId: The widget/component ID
    ///   - jwt: JWT authentication token
    /// - Returns: Widget configuration
    public func getWidgetConfiguration(
        componentId: String,
        jwt: String
    ) async throws -> WidgetConfiguration {
        let url = baseURL.appendingPathComponent("/api/v1/widgets/\(componentId)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        request.setValue(clientVersion, forHTTPHeaderField: "x-vortex-client-version")
        request.setValue(clientName, forHTTPHeaderField: "x-vortex-client-name")
        
        if let attestation = sessionAttestation {
            request.setValue(attestation, forHTTPHeaderField: "x-session-attestation")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VortexError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let configResponse = try decoder.decode(WidgetConfigurationResponse.self, from: data)
        
        // Store session attestation for future requests
        if let attestation = configResponse.sessionAttestation {
            self.sessionAttestation = attestation
        }
        
        return configResponse.data
    }
    
    // MARK: - Invitations
    
    /// Create a new invitation
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - widgetConfigurationId: ID of the widget configuration
    ///   - payload: Invitation payload (content tokens, etc.)
    ///   - source: Source of the invitation (e.g., "ios-sdk")
    ///   - groups: Associated groups
    ///   - templateVariables: Optional template variables
    ///   - metadata: Optional metadata
    /// - Returns: Created invitation response
    public func createInvitation(
        jwt: String,
        widgetConfigurationId: String,
        payload: [String: Any],
        source: String = "ios-sdk",
        groups: [GroupDTO]? = nil,
        templateVariables: [String: String]? = nil,
        metadata: [String: Any]? = nil
    ) async throws -> CreateInvitationResponse {
        let url = baseURL.appendingPathComponent("/api/v1/invitations")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        request.setValue(clientVersion, forHTTPHeaderField: "x-vortex-client-version")
        request.setValue(clientName, forHTTPHeaderField: "x-vortex-client-name")
        
        if let attestation = sessionAttestation {
            request.setValue(attestation, forHTTPHeaderField: "x-session-attestation")
        }
        
        var body: [String: Any] = [
            "widgetConfigurationId": widgetConfigurationId,
            "payload": payload,
            "source": source
        ]
        
        if let groups = groups {
            body["groups"] = groups.map { group in
                [
                    "id": group.id as Any,
                    "groupId": group.groupId as Any,
                    "type": group.type,
                    "name": group.name
                ]
            }
        }
        
        if let templateVariables = templateVariables {
            body["templateVariables"] = templateVariables
        }
        
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VortexError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CreateInvitationResponse.self, from: data)
    }
    
    // MARK: - Shareable Links
    
    /// Get a shareable invitation link
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - widgetConfigurationId: ID of the widget configuration
    ///   - groups: Associated groups
    ///   - templateVariables: Optional template variables
    /// - Returns: Shareable link response
    public func getShareableLink(
        jwt: String,
        widgetConfigurationId: String,
        groups: [GroupDTO]? = nil,
        templateVariables: [String: String]? = nil
    ) async throws -> ShareableLinkResponse {
        let url = baseURL.appendingPathComponent("/api/v1/invitations/shareable-link")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        request.setValue(clientVersion, forHTTPHeaderField: "x-vortex-client-version")
        request.setValue(clientName, forHTTPHeaderField: "x-vortex-client-name")
        
        if let attestation = sessionAttestation {
            request.setValue(attestation, forHTTPHeaderField: "x-session-attestation")
        }
        
        var body: [String: Any] = [
            "widgetConfigurationId": widgetConfigurationId
        ]
        
        if let groups = groups {
            body["groups"] = groups.map { group in
                [
                    "id": group.id as Any,
                    "groupId": group.groupId as Any,
                    "type": group.type,
                    "name": group.name
                ]
            }
        }
        
        if let templateVariables = templateVariables {
            body["templateVariables"] = templateVariables
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VortexError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ShareableLinkResponse.self, from: data)
    }
}

// MARK: - Error Types

/// Errors that can occur during Vortex API operations
public enum VortexError: LocalizedError {
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
