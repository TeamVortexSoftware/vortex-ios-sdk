import UIKit
import CoreText

/// FontAwesome 6 icon style
public enum FontAwesomeStyle {
    case solid
    case regular
    case brands
    
    var fontFileName: String {
        switch self {
        case .solid: return "fa-solid-900"
        case .regular: return "fa-regular-400"
        case .brands: return "fa-brands-400"
        }
    }
    
    var fontName: String {
        switch self {
        case .solid: return "FontAwesome6Free-Solid"
        case .regular: return "FontAwesome6Free-Regular"
        case .brands: return "FontAwesome6Brands-Regular"
        }
    }
}

/// FontAwesome 6 icon codes (Unicode values)
/// These match the FontAwesome 6 Free icon set used in react-native-vector-icons
public enum FontAwesome6Icon: String {
    // UI Icons (Solid)
    case xmark = "\u{f00d}"
    case arrowLeft = "\u{f060}"
    case link = "\u{f0c1}"
    case shareNodes = "\u{f1e0}"
    case addressBook = "\u{f2b9}"
    case envelope = "\u{f0e0}"
    case comment = "\u{f075}"
    case qrcode = "\u{f029}"
    
    // Brand Icons
    case google = "\u{f1a0}"
    case xTwitter = "\u{e61b}"
    case instagram = "\u{f16d}"
    case whatsapp = "\u{f232}"
    case line = "\u{f3c0}"
    case telegram = "\u{f2c6}"
    case discord = "\u{f392}"
    case facebookMessenger = "\u{f39f}"
}

/// Utility class to load and manage FontAwesome fonts bundled with the SDK
public final class FontAwesomeLoader {
    
    /// Shared instance
    public static let shared = FontAwesomeLoader()
    
    /// Track which fonts have been registered
    private var registeredFonts: Set<String> = []
    
    /// Serial queue for thread-safe font registration
    private let queue = DispatchQueue(label: "com.vortex.fontawesome.loader")
    
    private init() {}
    
    /// Register all FontAwesome fonts bundled with the SDK
    /// Call this early in your app lifecycle (e.g., in AppDelegate or @main)
    public func registerFonts() {
        registerFont(style: .solid)
        registerFont(style: .regular)
        registerFont(style: .brands)
    }
    
    /// Register a specific FontAwesome font style
    public func registerFont(style: FontAwesomeStyle) {
        queue.sync {
            let fontFileName = style.fontFileName
            
            // Skip if already registered
            guard !registeredFonts.contains(fontFileName) else { return }
            
            // Find the font file in the bundle
            guard let fontURL = Bundle.module.url(forResource: fontFileName, withExtension: "ttf") else {
                print("[VortexSDK] Warning: Could not find font file: \(fontFileName).ttf")
                return
            }
            
            // Register the font with CoreText
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            
            if success {
                registeredFonts.insert(fontFileName)
                #if DEBUG
                print("[VortexSDK] Successfully registered font: \(fontFileName)")
                #endif
            } else {
                if let error = error?.takeRetainedValue() {
                    let errorDescription = CFErrorCopyDescription(error) as String? ?? "Unknown error"
                    // Font might already be registered by the system or another call
                    if errorDescription.contains("already registered") {
                        registeredFonts.insert(fontFileName)
                    } else {
                        print("[VortexSDK] Warning: Failed to register font \(fontFileName): \(errorDescription)")
                    }
                }
            }
        }
    }
    
    /// Get a UIFont for FontAwesome with the specified size and style
    public func font(ofSize size: CGFloat, style: FontAwesomeStyle) -> UIFont? {
        // Ensure font is registered
        registerFont(style: style)
        
        // Try to get the font
        if let font = UIFont(name: style.fontName, size: size) {
            return font
        }
        
        // Fallback: list available fonts for debugging
        #if DEBUG
        print("[VortexSDK] Available fonts for family:")
        for family in UIFont.familyNames.sorted() {
            if family.lowercased().contains("awesome") || family.lowercased().contains("fa") {
                print("  Family: \(family)")
                for name in UIFont.fontNames(forFamilyName: family) {
                    print("    - \(name)")
                }
            }
        }
        #endif
        
        return nil
    }
    
    /// Check if fonts are available
    public var fontsAvailable: Bool {
        return UIFont(name: FontAwesomeStyle.solid.fontName, size: 12) != nil
    }
}
