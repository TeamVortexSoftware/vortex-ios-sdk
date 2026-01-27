import Foundation

/// Represents an incoming invitation item.
///
/// Use the `isVortexInvitation` property to determine the source of the invitation:
/// - `true`: The invitation was fetched from the Vortex API
/// - `false`: The invitation was provided by your app via `internalInvitations`
public struct IncomingInvitationItem: Identifiable, Sendable {
    /// Unique identifier for the invitation
    public let id: String
    /// Display name of the sender
    public let name: String
    /// Optional subtitle (email, userId, or app-specific info)
    public let subtitle: String?
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    /// Indicates the source of this invitation.
    /// - `true`: Fetched from the Vortex API (Vortex will handle accept/delete API calls)
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

/// Configuration for the Incoming Invitations component.
///
/// Note: UI strings (button text, empty state message, confirmation dialogs) are configured
/// via the widget configuration in the Vortex dashboard, not through this config object.
public struct IncomingInvitationsConfig {
    /// Internal invitations provided by the app (merged with API-fetched ones).
    /// These invitations will have `isVortexInvitation = false`.
    public let internalInvitations: [IncomingInvitationItem]?
    
    /// Called when user taps "Accept" on an invitation.
    ///
    /// Use `invitation.isVortexInvitation` to determine the source:
    /// - For Vortex invitations (`isVortexInvitation == true`): Return `true` to let the SDK
    ///   call the Vortex API to mark the invitation as accepted, or `false` to cancel.
    /// - For internal/app invitations (`isVortexInvitation == false`): Handle the accept logic
    ///   in your callback, then return `false` since no Vortex API call is needed.
    ///
    /// If the callback returns `true`, the invitation will be removed from the list.
    /// If not provided, the SDK will proceed with the API call for Vortex invitations.
    public let onAccept: ((IncomingInvitationItem) async -> Bool)?
    
    /// Called when user taps "Delete" on an invitation.
    ///
    /// Use `invitation.isVortexInvitation` to determine the source:
    /// - For Vortex invitations (`isVortexInvitation == true`): Return `true` to let the SDK
    ///   call the Vortex API to delete the invitation, or `false` to cancel.
    /// - For internal/app invitations (`isVortexInvitation == false`): Handle the delete logic
    ///   in your callback, then return `false` since no Vortex API call is needed.
    ///
    /// If the callback returns `true`, the invitation will be removed from the list.
    /// If not provided, the SDK will proceed with the API call for Vortex invitations.
    public let onDelete: ((IncomingInvitationItem) async -> Bool)?
    
    public init(
        internalInvitations: [IncomingInvitationItem]? = nil,
        onAccept: ((IncomingInvitationItem) async -> Bool)? = nil,
        onDelete: ((IncomingInvitationItem) async -> Bool)? = nil
    ) {
        self.internalInvitations = internalInvitations
        self.onAccept = onAccept
        self.onDelete = onDelete
    }
}
