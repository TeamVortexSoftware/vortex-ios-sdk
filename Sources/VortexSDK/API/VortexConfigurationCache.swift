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
/// - Locale-aware caching (different locales are cached separately)
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
    
    // MARK: - Private Helpers
    
    /// Generate a cache key that includes both componentId and locale.
    /// This ensures different locales are cached separately.
    private func cacheKey(componentId: String, locale: String?) -> String {
        if let locale = locale {
            return "\(componentId):\(locale)"
        }
        return componentId
    }
    
    // MARK: - Public API
    
    /// Get a cached widget configuration by component ID and locale.
    /// - Parameters:
    ///   - componentId: The widget component ID
    ///   - locale: Optional locale for i18n (e.g., "pt-BR", "en-US")
    /// - Returns: The cached configuration data, or nil if not found
    public func get(_ componentId: String, locale: String? = nil) -> (configuration: WidgetConfiguration, deploymentId: String?)? {
        let key = cacheKey(componentId: componentId, locale: locale)
        guard let cached = cache[key] else {
            return nil
        }
        return (cached.configuration, cached.deploymentId)
    }
    
    /// Store a widget configuration in the cache.
    /// - Parameters:
    ///   - componentId: The widget component ID
    ///   - configuration: The widget configuration to cache
    ///   - deploymentId: Optional deployment ID from the API response
    ///   - locale: Optional locale for i18n (e.g., "pt-BR", "en-US")
    public func set(
        _ componentId: String,
        configuration: WidgetConfiguration,
        deploymentId: String? = nil,
        locale: String? = nil
    ) {
        let key = cacheKey(componentId: componentId, locale: locale)
        cache[key] = CachedConfiguration(
            configuration: configuration,
            deploymentId: deploymentId,
            cachedAt: Date()
        )
    }
    
    /// Clear cached configuration(s).
    /// - Parameters:
    ///   - componentId: Optional component ID to clear specific config. If nil, clears all.
    ///   - locale: Optional locale. If provided with componentId, clears only that specific locale variant.
    public func clear(_ componentId: String? = nil, locale: String? = nil) {
        if let componentId = componentId {
            let key = cacheKey(componentId: componentId, locale: locale)
            cache.removeValue(forKey: key)
        } else {
            cache.removeAll()
        }
    }
    
    /// Check if a configuration exists in the cache.
    /// - Parameters:
    ///   - componentId: The widget component ID
    ///   - locale: Optional locale for i18n (e.g., "pt-BR", "en-US")
    /// - Returns: True if configuration is cached, false otherwise
    public func has(_ componentId: String, locale: String? = nil) -> Bool {
        let key = cacheKey(componentId: componentId, locale: locale)
        return cache[key] != nil
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
