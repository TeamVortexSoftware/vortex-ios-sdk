import Foundation

// MARK: - Invite Contacts Types

/// Contact to be displayed in the Invite Contacts component.
/// Each contact has a name and phone number for SMS invitation.
public struct InviteContactsContact: Identifiable, Sendable {
    /// Unique identifier for the contact (auto-generated if not provided)
    public let id: String
    /// Display name of the contact
    public let name: String
    /// Phone number for SMS invitation
    public let phoneNumber: String
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    /// Optional metadata for the contact
    public let metadata: [String: Any]?
    
    /// Creates a contact with all properties including a custom ID.
    public init(
        id: String,
        name: String,
        phoneNumber: String,
        avatarUrl: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.avatarUrl = avatarUrl
        self.metadata = metadata
    }
    
    /// Creates a contact with just name and phone number.
    /// The ID is auto-generated from name and phone number.
    public init(
        name: String,
        phoneNumber: String,
        avatarUrl: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = "\(name)|\(phoneNumber)"
        self.name = name
        self.phoneNumber = phoneNumber
        self.avatarUrl = avatarUrl
        self.metadata = metadata
    }
}

/// Configuration for the Invite Contacts feature.
/// Passed to VortexInviteView via the inviteContactsConfig prop.
///
/// The Invite Contacts component displays a list of contacts that can be invited via SMS.
/// Unlike Find Friends, this component:
/// - Receives pre-classified contacts directly (no fetching/classification)
/// - Only shows contacts that can be invited (no member/non-member distinction)
/// - Creates SMS invitations and opens the SMS app for the user to send
///
/// The component renders nothing (no height) if the contacts list is empty.
///
/// Text values (button labels, empty state message, etc.) come from the widget configuration
/// via `block.settings.customizations`. Do not pass them here.
public struct InviteContactsConfig {
    /// List of contacts to display for SMS invitation.
    /// If empty or undefined, the component renders nothing (no height).
    public let contacts: [InviteContactsContact]
    
    /// Called when the user successfully sends an SMS invitation.
    ///
    /// On real devices with in-app SMS composer (`MFMessageComposeViewController`),
    /// this callback is only called when the user actually taps "Send" in the composer.
    /// If the user cancels or the message fails to send, this callback is NOT called.
    ///
    /// On real devices without SMS capability (fallback to URL scheme), this callback
    /// is called optimistically when the Messages app is opened, since we cannot detect
    /// whether the user actually sent the message.
    ///
    /// On the iOS Simulator (fake SMS preview), this callback is called when the user
    /// taps "Send" in the simulated composer.
    ///
    /// Use cases:
    /// - Analytics tracking
    /// - Refreshing other components (like Outgoing Invitations)
    /// - Custom post-invite logic
    ///
    /// - Parameters:
    ///   - contact: The contact that was invited
    ///   - shortLink: The invitation short link that was created
    public let onInvitationSent: ((InviteContactsContact, String) -> Void)?
    
    /// Optional: Called when user navigates to the contacts list.
    /// Can be used for analytics.
    public let onNavigateToContacts: (() -> Void)?
    
    /// Optional: Called when user navigates back from the contacts list.
    /// Can be used for analytics.
    public let onNavigateBack: (() -> Void)?
    
    public init(
        contacts: [InviteContactsContact],
        onInvitationSent: ((InviteContactsContact, String) -> Void)? = nil,
        onNavigateToContacts: (() -> Void)? = nil,
        onNavigateBack: (() -> Void)? = nil
    ) {
        self.contacts = contacts
        self.onInvitationSent = onInvitationSent
        self.onNavigateToContacts = onNavigateToContacts
        self.onNavigateBack = onNavigateBack
    }
}
