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
    /// Optional email address for the contact.
    /// When provided, the backend creates an additional email target alongside the internal target,
    /// enabling email-based invitation reminders.
    public let email: String?
    /// Optional metadata for app-specific data
    public let metadata: [String: Any]?
    
    /// Identifiable conformance - uses userId
    public var id: String { userId }
    
    public init(
        userId: String,
        name: String,
        subtitle: String? = nil,
        avatarUrl: String? = nil,
        email: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.userId = userId
        self.name = name
        self.subtitle = subtitle
        self.avatarUrl = avatarUrl
        self.email = email
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
    
    /// Optional: Maximum number of contacts to display at once.
    /// If the total contacts exceed this number, a random subset of this size is displayed
    /// in alphabetical order. When a contact is removed, it is replaced with another from
    /// the remaining pool until the pool is exhausted.
    /// If nil, all contacts are displayed.
    public let maxDisplayCount: Int?
    
    /// Optional: Called after an invitation is successfully created.
    /// Use this to trigger in-app notifications or update your UI.
    public let onInvitationCreated: ((FindFriendsContact) -> Void)?
    
    public init(
        contacts: [FindFriendsContact],
        maxDisplayCount: Int? = nil,
        onInvitationCreated: ((FindFriendsContact) -> Void)? = nil
    ) {
        self.contacts = contacts
        self.maxDisplayCount = maxDisplayCount
        self.onInvitationCreated = onInvitationCreated
    }
}
