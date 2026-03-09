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
        let configResponse: WidgetConfigurationResponse
        do {
            configResponse = try decoder.decode(WidgetConfigurationResponse.self, from: data)
        } catch {
            #if DEBUG
            print("[VortexSDK] ❌ Failed to decode widget configuration (\(data.count) bytes)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    print("[VortexSDK]   Type mismatch: expected \(type) at '\(path)' — \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    print("[VortexSDK]   Value not found: expected \(type) at '\(path)' — \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    print("[VortexSDK]   Key '\(key.stringValue)' not found at '\(path)' — \(context.debugDescription)")
                case .dataCorrupted(let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                    print("[VortexSDK]   Data corrupted at '\(path)' — \(context.debugDescription)")
                @unknown default:
                    print("[VortexSDK]   \(error)")
                }
            } else {
                print("[VortexSDK]   \(error)")
            }
            #endif
            throw error
        }
        
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
        metadata: [String: Any]? = nil,
        subtype: String? = nil
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
        
        if let subtype = subtype {
            body["subtype"] = subtype
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
        let invitationsResponse = try decoder.decode(OutgoingInvitationsResponse.self, from: data)
        return invitationsResponse.data.invitations
    }
    
    /// Revokes (deactivates) an invitation.
    ///
    /// This works for any invitation where the authenticated user is either the creator
    /// or a target. The invitation is marked as deactivated and will no longer be active.
    ///
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - invitationId: The ID of the invitation to revoke
    /// - Throws: ``VortexError/httpError(statusCode:)`` if the request fails
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
    
    /// Retrieves details of a specific invitation by its ID.
    ///
    /// Use this method to fetch the full details of any invitation, including its targets,
    /// groups, acceptance records, and metadata.
    ///
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - invitationId: The ID of the invitation to retrieve
    /// - Returns: The full invitation details
    /// - Throws: ``VortexError/httpError(statusCode:)`` if the request fails or invitation is not found
    public func getInvitation(jwt: String, invitationId: String) async throws -> Invitation {
        let url = baseURL.appendingPathComponent("/api/v1/invitations/\(invitationId)")
        
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
        
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[VortexSDK] getInvitation raw response: \(jsonString)")
        }
        #endif
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Invitation.self, from: data)
        } catch {
            #if DEBUG
            print("[VortexSDK] getInvitation decoding error: \(error)")
            #endif
            throw error
        }
    }
    
    // MARK: - Incoming Invitations
    
    /// Fetches incoming (open) invitations for the current user.
    ///
    /// Returns only pending invitations that have not yet been accepted.
    ///
    /// - Parameter jwt: JWT authentication token
    /// - Returns: List of incoming invitations
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
        
        let decoder = JSONDecoder()
        let invitationsResponse = try decoder.decode(IncomingInvitationsResponse.self, from: data)
        return invitationsResponse.data.invitations
    }
    
    /// Accepts an incoming invitation that the user has received.
    ///
    /// Once accepted, the invitation status will be updated and the acceptance
    /// will be recorded.
    ///
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - invitationId: The ID of the invitation to accept
    /// - Throws: ``VortexError/httpError(statusCode:)`` if the request fails
    public func acceptInvitation(jwt: String, invitationId: String) async throws {
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
    
    /// Deletes (rejects/declines) an incoming invitation.
    ///
    /// This removes the invitation from the user's incoming list.
    ///
    /// - Parameters:
    ///   - jwt: JWT authentication token
    ///   - invitationId: The ID of the invitation to delete
    /// - Throws: ``VortexError/httpError(statusCode:)`` if the request fails
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
