import Foundation
import UIKit
import CoreTelephony

/// VortexSDK version information and namespace
public enum VortexSDKInfo {
    /// Current version of the SDK
    public static let version = "1.0.6-dev"
    
    /// SDK name identifier
    public static let name = "VortexSDK-iOS"
    
    /// Minimum iOS version required
    public static let minimumIOSVersion = "15.0"
}

// MARK: - Deferred Deep Links

/// Provides functionality for deferred deep linking through fingerprint matching.
///
/// Deferred deep linking allows the app to retrieve invitation context even when the user
/// installs the app after clicking an invitation link. The server stores a fingerprint of
/// the user's device when they click the link, and this class provides methods to match
/// that fingerprint after app installation.
@MainActor
public class VortexDeferredLinks {
    
    /// Default production API base URL
    private static let defaultBaseURL = URL(string: "https://client-api.vortexsoftware.com")!
    
    /// Retrieves deferred deep link context by matching the device fingerprint.
    ///
    /// Call this method when the user signs in or when the app session is restored
    /// to check if there's a pending invitation from before the app was installed.
    ///
    /// The account ID is derived from the JWT token, so account-wide matching is performed
    /// across all components/widgets for the account.
    ///
    /// - Parameters:
    ///   - jwt: JWT authentication token for the current user
    ///   - baseURL: Base URL of the Vortex API (defaults to production). Only override for development/staging.
    /// - Returns: Match result containing invitation context if a match is found
    /// - Throws: VortexError if the request fails
    ///
    /// Example usage:
    /// ```swift
    /// let result = try await VortexDeferredLinks.retrieveDeferredDeepLink(jwt: userToken)
    /// if result.matched, let context = result.context {
    ///     print("Found invitation: \(context.invitationId)")
    /// }
    /// ```
    public static func retrieveDeferredDeepLink(
        jwt: String,
        baseURL: URL? = nil
    ) async throws -> MatchFingerprintResponse {
        let effectiveBaseURL = baseURL ?? defaultBaseURL
        let fingerprint = collectDeviceFingerprint()
        
        let client = VortexClient(
            baseURL: effectiveBaseURL,
            clientName: VortexSDKInfo.name,
            clientVersion: VortexSDKInfo.version
        )
        
        return try await client.matchFingerprint(
            jwt: jwt,
            fingerprint: fingerprint
        )
    }
    
    /// Collects device fingerprint data from the current device.
    ///
    /// This method gathers various device characteristics that can be used
    /// to match against fingerprints stored on the server.
    ///
    /// - Returns: DeviceFingerprint containing device characteristics
    public static func collectDeviceFingerprint() -> DeviceFingerprint {
        let device = UIDevice.current
        let screen = UIScreen.main
        
        // Get OS version
        let osVersion = device.systemVersion
        
        // Get device model identifier (e.g., "iPhone14,5", "iPhone15,2")
        let deviceModel = getDeviceModelIdentifier()
        
        // Get timezone
        let timezone = TimeZone.current.identifier
        
        // Get language
        let language = Locale.preferredLanguages.first ?? Locale.current.identifier
        
        // Get screen dimensions (in points)
        let screenWidth = Int(screen.bounds.width * screen.scale)
        let screenHeight = Int(screen.bounds.height * screen.scale)
        
        // Get carrier name (if available)
        var carrierName: String? = nil
        let networkInfo = CTTelephonyNetworkInfo()
        if let carriers = networkInfo.serviceSubscriberCellularProviders {
            carrierName = carriers.values.first?.carrierName
        }
        
        // Get total memory
        let totalMemory = Int(ProcessInfo.processInfo.physicalMemory)
        
        return DeviceFingerprint(
            platform: "ios",
            osVersion: osVersion,
            deviceModel: deviceModel,
            deviceBrand: "Apple",
            timezone: timezone,
            language: language,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            carrierName: carrierName,
            totalMemory: totalMemory
        )
    }
    
    /// Gets the device model identifier (e.g., "iPhone14,5", "iPhone15,2")
    /// On simulator, uses SIMULATOR_MODEL_IDENTIFIER environment variable.
    /// On real devices, uses sysctlbyname("hw.machine").
    private static func getDeviceModelIdentifier() -> String {
        // On iOS Simulator, sysctlbyname("hw.machine") returns the host Mac's architecture
        // (e.g., "arm64" on Apple Silicon), not the simulated device model.
        // The SIMULATOR_MODEL_IDENTIFIER environment variable contains the correct model.
        #if targetEnvironment(simulator)
        if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModel
        }
        #endif
        
        // On real devices, use sysctlbyname to get the actual device model
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}
