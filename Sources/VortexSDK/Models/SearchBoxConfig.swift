import Foundation

/// Configuration for the Search Box feature.
/// Passed to VortexInviteView to enable and configure the Search Box component.
///
/// The customer provides an `onSearch` callback that returns matching contacts.
/// When the user taps "Connect", the SDK creates an invitation with target type = internalId.
public struct SearchBoxConfig {
    /// Called when the user taps the search button.
    /// The customer implements this callback to perform the search and return matching contacts.
    public let onSearch: (String) async -> [FindFriendsContact]
    
    /// Called when user taps "Connect" on a search result contact.
    /// If the callback returns true, the SDK will create an invitation via the Vortex backend.
    public let onConnect: ((FindFriendsContact) async -> Bool)?
    
    /// Optional: Called after an invitation is successfully created.
    public let onInvitationCreated: ((FindFriendsContact) -> Void)?
    
    /// Optional: Called if creating the invitation fails.
    public let onInvitationError: ((FindFriendsContact, Error) -> Void)?
    
    /// Optional: Custom text for the "Connect" button.
    /// Defaults to "Connect".
    public let connectButtonText: String?
    
    /// Optional: Custom message shown when search returns no results.
    /// Defaults to "No results found".
    public let noResultsMessage: String?
    
    public init(
        onSearch: @escaping (String) async -> [FindFriendsContact],
        onConnect: ((FindFriendsContact) async -> Bool)? = nil,
        onInvitationCreated: ((FindFriendsContact) -> Void)? = nil,
        onInvitationError: ((FindFriendsContact, Error) -> Void)? = nil,
        connectButtonText: String? = nil,
        noResultsMessage: String? = nil
    ) {
        self.onSearch = onSearch
        self.onConnect = onConnect
        self.onInvitationCreated = onInvitationCreated
        self.onInvitationError = onInvitationError
        self.connectButtonText = connectButtonText
        self.noResultsMessage = noResultsMessage
    }
}
