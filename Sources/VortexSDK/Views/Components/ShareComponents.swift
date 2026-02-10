import SwiftUI

struct ShareOptionsView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Section label from block attributes
            if let label = block.attributes?["label"]?.stringValue {
                HStack {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0x66/255, green: 0x66/255, blue: 0x66/255))
                    Spacer()
                }
            }
            
            // Render buttons in configuration order
            ForEach(viewModel.shareOptions, id: \.self) { option in
                shareButton(for: option)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    /// Get custom label for a button from settings.customizations, or use default
    private func customLabel(for key: String, default defaultLabel: String) -> String {
        block.settings?.customizations?[key]?.textContent ?? defaultLabel
    }
    
    @ViewBuilder
    private func shareButton(for option: String) -> some View {
        switch option {
        case "copyLink":
            ShareButton(
                icon: .link,
                title: viewModel.copySuccess ? customLabel(for: "mobile.copyLink.successText", default: "✓ Copied!") : customLabel(for: "mobile.copyLink", default: "Copy Link"),
                isLoading: viewModel.loadingCopy,
                theme: block.theme
            ) {
                Task { await viewModel.copyLink() }
            }
        case "nativeShareSheet":
            ShareButton(
                icon: .share,
                title: viewModel.shareSuccess ? customLabel(for: "mobile.nativeShareSheet.successText", default: "✓ Shared!") : customLabel(for: "mobile.nativeShareSheet", default: "Share Invitation"),
                isLoading: viewModel.loadingShare,
                theme: block.theme
            ) {
                Task { await viewModel.shareInvitation() }
            }
        case "sms":
            ShareButton(
                icon: .sms,
                title: customLabel(for: "mobile.sms", default: "Share via SMS"),
                theme: block.theme
            ) {
                viewModel.shareViaSms()
            }
        case "qrCode":
            ShareButton(
                icon: .qrCode,
                title: customLabel(for: "mobile.qrCode", default: "Show QR Code"),
                theme: block.theme
            ) {
                viewModel.showQrCode()
            }
        case "line":
            ShareButton(
                icon: .line,
                title: customLabel(for: "mobile.line", default: "Share via LINE"),
                theme: block.theme
            ) {
                viewModel.shareViaLine()
            }
        case "lineLiff":
            ShareButton(
                icon: .line,
                title: customLabel(for: "mobile.lineLiff", default: "Share via LINE (LIFF)"),
                theme: block.theme
            ) {
                viewModel.shareViaLineLiff()
            }
        case "email":
            ShareButton(
                icon: .email,
                title: customLabel(for: "mobile.email", default: "Share via Email"),
                theme: block.theme
            ) {
                viewModel.shareViaEmail()
            }
        case "twitterDms":
            ShareButton(
                icon: .xTwitter,
                title: customLabel(for: "mobile.twitterDms", default: "Share via X"),
                theme: block.theme
            ) {
                viewModel.shareViaTwitter()
            }
        case "instagramDms":
            ShareButton(
                icon: .instagram,
                title: customLabel(for: "mobile.instagramDms", default: "Share via Instagram"),
                theme: block.theme
            ) {
                viewModel.shareViaInstagram()
            }
        case "whatsApp":
            ShareButton(
                icon: .whatsapp,
                title: customLabel(for: "mobile.whatsApp", default: "Share via WhatsApp"),
                theme: block.theme
            ) {
                viewModel.shareViaWhatsApp()
            }
        case "facebookMessenger":
            ShareButton(
                icon: .facebookMessenger,
                title: customLabel(for: "mobile.facebookMessenger", default: "Share via Messenger"),
                theme: block.theme
            ) {
                viewModel.shareViaFacebookMessenger()
            }
        case "telegram":
            ShareButton(
                icon: .telegram,
                title: customLabel(for: "mobile.telegram", default: "Share via Telegram"),
                theme: block.theme
            ) {
                viewModel.shareViaTelegram()
            }
        case "discord":
            ShareButton(
                icon: .discord,
                title: customLabel(for: "mobile.discord", default: "Share via Discord"),
                theme: block.theme
            ) {
                viewModel.shareViaDiscord()
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Share Button

struct ShareButton: View {
    let icon: VortexIconName
    let title: String
    var isLoading: Bool = false
    var theme: Theme? = nil
    let action: () -> Void
    
    /// Default background color matching RN SDK's #f5f5f5
    private static let defaultBackgroundColor = Color(red: 0xf5/255, green: 0xf5/255, blue: 0xf5/255)
    
    /// Computed background style from theme or default
    private var backgroundStyle: BackgroundStyle {
        theme?.buttonBackgroundStyle ?? .solid(Self.defaultBackgroundColor)
    }
    
    /// Default dark color matching RN SDK's #333
    private static let defaultDarkColor = Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)
    
    /// Computed foreground color from theme or default
    /// Matches RN SDK behavior: defaults to #333 regardless of background type
    private var foregroundColor: Color {
        theme?.buttonTextColor ?? Self.defaultDarkColor
    }
    
    /// Get textAlign from theme options and map to HorizontalAlignment
    /// Matches RN SDK behavior: left/start → leading, right/end → trailing, default → center
    private var buttonAlignment: Alignment {
        guard let options = theme?.options,
              let textAlign = options.first(where: { $0.key == "--vrtx-icon-button-text-align" })?.value else {
            return .center
        }
        switch textAlign {
        case "left", "start":
            return .leading
        case "right", "end":
            return .trailing
        default:
            return .center
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .frame(width: 24, height: 18)
                } else {
                    // Use width: 24, height: 18 to match RN SDK's buttonIconContainer
                    // This prevents the link icon (which is wider than tall) from being clipped
                    VortexIcon(name: icon, size: 18, color: foregroundColor)
                        .frame(width: 24, height: 18)
                }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: buttonAlignment)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .backgroundStyle(backgroundStyle)
            .foregroundColor(foregroundColor)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }
}

// MARK: - Email Pill View

