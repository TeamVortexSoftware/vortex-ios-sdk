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
    
    public init(
        contacts: [InviteContactsContact]
    ) {
        self.contacts = contacts
    }
}
