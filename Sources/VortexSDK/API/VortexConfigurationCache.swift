import Foundation

/// Thread-safe cache for widget configurations.
/// This cache is shared across all views and prefetchers to ensure
/// configuration updates persist between component mount/unmount cycles.
///
/// Benefits:
/// - Single source of truth for widget configurations
/// - Persists between modal open/close cycles
/// - Automatic synchronization between prefetch and main views
/// - Thread-safe via actor isolation
public actor VortexConfigurationCache {
    /// Shared singleton instance
    public static let shared = VortexConfigurationCache()
    
    /// Internal storage for cached configurations
    private var cache: [String: CachedConfiguration] = [:]
    
    /// Cached configuration with metadata
    private struct CachedConfiguration {
        let configuration: WidgetConfiguration
        let deploymentId: String?
        let cachedAt: Date
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get a cached widget configuration by component ID.
    /// - Parameter componentId: The widget component ID
    /// - Returns: The cached configuration data, or nil if not found
    public func get(_ componentId: String) -> (configuration: WidgetConfiguration, deploymentId: String?)? {
        guard let cached = cache[componentId] else {
            return nil
        }
        return (cached.configuration, cached.deploymentId)
    }
    
    /// Store a widget configuration in the cache.
    /// - Parameters:
    ///   - componentId: The widget component ID
    ///   - configuration: The widget configuration to cache
    ///   - deploymentId: Optional deployment ID from the API response
    public func set(
        _ componentId: String,
        configuration: WidgetConfiguration,
        deploymentId: String? = nil
    ) {
        cache[componentId] = CachedConfiguration(
            configuration: configuration,
            deploymentId: deploymentId,
            cachedAt: Date()
        )
    }
    
    /// Clear cached configuration(s).
    /// - Parameter componentId: Optional component ID to clear specific config. If nil, clears all.
    public func clear(_ componentId: String? = nil) {
        if let componentId = componentId {
            cache.removeValue(forKey: componentId)
        } else {
            cache.removeAll()
        }
    }
    
    /// Check if a configuration exists in the cache.
    /// - Parameter componentId: The widget component ID
    /// - Returns: True if configuration is cached, false otherwise
    public func has(_ componentId: String) -> Bool {
        return cache[componentId] != nil
    }
    
    /// Get cache statistics for debugging.
    /// - Returns: Dictionary with cache size and cached component IDs
    public func stats() -> [String: Any] {
        return [
            "size": cache.count,
            "keys": Array(cache.keys)
        ]
    }
}
