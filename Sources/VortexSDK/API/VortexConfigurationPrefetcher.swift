import Foundation

/// Prefetches widget configuration for instant rendering.
/// Use this class to fetch the configuration early (e.g., when JWT becomes available)
/// so the VortexInviteView can render immediately without showing a loading spinner.
///
/// The prefetcher stores the configuration in the shared cache, which is automatically
/// used by VortexInviteView. The view will still refresh in the background when it mounts
/// to ensure the configuration is up-to-date (stale-while-revalidate pattern).
///
/// ## Example Usage
///
/// ```swift
/// // In your view or view model where JWT becomes available
/// let prefetcher = VortexConfigurationPrefetcher(
///     componentId: "your-component-id",
///     apiBaseURL: URL(string: "https://client-api.vortexsoftware.com")!
/// )
///
/// // Start prefetching when JWT is ready
/// Task {
///     await prefetcher.prefetch(jwt: jwt)
/// }
///
/// // Later, when showing VortexInviteView, it will use the cached configuration
/// VortexInviteView(
///     componentId: "your-component-id",
///     jwt: jwt,
///     // ... other parameters
/// )
/// ```
@MainActor
public class VortexConfigurationPrefetcher: ObservableObject {
    /// The component ID to prefetch configuration for
    public let componentId: String
    
    /// Current prefetch state
    @Published public private(set) var isLoading: Bool = false
    
    /// Error that occurred during prefetch, if any
    @Published public private(set) var error: Error?
    
    /// Whether configuration has been successfully prefetched
    @Published public private(set) var isPrefetched: Bool = false
    
    /// The prefetched widget configuration (read from cache)
    public var widgetConfiguration: WidgetConfiguration? {
        get async {
            await VortexConfigurationCache.shared.get(componentId, locale: locale)?.configuration
        }
    }
    
    private let client: VortexClient
    private let locale: String?
    
    /// Initialize a new prefetcher
    /// - Parameters:
    ///   - componentId: The widget/component ID from your Vortex dashboard
    ///   - apiBaseURL: Base URL of the Vortex API (default: production)
    ///   - locale: Optional locale for internationalization (e.g., "pt-BR", "en-US")
    public init(
        componentId: String,
        apiBaseURL: URL = URL(string: "https://client-api.vortexsoftware.com")!,
        locale: String? = nil
    ) {
        self.componentId = componentId
        self.client = VortexClient(baseURL: apiBaseURL)
        self.locale = locale
    }
    
    /// Prefetch the widget configuration
    /// - Parameter jwt: JWT authentication token
    /// - Returns: The prefetched configuration, or nil if prefetch failed
    @discardableResult
    public func prefetch(jwt: String) async -> WidgetConfiguration? {
        // Check if already cached (locale-aware)
        if let cached = await VortexConfigurationCache.shared.get(componentId, locale: locale) {
            isPrefetched = true
            return cached.configuration
        }
        
        isLoading = true
        error = nil
        
        do {
            let configData = try await client.getWidgetConfiguration(
                componentId: componentId,
                jwt: jwt,
                locale: locale
            )
            
            // Store in shared cache (locale-aware)
            await VortexConfigurationCache.shared.set(
                componentId,
                configuration: configData.widgetConfiguration,
                deploymentId: configData.deploymentId,
                locale: locale
            )
            
            isPrefetched = true
            isLoading = false
            return configData.widgetConfiguration
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    /// Clear the prefetched configuration from cache
    public func clearCache() async {
        await VortexConfigurationCache.shared.clear(componentId, locale: locale)
        isPrefetched = false
    }
}
