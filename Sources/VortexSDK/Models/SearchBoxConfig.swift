import Foundation

// MARK: - Search Box Types

/// A contact returned from the Search Box search callback.
/// Provided by the customer via searchBoxConfig.onSearch.
public struct SearchBoxContact: Identifiable, Sendable {
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

/// Configuration for the Search Box feature.
/// Passed to VortexInviteView to enable and configure the Search Box component.
///
/// The customer provides an `onSearch` callback that returns matching contacts.
/// When the user taps "Connect", the SDK creates an invitation with target type = internalId
/// via the Vortex backend, identical to the Find Friends component behavior.
public struct SearchBoxConfig {
    /// Called when the user taps the search button.
    /// The customer implements this callback to perform the search and return matching contacts.
    public let onSearch: (String) async -> [SearchBoxContact]
    
    /// Optional: Called after an invitation is successfully created.
    /// Use this to trigger in-app notifications or update your UI.
    public let onInvitationCreated: ((SearchBoxContact) -> Void)?
    
    public init(
        onSearch: @escaping (String) async -> [SearchBoxContact],
        onInvitationCreated: ((SearchBoxContact) -> Void)? = nil
    ) {
        self.onSearch = onSearch
        self.onInvitationCreated = onInvitationCreated
    }
}
