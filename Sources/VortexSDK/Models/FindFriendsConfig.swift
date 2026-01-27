import Foundation

// MARK: - Find Friends Types

/// A contact in the Find Friends list.
/// Provided by the customer via findFriendsConfig.contacts.
public struct FindFriendsContact: Identifiable, Sendable {
    /// Internal ID of the contact in the customer's platform
    public let internalId: String
    /// Display name of the contact
    public let name: String
    /// Optional subtitle (e.g., username, email, or app-specific info)
    public let subtitle: String?
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    /// Optional metadata for app-specific data
    public let metadata: [String: Any]?
    
    /// Identifiable conformance - uses internalId
    public var id: String { internalId }
    
    public init(
        internalId: String,
        name: String,
        subtitle: String? = nil,
        avatarUrl: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.internalId = internalId
        self.name = name
        self.subtitle = subtitle
        self.avatarUrl = avatarUrl
        self.metadata = metadata
    }
}

/// Configuration for the Find Friends feature.
/// Passed to VortexInviteView to enable and configure the Find Friends component.
///
/// The customer provides a list of contacts with internal IDs. When the user taps "Connect",
/// the SDK calls the onConnect callback. If it returns true, an invitation with
/// target type = internalId is created via the Vortex backend.
public struct FindFriendsConfig {
    /// List of contacts to display.
    /// Each contact must have an internalId that identifies them in the customer's platform.
    public let contacts: [FindFriendsContact]
    
    /// Called when user taps "Connect" on a contact.
    /// The customer implements this callback to perform any pre-connection logic.
    ///
    /// If the callback returns true, the SDK will create an invitation via the
    /// Vortex backend with target type = internalId.
    ///
    /// If the callback returns false, no invitation is created.
    public let onConnect: (FindFriendsContact) async -> Bool
    
    /// Optional: Called after an invitation is successfully created.
    /// Use this to update your UI or local state.
    public let onInvitationCreated: ((FindFriendsContact) -> Void)?
    
    /// Optional: Called if creating the invitation fails.
    public let onInvitationFailed: ((FindFriendsContact, Error) -> Void)?
    
    /// Optional: Custom text for the "Connect" button.
    /// Default: "Connect"
    public let connectButtonText: String
    
    /// Optional: Custom empty state message when no contacts are found.
    /// Default: "No contacts found"
    public let emptyStateMessage: String
    
    public init(
        contacts: [FindFriendsContact],
        onConnect: @escaping (FindFriendsContact) async -> Bool,
        onInvitationCreated: ((FindFriendsContact) -> Void)? = nil,
        onInvitationFailed: ((FindFriendsContact, Error) -> Void)? = nil,
        connectButtonText: String = "Connect",
        emptyStateMessage: String = "No contacts found"
    ) {
        self.contacts = contacts
        self.onConnect = onConnect
        self.onInvitationCreated = onInvitationCreated
        self.onInvitationFailed = onInvitationFailed
        self.connectButtonText = connectButtonText
        self.emptyStateMessage = emptyStateMessage
    }
}
