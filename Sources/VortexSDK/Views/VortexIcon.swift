import SwiftUI
import UIKit

/// Icon names used in the Vortex SDK (matching React Native SDK)
public enum VortexIconName: String {
    case close = "close"
    case arrowBack = "arrow-back"
    case link = "link"
    case share = "share"
    case importContacts = "import-contacts"
    case email = "email"
    case google = "google"
    case xTwitter = "x-twitter"
    case instagram = "instagram"
    case sms = "sms"
    case whatsapp = "whatsapp"
    case qrCode = "qr-code"
    case line = "line"
}

/// A view that renders FontAwesome 6 icons for the Vortex SDK
/// Uses bundled FontAwesome fonts to match the React Native SDK exactly
public struct VortexIcon: View {
    let name: VortexIconName
    let size: CGFloat
    let color: Color
    
    public init(name: VortexIconName, size: CGFloat = 18, color: Color = .primary) {
        self.name = name
        self.size = size
        self.color = color
    }
    
    /// Get the FontAwesome icon info (unicode and style)
    private var iconInfo: (unicode: String, style: FontAwesomeStyle) {
        switch name {
        case .close:
            return (FontAwesome6Icon.xmark.rawValue, .solid)
        case .arrowBack:
            return (FontAwesome6Icon.arrowLeft.rawValue, .solid)
        case .link:
            return (FontAwesome6Icon.link.rawValue, .solid)
        case .share:
            return (FontAwesome6Icon.shareNodes.rawValue, .solid)
        case .importContacts:
            return (FontAwesome6Icon.addressBook.rawValue, .solid)
        case .email:
            return (FontAwesome6Icon.envelope.rawValue, .solid)
        case .google:
            return (FontAwesome6Icon.google.rawValue, .brands)
        case .xTwitter:
            return (FontAwesome6Icon.xTwitter.rawValue, .brands)
        case .instagram:
            return (FontAwesome6Icon.instagram.rawValue, .brands)
        case .sms:
            return (FontAwesome6Icon.comment.rawValue, .solid)
        case .whatsapp:
            return (FontAwesome6Icon.whatsapp.rawValue, .brands)
        case .qrCode:
            return (FontAwesome6Icon.qrcode.rawValue, .solid)
        case .line:
            return (FontAwesome6Icon.line.rawValue, .brands)
        }
    }
    
    public var body: some View {
        let info = iconInfo
        
        // Try to use FontAwesome font
        if let uiFont = FontAwesomeLoader.shared.font(ofSize: size, style: info.style) {
            Text(info.unicode)
                .font(Font(uiFont))
                .foregroundColor(color)
        } else {
            // Fallback to SF Symbols if FontAwesome fails to load
            Image(systemName: sfSymbolFallback)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(color)
        }
    }
    
    /// SF Symbol fallback names in case FontAwesome fonts fail to load
    private var sfSymbolFallback: String {
        switch name {
        case .close:
            return "xmark"
        case .arrowBack:
            return "arrow.left"
        case .link:
            return "link"
        case .share:
            return "square.and.arrow.up"
        case .importContacts:
            return "person.crop.circle.badge.plus"
        case .email:
            return "envelope"
        case .google:
            return "g.circle.fill"
        case .xTwitter:
            return "at"
        case .instagram:
            return "camera"
        case .sms:
            return "message"
        case .whatsapp:
            return "phone.bubble"
        case .qrCode:
            return "qrcode"
        case .line:
            return "bubble.left.and.bubble.right"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VortexIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VortexIcon(name: .close, size: 24)
                VortexIcon(name: .arrowBack, size: 24)
                VortexIcon(name: .link, size: 24)
                VortexIcon(name: .share, size: 24)
            }
            HStack(spacing: 20) {
                VortexIcon(name: .importContacts, size: 24)
                VortexIcon(name: .email, size: 24)
                VortexIcon(name: .sms, size: 24)
                VortexIcon(name: .qrCode, size: 24)
            }
            HStack(spacing: 20) {
                VortexIcon(name: .google, size: 24, color: .red)
                VortexIcon(name: .xTwitter, size: 24)
                VortexIcon(name: .instagram, size: 24, color: .purple)
                VortexIcon(name: .whatsapp, size: 24, color: .green)
            }
            HStack(spacing: 20) {
                VortexIcon(name: .line, size: 24, color: .green)
            }
        }
        .padding()
    }
}
#endif
