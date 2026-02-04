import Foundation

/// Configuration for Open Graph unfurl metadata when sharing invitation links.
///
/// When invitation links are shared on social platforms (iMessage, Facebook, Twitter, etc.),
/// these values customize the preview card that appears. The backend extracts these from
/// the invitation's metadata and uses them to generate Open Graph meta tags.
///
/// ## Priority Chain
/// The backend uses this priority for unfurl values:
/// 1. **Invitation metadata** (these values) - highest priority
/// 2. **Domain profile unfurlData** - fallback from account settings
/// 3. **Hardcoded defaults** - last resort
///
/// ## Example
/// ```swift
/// VortexInviteView(
///     componentId: "widget-123",
///     jwt: userToken,
///     unfurlConfig: UnfurlConfig(
///         title: "Join our team!",
///         description: "You've been invited to collaborate",
///         image: "https://example.com/preview.png",
///         siteName: "My App",
///         type: "website"
///     )
/// )
/// ```
public struct UnfurlConfig {
    /// The title shown in the link preview (og:title)
    public let title: String?
    
    /// The description shown in the link preview (og:description)
    public let description: String?
    
    /// URL to the image shown in the link preview (og:image). Must be a valid URL.
    public let image: String?
    
    /// The site name shown in the link preview (og:site_name)
    public let siteName: String?
    
    /// The Open Graph type (og:type). Defaults to "website" if not provided or invalid.
    /// Valid values include: "website", "article", "book", "profile", "music.song", etc.
    public let type: String?
    
    /// Initialize an UnfurlConfig with optional Open Graph metadata values.
    /// - Parameters:
    ///   - title: The title for link previews (og:title)
    ///   - description: The description for link previews (og:description)
    ///   - image: URL to the preview image (og:image)
    ///   - siteName: The site name for link previews (og:site_name)
    ///   - type: The Open Graph type (og:type), defaults to "website"
    public init(
        title: String? = nil,
        description: String? = nil,
        image: String? = nil,
        siteName: String? = nil,
        type: String? = nil
    ) {
        self.title = title
        self.description = description
        self.image = image
        self.siteName = siteName
        self.type = type
    }
    
    /// Convert the config to metadata dictionary with nested unfurlConfig object.
    /// Used internally when creating invitations.
    internal func toMetadata() -> [String: Any] {
        var unfurlConfig: [String: String] = [:]
        if let title = title { unfurlConfig["title"] = title }
        if let description = description { unfurlConfig["description"] = description }
        if let image = image { unfurlConfig["image"] = image }
        if let siteName = siteName { unfurlConfig["siteName"] = siteName }
        if let type = type { unfurlConfig["type"] = type }
        
        guard !unfurlConfig.isEmpty else { return [:] }
        return ["unfurlConfig": unfurlConfig]
    }
}
