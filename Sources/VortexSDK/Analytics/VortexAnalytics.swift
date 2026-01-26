import Foundation

// MARK: - Analytics Event

/// Represents a telemetry event that can be tracked by the Vortex SDK.
///
/// Events are emitted during user interactions with the invitation widget and can be
/// consumed via the `onEvent` callback. This enables integration with external analytics
/// services and custom event handling.
///
/// Example usage:
/// ```swift
/// VortexInviteView(
///     componentId: "your-component-id",
///     jwt: userJWT,
///     onEvent: { event in
///         print("Event: \(event.name)")
///         // Forward to your analytics service
///     }
/// )
/// ```
public struct VortexAnalyticsEvent: Codable, Sendable {
    
    /// The name of the event (e.g., "invite_formRender_succeeded", "email_fieldSubmission_succeeded")
    public let name: String
    
    /// The widget configuration ID associated with this event
    public let widgetConfigurationId: String?
    
    /// The deployment ID for this event
    public let deploymentId: String?
    
    /// The environment ID for this event
    public let environmentId: String?
    
    /// The platform on which the event occurred (always "ios" for this SDK)
    public let platform: String
    
    /// The timestamp when the event occurred
    public let timestamp: Date
    
    /// The session ID for this widget session
    public let sessionId: String?
    
    /// The user agent string (iOS device info)
    public let useragent: String?
    
    /// The foreign user ID (user ID in your system, extracted from JWT)
    public let foreignUserId: String?
    
    /// Optional segmentation data for analytics filtering
    public let segmentation: [String: JSONValue]?
    
    /// Optional event-specific payload containing additional context
    public let payload: [String: JSONValue]?
    
    /// Optional groups associated with this event
    public let groups: [GroupInfo]?
    
    /// Creates a new analytics event.
    /// - Parameters:
    ///   - name: The event name
    ///   - widgetConfigurationId: The widget configuration ID
    ///   - deploymentId: The deployment ID
    ///   - environmentId: The environment ID
    ///   - platform: The platform (defaults to "ios")
    ///   - timestamp: The event timestamp (defaults to now)
    ///   - sessionId: The session ID
    ///   - useragent: The user agent string
    ///   - foreignUserId: The foreign user ID from your system
    ///   - segmentation: Optional segmentation data
    ///   - payload: Optional event payload
    ///   - groups: Optional group information
    public init(
        name: String,
        widgetConfigurationId: String? = nil,
        deploymentId: String? = nil,
        environmentId: String? = nil,
        platform: String = "ios",
        timestamp: Date = Date(),
        sessionId: String? = nil,
        useragent: String? = nil,
        foreignUserId: String? = nil,
        segmentation: [String: JSONValue]? = nil,
        payload: [String: JSONValue]? = nil,
        groups: [GroupInfo]? = nil
    ) {
        self.name = name
        self.widgetConfigurationId = widgetConfigurationId
        self.deploymentId = deploymentId
        self.environmentId = environmentId
        self.platform = platform
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.useragent = useragent
        self.foreignUserId = foreignUserId
        self.segmentation = segmentation
        self.payload = payload
        self.groups = groups
    }
}

// MARK: - Group Info

extension VortexAnalyticsEvent {
    
    /// Group information for analytics events.
    ///
    /// Groups allow you to associate events with specific organizational units
    /// in your system (e.g., teams, organizations, workspaces).
    public struct GroupInfo: Codable, Sendable, Equatable {
        /// The type of group (e.g., "team", "organization")
        public let type: String
        
        /// The unique identifier for the group
        public let id: String
        
        /// The display name of the group
        public let name: String
        
        /// Creates a new group info instance.
        /// - Parameters:
        ///   - type: The group type
        ///   - id: The group identifier
        ///   - name: The group display name
        public init(type: String, id: String, name: String) {
            self.type = type
            self.id = id
            self.name = name
        }
    }
}

// MARK: - Event Names

/// Standard event names emitted by the Vortex SDK.
///
/// These events are available via the `onEvent` callback and can be used
/// to track user interactions with the invitation widget.
///
/// Event names follow the `object_action` naming convention for consistency
/// across all Vortex SDKs and platforms.
public enum VortexEventName: String, CaseIterable, Sendable {

    // MARK: - Invite Form Events

