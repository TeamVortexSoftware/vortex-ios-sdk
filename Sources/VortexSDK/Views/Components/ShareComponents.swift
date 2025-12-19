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
    
    @ViewBuilder
    private func shareButton(for option: String) -> some View {
        switch option {
        case "copyLink":
            ShareButton(
                icon: .link,
                title: viewModel.copySuccess ? "✓ Copied!" : "Copy Link",
                isLoading: viewModel.loadingCopy,
                theme: block.theme
            ) {
                Task { await viewModel.copyLink() }
            }
        case "nativeShareSheet":
            ShareButton(
                icon: .share,
                title: viewModel.shareSuccess ? "✓ Shared!" : "Share Invitation",
                isLoading: viewModel.loadingShare,
                theme: block.theme
            ) {
                Task { await viewModel.shareInvitation() }
            }
        case "sms":
            ShareButton(
                icon: .sms,
                title: "Share via SMS",
                theme: block.theme
            ) {
                viewModel.shareViaSms()
            }
        case "qrCode":
            ShareButton(
                icon: .qrCode,
                title: "Show QR Code",
                theme: block.theme
            ) {
                viewModel.showQrCode()
            }
        case "line":
            ShareButton(
                icon: .line,
                title: "Share via LINE",
                theme: block.theme
            ) {
                viewModel.shareViaLine()
            }
        case "email":
            ShareButton(
                icon: .email,
                title: "Share via Email",
                theme: block.theme
            ) {
                viewModel.shareViaEmail()
            }
        case "twitterDms":
            ShareButton(
                icon: .xTwitter,
                title: "Share via X",
                theme: block.theme
            ) {
                viewModel.shareViaTwitter()
            }
        case "instagramDms":
            ShareButton(
                icon: .instagram,
                title: "Share via Instagram",
                theme: block.theme
            ) {
                viewModel.shareViaInstagram()
            }
        case "whatsApp":
            ShareButton(
                icon: .whatsapp,
                title: "Share via WhatsApp",
                theme: block.theme
            ) {
                viewModel.shareViaWhatsApp()
            }
        case "facebookMessenger":
            ShareButton(
                icon: .facebookMessenger,
                title: "Share via Messenger",
                theme: block.theme
            ) {
                viewModel.shareViaFacebookMessenger()
            }
        case "telegram":
            ShareButton(
                icon: .telegram,
                title: "Share via Telegram",
                theme: block.theme
            ) {
                viewModel.shareViaTelegram()
            }
        case "discord":
            ShareButton(
                icon: .discord,
                title: "Share via Discord",
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
    
    /// Computed background style from theme or default
    private var backgroundStyle: BackgroundStyle {
        theme?.buttonBackgroundStyle ?? .solid(Color(UIColor.secondarySystemBackground))
    }
    
    /// Default dark color matching RN SDK's #333
    private static let defaultDarkColor = Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)
    
    /// Computed foreground color from theme or default
    /// Matches RN SDK behavior: defaults to #333 regardless of background type
    private var foregroundColor: Color {
        theme?.buttonTextColor ?? Self.defaultDarkColor
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
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
            .frame(maxWidth: .infinity)
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

