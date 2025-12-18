import Foundation

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
        
        // Debug: Log raw JSON response
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[VortexSDK] Raw widget configuration response:")
            print(jsonString)
        }
        #endif
        
        let decoder = JSONDecoder()
        let configResponse = try decoder.decode(WidgetConfigurationResponse.self, from: data)
        
        // Store session attestation for future requests
        if let attestation = configResponse.data.sessionAttestation {
            self.sessionAttestation = attestation
        }
        
        return configResponse.data.widgetConfiguration
    }
    
    // MARK: - Invitations
    
    /// Create a new invitation
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - widgetConfigurationId: ID of the widget configuration
    ///   - payload: Invitation payload (content tokens, etc.)
    ///   - source: Source of the invitation (e.g., "email")
    ///   - groups: Associated groups
    ///   - templateVariables: Optional template variables
    ///   - metadata: Optional metadata
    /// - Returns: Created invitation response
    public func createInvitation(
        jwt: String,
        widgetConfigurationId: String,
        payload: [String: Any],
        source: String = "email",
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
        let url = baseURL.appendingPathComponent("/api/v1/invitations/generate-shareable-link-invite")
        
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