    /// Emitted when the invite form is rendered successfully.
    case inviteFormRenderSucceeded = "invite_formRender_succeeded"

    /// Emitted when there's an error rendering the invite form.
    case inviteFormRenderFailed = "invite_formRender_failed"

    // MARK: - Email Field Events

    /// Emitted when the email field receives focus.
    case emailFieldFocussed = "email_field_focussed"

    /// Emitted when the email field loses focus.
    case emailFieldBlurred = "email_field_blurred"

    /// Emitted when email validation occurs.
    case emailSubmissionValidated = "email_submission_validated"

    /// Emitted when email invitations are submitted successfully.
    case emailFieldSubmissionSucceeded = "email_fieldSubmission_succeeded"

    /// Emitted when there's an error submitting the email form.
    case emailFieldSubmissionFailed = "email_fieldSubmission_failed"

    // MARK: - Sharing Events

    /// Emitted when a sharing destination button is clicked.
    case sharingDestinationButtonClicked = "sharingDestination_button_clicked"

    // MARK: - Inbound Invitation Events (requested by Mixerbox)

    /// Emitted when accept button is clicked on an inbound invitation.
    case inboundInvitationAcceptClicked = "inboundInvitationAccept_button_clicked"

    /// Emitted when delete button is clicked on an inbound invitation.
    case inboundInvitationDeleteClicked = "inboundInvitationDelete_button_clicked"

    // MARK: - Outbound Invitation Events (requested by Mixerbox)

    /// Emitted when delete button is clicked on an outbound invitation.
    case outboundInvitationDeleteClicked = "outboundInvitationDelete_button_clicked"

    // MARK: - People You May Know (PYMK) Events (requested by Mixerbox)

    /// Emitted when invite button is clicked on a PYMK suggestion.
    case pymkInviteClicked = "pymkInvite_button_clicked"

    /// Emitted when delete button is clicked on a PYMK suggestion.
    case pymkDeleteClicked = "pymkDelete_button_clicked"

    // MARK: - Find Friends Events (requested by Mixerbox)

    /// Emitted when invite button is clicked in Find Friends.
    case findFriendsInviteClicked = "findFriendsInvite_button_clicked"

    // MARK: - Widget Lifecycle Events

    /// Emitted when widget configuration is loaded.
    case widgetConfigurationLoaded = "widget_configuration_loaded"
}

// MARK: - JSON Value

