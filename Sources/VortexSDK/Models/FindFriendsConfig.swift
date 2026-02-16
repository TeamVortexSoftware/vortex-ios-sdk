import Foundation

// MARK: - Find Friends Types

/// A contact in the Find Friends list.
/// Provided by the customer via findFriendsConfig.contacts.
public struct FindFriendsContact: Identifiable, Sendable {
    /// The user ID that identifies this contact in the customer's platform
    public let userId: String
    /// Display name of the contact
    public let name: String
    /// Optional subtitle (e.g., username, email, or app-specific info)
    public let subtitle: String?
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    /// Optional metadata for app-specific data
    public let metadata: [String: Any]?
    
    /// Identifiable conformance - uses userId
    public var id: String { userId }
    
    public init(
        userId: String,
        name: String,
        subtitle: String? = nil,
        avatarUrl: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.userId = userId
        self.name = name
        self.subtitle = subtitle
        self.avatarUrl = avatarUrl
        self.metadata = metadata
    }
}

/// Configuration for the Find Friends feature.
/// Passed to VortexInviteView to enable and configure the Find Friends component.
///
/// The customer provides a list of contacts with user IDs. When the user taps "Connect",
/// the SDK creates an invitation via the Vortex backend.
public struct FindFriendsConfig {
    /// List of contacts to display.
    /// Each contact must have a userId that identifies them in the customer's platform.
    public let contacts: [FindFriendsContact]
    
    /// Optional: Called after an invitation is successfully created.
    /// Use this to trigger in-app notifications or update your UI.
    public let onInvitationCreated: ((FindFriendsContact) -> Void)?
    
    public init(
        contacts: [FindFriendsContact],
        onInvitationCreated: ((FindFriendsContact) -> Void)? = nil
    ) {
        self.contacts = contacts
        self.onInvitationCreated = onInvitationCreated
    }
}
