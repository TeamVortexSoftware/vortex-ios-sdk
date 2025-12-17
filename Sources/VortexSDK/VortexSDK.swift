import Foundation

// MARK: - Public API Exports

// Re-export all public types for convenient importing
@_exported import struct VortexSDK.WidgetConfiguration
@_exported import struct VortexSDK.VortexInviteView
@_exported import class VortexSDK.VortexClient
@_exported import enum VortexSDK.VortexError
@_exported import struct VortexSDK.GroupDTO

/// VortexSDK version information
public enum VortexSDK {
    /// Current version of the SDK
    public static let version = "1.0.0"
    
    /// SDK name identifier
    public static let name = "VortexSDK-iOS"
    
    /// Minimum iOS version required
    public static let minimumIOSVersion = "15.0"
}