/// A type-safe, Sendable-conforming JSON value representation.
///
/// This enum provides a safe way to encode arbitrary JSON-compatible values
/// while maintaining Swift's strict concurrency requirements.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    
    /// Creates a JSONValue from any supported type.
    /// - Parameter value: The value to convert
    /// - Returns: A JSONValue representation, or nil if the type is not supported
    public static func from(_ value: Any) -> JSONValue {
        switch value {
        case is NSNull:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map { JSONValue.from($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { JSONValue.from($0) })
        default:
            // Convert unknown types to string representation
            return .string(String(describing: value))
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode JSONValue"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Analytics Client

/// Client for sending analytics events to the Vortex backend.
///
/// This client handles the network communication for tracking events.
/// Events are sent asynchronously and failures are handled silently
/// to ensure analytics never impact the user experience.
@MainActor
public final class VortexAnalyticsClient {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let sessionId: String
    private var jwt: String?
    private let urlSession: URLSession
    
    // MARK: - Initialization
    
    /// Creates a new analytics client.
    /// - Parameters:
    ///   - baseURL: Base URL of the Vortex API
    ///   - sessionId: Unique session identifier
    ///   - jwt: JWT authentication token (optional)
    ///   - urlSession: URLSession to use for requests (defaults to shared)
    public init(
        baseURL: URL,
        sessionId: String,
        jwt: String?,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.sessionId = sessionId
        self.jwt = jwt
        self.urlSession = urlSession
    }
    
    // MARK: - Public Methods
    
    /// Updates the JWT token used for authentication.
    /// - Parameter jwt: The new JWT token
    public func updateJWT(_ jwt: String?) {
        self.jwt = jwt
    }
    
    /// Tracks an analytics event by sending it to the backend.
    ///
    /// This method is fire-and-forget; it does not wait for a response
    /// and silently handles any errors to avoid impacting the user experience.
    ///
    /// - Parameter event: The event to track
    public func track(_ event: VortexAnalyticsEvent) async {
        guard let jwt = jwt else {
            #if DEBUG
            print("[VortexSDK] Analytics: Skipping event '\(event.name)' - no JWT token")
            #endif
            return
        }
        
        let url = baseURL.appendingPathComponent("api/v1/events")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        request.setValue("VortexSDK-iOS", forHTTPHeaderField: "x-vortex-client-name")
        
        do {
            let encoder = JSONEncoder()
            // Use default camelCase keys - the analytics API expects camelCase
            encoder.dateEncodingStrategy = .secondsSince1970
            request.httpBody = try encoder.encode(event)
            
            #if DEBUG
            print("[VortexSDK] Analytics: Tracking event '\(event.name)'")
            #endif
            
            // Fire and forget - capture urlSession for use in detached task
            let session = self.urlSession
            Task.detached(priority: .utility) {
                _ = try? await session.data(for: request)
            }
        } catch {
            #if DEBUG
            print("[VortexSDK] Analytics: Failed to encode event '\(event.name)': \(error)")
            #endif
        }
    }
}

// MARK: - Event Handler Protocol

/// Protocol for handling Vortex analytics events.
///
/// Implement this protocol to receive analytics events from the SDK
/// and forward them to your own analytics infrastructure.
///
/// Example:
/// ```swift
/// class MyAnalyticsHandler: VortexEventHandler {
///     func onEvent(_ event: VortexAnalyticsEvent) {
///         // Forward to your analytics service
///         MyAnalytics.track(event.name, properties: event.payload)
///     }
/// }
/// ```
public protocol VortexEventHandler: AnyObject, Sendable {
    /// Called when an analytics event is triggered.
    /// - Parameter event: The analytics event that occurred
    func onEvent(_ event: VortexAnalyticsEvent)
}

// MARK: - Convenience Extensions

extension Dictionary where Key == String, Value == Any {
    /// Converts a dictionary of Any values to JSONValue for safe encoding.
    func toJSONValues() -> [String: JSONValue] {
        mapValues { JSONValue.from($0) }
    }
}

// MARK: - Device Info

import UIKit

/// Helper for generating device information for analytics.
public enum VortexDeviceInfo {
    
    /// Generates a user agent string for the current iOS device.
    ///
    /// Format: `VortexSDK-iOS/1.0.0 (iOS <version>; <model>)`
    /// Example: `VortexSDK-iOS/1.0.0 (iOS 17.0; iPhone14,2)`
    public static var useragent: String {
        let osVersion = UIDevice.current.systemVersion
        let model = deviceModel
        let sdkVersion = VortexSDKInfo.version
        return "VortexSDK-iOS/\(sdkVersion) (iOS \(osVersion); \(model))"
    }
    
    /// Returns the device model identifier (e.g., "iPhone14,2", "iPad13,4")
    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - JWT Parsing

/// Helper for extracting information from JWT tokens.
public enum VortexJWTParser {
    
    /// Extracts the foreign user ID from a JWT token.
    ///
    /// The function looks for common user ID claims in the following order:
    /// 1. `userId` - Vortex's standard claim
    /// 2. `sub` - Standard JWT subject claim
    /// 3. `user_id` - Alternative format
    ///
    /// - Parameter jwt: The JWT token string
    /// - Returns: The user ID if found, nil otherwise
    public static func extractForeignUserId(from jwt: String?) -> String? {
        guard let jwt = jwt else { return nil }
        
        // Handle raw-data format (insecure JWT for development)
        if jwt.hasPrefix("raw-data:") {
            let base64Part = String(jwt.dropFirst("raw-data:".count))
            guard let data = Data(base64Encoded: base64Part),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return json["userId"] as? String ?? json["user_id"] as? String
        }
        
        // Standard JWT format: header.payload.signature
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        
        // Decode the payload (second part)
        var base64 = String(parts[1])
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        // Replace URL-safe characters
        base64 = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Try common user ID claims
        if let userId = json["userId"] as? String {
            return userId
        }
        if let sub = json["sub"] as? String {
            return sub
        }
        if let userId = json["user_id"] as? String {
            return userId
        }
        
        return nil
    }
}
