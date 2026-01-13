import Foundation

// MARK: - Find Friends Types

/// Raw contact as fetched by the SDK from device or Google contacts.
/// This is passed to the platform's onClassifyContacts callback for classification.
public struct FindFriendsRawContact: Identifiable, Sendable {
    /// Unique identifier for the contact
    public let id: String
    /// Display name of the contact
    public let name: String
    /// Email addresses associated with this contact
    public let emails: [String]
    /// Phone numbers associated with this contact (optional)
    public let phones: [String]?
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    
    public init(
        id: String,
        name: String,
        emails: [String],
        phones: [String]? = nil,
        avatarUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.emails = emails
        self.phones = phones
        self.avatarUrl = avatarUrl
    }
}

/// Classification status for a contact
public enum FindFriendsContactStatus: String, Sendable {
    /// Contact is already a member of the platform (show "Connect" button)
    case member
    /// Contact is not a member (show "Invite" button)
    case nonMember = "non-member"
}

/// Contact after classification by the host platform.
/// Extends RawContact with membership status and optional platform-specific data.
public struct FindFriendsClassifiedContact: Identifiable, Sendable {
    /// Unique identifier for the contact
    public let id: String
    /// Display name of the contact
    public let name: String
    /// Email addresses associated with this contact
    public let emails: [String]
    /// Phone numbers associated with this contact (optional)
    public let phones: [String]?
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    /// Classification status: member or non-member
    public let status: FindFriendsContactStatus
    /// Platform-specific user ID if the contact is a member.
    /// Useful for the onConnect callback to know which user to connect with.
    public let platformUserId: String?
    /// Optional platform-specific metadata.
    /// Can be used to pass additional data like mutual connections, last active, etc.
    public let metadata: [String: Any]?
    
    public init(
        id: String,
        name: String,
        emails: [String],
        phones: [String]? = nil,
        avatarUrl: String? = nil,
        status: FindFriendsContactStatus,
        platformUserId: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.emails = emails
        self.phones = phones
        self.avatarUrl = avatarUrl
        self.status = status
        self.platformUserId = platformUserId
        self.metadata = metadata
    }
    
    /// Create a classified contact from a raw contact
    public init(
        from rawContact: FindFriendsRawContact,
        status: FindFriendsContactStatus,
        platformUserId: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = rawContact.id
        self.name = rawContact.name
        self.emails = rawContact.emails
        self.phones = rawContact.phones
        self.avatarUrl = rawContact.avatarUrl
        self.status = status
        self.platformUserId = platformUserId
        self.metadata = metadata
    }
}

/// Configuration for the Find Friends feature.
/// Passed to VortexInviteView to enable and configure the Find Friends component.
///
/// There are two ways to provide contacts:
/// 1. **Callback approach**: Provide `onClassifyContacts` callback. The SDK fetches
///    contacts and calls this callback for classification.
/// 2. **Props approach**: Provide `classifiedContacts` directly. The SDK skips
///    fetching and uses these contacts immediately. This is useful for:
///    - Pre-fetching contacts in the background before rendering the form
///    - Preview/edit modes where instant rendering is needed
///    - Cases where the app already has classified contacts available
public struct FindFriendsConfig {
    /// Pre-classified contacts to display immediately.
    /// When provided, the SDK skips fetching contacts and uses these directly.
    /// This enables instant rendering without loading states.
    public let classifiedContacts: [FindFriendsClassifiedContact]?
    
    /// Called by the SDK after fetching contacts from device or Google.
    /// The platform should call their server to classify which contacts
    /// are existing members vs non-members.
    ///
    /// This callback is only used if `classifiedContacts` is not provided.
    public let onClassifyContacts: (([FindFriendsRawContact]) async throws -> [FindFriendsClassifiedContact])?
    
    /// Called when user taps "Connect" on a member contact.
    /// The platform should handle the connection logic (e.g., send friend request).
    public let onConnect: (FindFriendsClassifiedContact) async -> Void
    
    /// Called when user taps "Invite" on a non-member contact.
    /// The platform can handle custom invitation logic, or let the SDK
    /// handle it via the standard invitation flow.
    ///
    /// If not provided, the SDK will use its built-in invitation mechanism.
    public let onInvite: ((FindFriendsClassifiedContact) async -> Void)?
    
    /// Optional: Custom text for the "Connect" button.
    /// Default: "Connect"
    public let connectButtonText: String
    
    /// Optional: Custom text for the "Invite" button.
    /// Default: "Invite"
    public let inviteButtonText: String
    
    /// Optional: Custom empty state message when no contacts are found.
    /// Default: "No contacts found"
    public let emptyStateMessage: String
    
    /// Optional: Custom loading message while classifying contacts.
    /// Default: "Finding friends..."
    public let loadingMessage: String
    
    /// Optional: Custom text for the "Invite your contacts" entry that leads to non-members list.
    /// Default: "Invite your contacts"
    public let inviteContactsEntryText: String
    
    /// Optional: Called when user navigates to the non-members list.
    /// Can be used for analytics or custom navigation handling.
    public let onNavigateToInviteContacts: (() -> Void)?
    
    /// Optional: Called when user navigates back from the non-members list.
    /// Can be used for analytics or custom navigation handling.
    public let onNavigateBackFromInviteContacts: (() -> Void)?
    
    public init(
        classifiedContacts: [FindFriendsClassifiedContact]? = nil,
        onClassifyContacts: (([FindFriendsRawContact]) async throws -> [FindFriendsClassifiedContact])? = nil,
        onConnect: @escaping (FindFriendsClassifiedContact) async -> Void,
        onInvite: ((FindFriendsClassifiedContact) async -> Void)? = nil,
        connectButtonText: String = "Connect",
        inviteButtonText: String = "Invite",
        emptyStateMessage: String = "No contacts found",
        loadingMessage: String = "Finding friends...",
        inviteContactsEntryText: String = "Invite your contacts",
        onNavigateToInviteContacts: (() -> Void)? = nil,
        onNavigateBackFromInviteContacts: (() -> Void)? = nil
    ) {
        self.classifiedContacts = classifiedContacts
        self.onClassifyContacts = onClassifyContacts
        self.onConnect = onConnect
        self.onInvite = onInvite
        self.connectButtonText = connectButtonText
        self.inviteButtonText = inviteButtonText
        self.emptyStateMessage = emptyStateMessage
        self.loadingMessage = loadingMessage
        self.inviteContactsEntryText = inviteContactsEntryText
        self.onNavigateToInviteContacts = onNavigateToInviteContacts
        self.onNavigateBackFromInviteContacts = onNavigateBackFromInviteContacts
    }
}
