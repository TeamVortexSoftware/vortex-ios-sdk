import Foundation

/// Represents an incoming invitation item
public struct IncomingInvitationItem: Identifiable, Sendable {
    /// Unique identifier for the invitation
    public let id: String
    /// Display name of the sender
    public let name: String
    /// Optional subtitle (email, userId, or app-specific info)
    public let subtitle: String?
    /// Avatar/profile image URL (optional)
    public let avatarUrl: String?
    /// Whether this invitation was fetched from the Vortex API (vs provided internally)
    public let isFromVortexAPI: Bool
    /// Optional metadata for app-specific data
    public let metadata: [String: Any]?
    
    public init(
        id: String,
        name: String,
        subtitle: String? = nil,
        avatarUrl: String? = nil,
        isFromVortexAPI: Bool = false,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.avatarUrl = avatarUrl
        self.isFromVortexAPI = isFromVortexAPI
        self.metadata = metadata
    }
}

/// Configuration for the Incoming Invitations component.
///
/// Note: UI strings (button text, empty state message, confirmation dialogs) are configured
/// via the widget configuration in the Vortex dashboard, not through this config object.
public struct IncomingInvitationsConfig {
    /// Internal invitations provided by the app (merged with API-fetched ones)
    public let internalInvitations: [IncomingInvitationItem]?
    
    /// Called when user confirms "Accept" on an invitation.
    /// Return true to proceed with API call (for Vortex API invitations).
    /// Return false to cancel the action.
    public let onAccept: ((IncomingInvitationItem) async -> Bool)?
    
    /// Called when user confirms "Delete" on an invitation.
    /// Return true to proceed with API call (for Vortex API invitations).
    /// Return false to cancel the action.
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
