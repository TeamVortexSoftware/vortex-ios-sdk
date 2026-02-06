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
        clientVersion: String = VortexSDKInfo.version,
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
    ///   - locale: Optional locale for i18n (e.g., "pt-BR", "en-US")
    /// - Returns: Widget configuration data including deploymentId and other metadata
    public func getWidgetConfiguration(
        componentId: String,
        jwt: String,
        locale: String? = nil
    ) async throws -> WidgetConfigurationData {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/api/v1/widgets/\(componentId)"), resolvingAgainstBaseURL: false)!
        
        // Add locale query parameter if provided
        if let locale = locale {
            urlComponents.queryItems = [URLQueryItem(name: "locale", value: locale)]
        }
        
        let url = urlComponents.url!
        
        #if DEBUG
        print("[VortexSDK] Fetching widget configuration from URL: \(url.absoluteString)")
        print("[VortexSDK] Locale parameter: \(locale ?? "nil")")
        #endif
        
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
            print("\n")
            print("╔══════════════════════════════════════════════════════════════════════════════╗")
            print("║                    [VortexSDK] WIDGET CONFIGURATION                          ║")
            print("╚══════════════════════════════════════════════════════════════════════════════╝")
            print(jsonString)
            print("╔══════════════════════════════════════════════════════════════════════════════╗")
            print("║                    [VortexSDK] END WIDGET CONFIGURATION                      ║")
            print("╚══════════════════════════════════════════════════════════════════════════════╝")
            print("\n")
        }
        #endif
        
        let decoder = JSONDecoder()
        let configResponse = try decoder.decode(WidgetConfigurationResponse.self, from: data)
        
        // Store session attestation for future requests
        if let attestation = configResponse.data.sessionAttestation {
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
    ///   - source: Source of the invitation (e.g., "email", "sms")
    ///   - groups: Associated groups
    ///   - targets: Optional targets array for SMS invitations
    ///   - templateVariables: Optional template variables
    ///   - metadata: Optional metadata
    /// - Returns: Created invitation response
    public func createInvitation(
        jwt: String,
        widgetConfigurationId: String,
        payload: [String: Any],
        source: String = "email",
        groups: [GroupDTO]? = nil,
        targets: [[String: Any]]? = nil,
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
        
        if let targets = targets {
            body["targets"] = targets
        }
        
        if let templateVariables = templateVariables {
            body["templateVariables"] = templateVariables
        }
        
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        
        #if DEBUG
        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[VortexSDK] POST /api/v1/invitations request body:")
            print(bodyString)
        }
        #endif
        
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
    ///   - metadata: Optional metadata (e.g., unfurl parameters)
    /// - Returns: Shareable link response
    public func getShareableLink(
        jwt: String,
        widgetConfigurationId: String,
        groups: [GroupDTO]? = nil,
        templateVariables: [String: String]? = nil,
        metadata: [String: Any]? = nil
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
        
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        
        #if DEBUG
        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[VortexSDK] POST /api/v1/invitations/generate-shareable-link-invite request body:")
            print(bodyString)
        }
        #endif
        
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
    
    // MARK: - Outgoing Invitations
    
    /// Fetch outgoing invitations for the current user
    /// - Parameter jwt: JWT authentication token
    /// - Returns: List of outgoing invitations
    public func getOutgoingInvitations(jwt: String) async throws -> [OutgoingInvitation] {
        let url = baseURL.appendingPathComponent("/api/v1/invitations/sent")
        
        print("[VortexSDK] VortexClient.getOutgoingInvitations() - URL: \(url.absoluteString)")
        
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
        
        print("[VortexSDK] VortexClient.getOutgoingInvitations() - Making request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[VortexSDK] VortexClient.getOutgoingInvitations() - Invalid response (not HTTP)")
            throw VortexError.invalidResponse
        }
        
        print("[VortexSDK] VortexClient.getOutgoingInvitations() - Status code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("[VortexSDK] VortexClient.getOutgoingInvitations() - HTTP error: \(httpResponse.statusCode)")
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("[VortexSDK] VortexClient.getOutgoingInvitations() - Response body: \(responseString)")
        }
        
        let decoder = JSONDecoder()
        let invitationsResponse = try decoder.decode(OutgoingInvitationsResponse.self, from: data)
        print("[VortexSDK] VortexClient.getOutgoingInvitations() - Decoded \(invitationsResponse.data.invitations.count) invitations")
        print("[VortexSDK] VortexClient.getOutgoingInvitations() - Raw invitations data: \(invitationsResponse.data.invitations)")
        return invitationsResponse.data.invitations
    }
    
    /// Revoke (cancel) an outgoing invitation
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - invitationId: ID of the invitation to revoke
    public func revokeInvitation(jwt: String, invitationId: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/invitations/\(invitationId)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        request.setValue(clientVersion, forHTTPHeaderField: "x-vortex-client-version")
        request.setValue(clientName, forHTTPHeaderField: "x-vortex-client-name")
        
        if let attestation = sessionAttestation {
            request.setValue(attestation, forHTTPHeaderField: "x-session-attestation")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VortexError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 204 else {
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Incoming Invitations
    
    /// Fetch incoming (open) invitations for the current user
    /// - Parameter jwt: JWT authentication token
    /// - Returns: List of incoming invitations (only pending, not yet accepted)
    public func getIncomingInvitations(jwt: String) async throws -> [IncomingInvitation] {
        // Note: The API only accepts a single status value, so we fetch without status filter
        // and let the API return all open invitations for the current user
        let url = baseURL.appendingPathComponent("/api/v1/invitations")
        
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
        
        // Debug: Print raw JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[VortexSDK] Raw incoming invitations response: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        let invitationsResponse = try decoder.decode(IncomingInvitationsResponse.self, from: data)
        return invitationsResponse.data.invitations
    }
    
    /// Accept an incoming invitation
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - invitationId: ID of the invitation to accept
    public func acceptIncomingInvitation(jwt: String, invitationId: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/invitations/accept")
        
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
        
        let body: [String: Any] = ["invitationId": invitationId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VortexError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Delete (reject/decline) an incoming invitation
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - invitationId: ID of the invitation to delete
    public func deleteIncomingInvitation(jwt: String, invitationId: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/invitations/\(invitationId)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        request.setValue(clientVersion, forHTTPHeaderField: "x-vortex-client-version")
        request.setValue(clientName, forHTTPHeaderField: "x-vortex-client-name")
        
        if let attestation = sessionAttestation {
            request.setValue(attestation, forHTTPHeaderField: "x-session-attestation")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VortexError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 204 else {
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Deferred Deep Links
    
    /// Match device fingerprint to retrieve deferred deep link context
    ///
    /// This method is used for deferred deep linking. When a user clicks an invitation link
    /// and is redirected to the App Store to install the app, the server stores a fingerprint
    /// of the user's device. After installation, the app can call this method to retrieve
    /// the original invitation context by matching the device fingerprint.
    ///
    /// The account ID is derived from the JWT token, so account-wide matching is performed.
    ///
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - fingerprint: Device fingerprint data collected from the device
    /// - Returns: Match result containing invitation context if a match is found
    public func matchFingerprint(
        jwt: String,
        fingerprint: DeviceFingerprint
    ) async throws -> MatchFingerprintResponse {
        let url = baseURL.appendingPathComponent("/api/v1/deferred-links/match")
        
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
        
        let requestBody = MatchFingerprintRequest(fingerprint: fingerprint)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(requestBody)
        request.httpBody = bodyData
        
        #if DEBUG
        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[VortexSDK] POST /api/v1/deferred-links/match request body:")
            print(bodyString)
        }
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VortexError.invalidResponse
        }
        
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[VortexSDK] Match fingerprint response (status \(httpResponse.statusCode)):")
            print(jsonString)
        }
        #endif
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw VortexError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(MatchFingerprintResponse.self, from: data)
    }
}
