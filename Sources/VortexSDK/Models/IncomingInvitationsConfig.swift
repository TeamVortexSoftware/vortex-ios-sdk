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

/// Configuration for the Incoming Invitations component
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
    
    /// Custom text for the Accept button (default: "Accept")
    public let acceptButtonText: String?
    
    /// Custom text for the Delete button (default: "Delete")
    public let deleteButtonText: String?
    
    /// Custom empty state message (default: "No incoming invitations")
    public let emptyStateMessage: String?
    
    /// Custom title for the Accept confirmation dialog (default: "Accept Invitation")
    public let acceptConfirmTitle: String?
    
    /// Custom message for the Accept confirmation dialog.
    /// Use {name} as a placeholder for the person's name.
    /// (default: "Accept invitation from {name}?")
    public let acceptConfirmMessage: String?
    
    /// Custom title for the Delete confirmation dialog (default: "Delete Invitation")
    public let deleteConfirmTitle: String?
    
    /// Custom message for the Delete confirmation dialog.
    /// Use {name} as a placeholder for the person's name.
    /// (default: "Delete invitation from {name}?")
    public let deleteConfirmMessage: String?
    
    /// Custom text for the confirmation dialog's confirm button (default: "Confirm")
    public let confirmButtonText: String?
    
    /// Custom text for the confirmation dialog's cancel button (default: "Cancel")
    public let cancelButtonText: String?
    
    public init(
        internalInvitations: [IncomingInvitationItem]? = nil,
        onAccept: ((IncomingInvitationItem) async -> Bool)? = nil,
        onDelete: ((IncomingInvitationItem) async -> Bool)? = nil,
        acceptButtonText: String? = nil,
        deleteButtonText: String? = nil,
        emptyStateMessage: String? = nil,
        acceptConfirmTitle: String? = nil,
        acceptConfirmMessage: String? = nil,
        deleteConfirmTitle: String? = nil,
        deleteConfirmMessage: String? = nil,
        confirmButtonText: String? = nil,
        cancelButtonText: String? = nil
    ) {
        self.internalInvitations = internalInvitations
        self.onAccept = onAccept
        self.onDelete = onDelete
        self.acceptButtonText = acceptButtonText
        self.deleteButtonText = deleteButtonText
        self.emptyStateMessage = emptyStateMessage
        self.acceptConfirmTitle = acceptConfirmTitle
        self.acceptConfirmMessage = acceptConfirmMessage
        self.deleteConfirmTitle = deleteConfirmTitle
        self.deleteConfirmMessage = deleteConfirmMessage
        self.confirmButtonText = confirmButtonText
        self.cancelButtonText = cancelButtonText
    }
}
