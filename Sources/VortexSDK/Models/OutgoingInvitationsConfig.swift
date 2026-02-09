import Foundation

/// Represents an outgoing invitation item.
///
/// Use the `isVortexInvitation` property to determine the source of the invitation:
/// - `true`: The invitation was fetched from the Vortex API
/// - `false`: The invitation was provided by your app via `internalInvitations`
public struct OutgoingInvitationItem: Identifiable, Sendable {
    /// Unique identifier for the invitation
    public let id: String
    /// Display name of the invitee
    public let name: String
    /// Optional subtitle (user ID, email, phone, or app-specific info)
    public let subtitle: String?
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    /// Indicates the source of this invitation.
    /// - `true`: Fetched from the Vortex API (Vortex will handle cancel API calls)
    /// - `false`: Provided by your app via `internalInvitations` (your app must handle the action)
    public let isVortexInvitation: Bool
    /// Optional metadata for app-specific data
    public let metadata: [String: Any]?
    
    public init(
        id: String,
        name: String,
        subtitle: String? = nil,
        avatarUrl: String? = nil,
        isVortexInvitation: Bool = false,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.avatarUrl = avatarUrl
        self.isVortexInvitation = isVortexInvitation
        self.metadata = metadata
    }
}

/// Configuration for the Outgoing Invitations component.
///
/// Note: UI strings (button text, confirmation dialogs) are configured
/// via the widget configuration in the Vortex dashboard, not through this config object.
public struct OutgoingInvitationsConfig {
    /// Internal invitations provided by the app (merged with API-fetched ones).
    /// These invitations will have `isVortexInvitation = false`.
    public let internalInvitations: [OutgoingInvitationItem]?
    
    /// Called when user taps "Cancel" on an invitation.
    ///
    /// Use `invitation.isVortexInvitation` to determine the source:
    /// - For Vortex invitations (`isVortexInvitation == true`): Return `true` to let the SDK
    ///   call the Vortex API to revoke the invitation, or `false` to cancel the action.
    /// - For internal/app invitations (`isVortexInvitation == false`): Handle the cancel logic
    ///   in your callback, then return `false` since no Vortex API call is needed.
    ///
    /// If the callback returns `true`, the invitation will be removed from the list.
    /// If not provided, the SDK will proceed with the API call for Vortex invitations.
    public let onCancel: ((OutgoingInvitationItem) async -> Bool)?
    
    public init(
        internalInvitations: [OutgoingInvitationItem]? = nil,
        onCancel: ((OutgoingInvitationItem) async -> Bool)? = nil
    ) {
        self.internalInvitations = internalInvitations
        self.onCancel = onCancel
    }
}
