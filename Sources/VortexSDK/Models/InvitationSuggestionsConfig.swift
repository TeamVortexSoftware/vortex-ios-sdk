import Foundation

// MARK: - Invitation Suggestions Types

/// A suggested contact in the Invitation Suggestions list.
/// Provided by the customer via invitationSuggestionsConfig.contacts.
public struct InvitationSuggestionContact: Identifiable, Sendable {
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

/// Configuration for the Invitation Suggestions feature.
/// Passed to VortexInviteView to enable and configure the Invitation Suggestions component.
///
/// The customer provides a list of suggested contacts with user IDs. The user can either
/// tap "Invite" to send an invitation, or tap "X" to dismiss the suggestion.
public struct InvitationSuggestionsConfig {
    /// List of suggested contacts to display.
    /// Each contact must have a userId that identifies them in the customer's platform.
    public let contacts: [InvitationSuggestionContact]
    
    /// Optional: Maximum number of suggestions to display at once.
    /// If the total contacts exceed this number, a random subset of this size is displayed
    /// in alphabetical order. When a suggestion is removed (invited or dismissed), it is
    /// replaced with another from the remaining pool until the pool is exhausted.
    /// If nil, all suggestions are displayed.
    public let maxDisplayCount: Int?
    
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
        maxDisplayCount: Int? = nil,
        onDismiss: @escaping (InvitationSuggestionContact) -> Void,
        onInvitationCreated: ((InvitationSuggestionContact) -> Void)? = nil,
        onInvitationFailed: ((InvitationSuggestionContact, Error) -> Void)? = nil,
        inviteButtonText: String = "Invite",
        emptyStateMessage: String = "No suggestions available"
    ) {
        self.contacts = contacts
        self.maxDisplayCount = maxDisplayCount
        self.onDismiss = onDismiss
        self.onInvitationCreated = onInvitationCreated
        self.onInvitationFailed = onInvitationFailed
        self.inviteButtonText = inviteButtonText
        self.emptyStateMessage = emptyStateMessage
    }
}
