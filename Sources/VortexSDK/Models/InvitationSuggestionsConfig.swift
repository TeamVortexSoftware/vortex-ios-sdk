import Foundation

// MARK: - Invitation Suggestions Types

/// A suggested contact in the Invitation Suggestions list.
/// Provided by the customer via invitationSuggestionsConfig.contacts.
public struct InvitationSuggestionContact: Identifiable, Sendable {
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

/// Configuration for the Invitation Suggestions feature.
/// Passed to VortexInviteView to enable and configure the Invitation Suggestions component.
///
/// The customer provides a list of suggested contacts with internal IDs. The user can either
/// tap "Invite" to send an invitation, or tap "X" to dismiss the suggestion.
public struct InvitationSuggestionsConfig {
    /// List of suggested contacts to display.
    /// Each contact must have an internalId that identifies them in the customer's platform.
    public let contacts: [InvitationSuggestionContact]
    
    /// Called when user taps "Invite" on a contact.
    /// The customer implements this callback to perform any pre-invitation logic.
    ///
    /// If the callback returns true, the SDK will create an invitation via the
    /// Vortex backend with target type = internalId.
    ///
    /// If the callback returns false, no invitation is created.
    public let onInvite: (InvitationSuggestionContact) async -> Bool
    
    /// Called when user taps "X" to dismiss a suggestion.
    /// The customer implements this callback to handle the dismissal (e.g., persist it).
    public let onDismiss: (InvitationSuggestionContact) -> Void
    
    /// Optional: Called after an invitation is successfully created.
    /// Use this to update your UI or local state.
    public let onInvitationCreated: ((InvitationSuggestionContact) -> Void)?
    
    /// Optional: Called if creating the invitation fails.
    public let onInvitationFailed: ((InvitationSuggestionContact, Error) -> Void)?
    
    /// Optional: Custom text for the "Invite" button.
    /// Default: "Invite"
    public let inviteButtonText: String
    
    /// Optional: Custom empty state message when no suggestions are available.
    /// Default: "No suggestions available"
    public let emptyStateMessage: String
    
    public init(
        contacts: [InvitationSuggestionContact],
        onInvite: @escaping (InvitationSuggestionContact) async -> Bool,
        onDismiss: @escaping (InvitationSuggestionContact) -> Void,
        onInvitationCreated: ((InvitationSuggestionContact) -> Void)? = nil,
        onInvitationFailed: ((InvitationSuggestionContact, Error) -> Void)? = nil,
        inviteButtonText: String = "Invite",
        emptyStateMessage: String = "No suggestions available"
    ) {
        self.contacts = contacts
        self.onInvite = onInvite
        self.onDismiss = onDismiss
        self.onInvitationCreated = onInvitationCreated
        self.onInvitationFailed = onInvitationFailed
        self.inviteButtonText = inviteButtonText
        self.emptyStateMessage = emptyStateMessage
    }
}
