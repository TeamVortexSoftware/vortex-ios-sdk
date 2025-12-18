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
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Copy Link button
            if viewModel.isCopyLinkEnabled {
                ShareButton(
                    icon: .link,
                    title: viewModel.copySuccess ? "✓ Copied!" : "Copy Link",
                    isLoading: viewModel.loadingCopy,
                    theme: block.theme
                ) {
                    Task { await viewModel.copyLink() }
                }
            }
            
            // Native Share button
            if viewModel.isNativeShareEnabled {
                ShareButton(
                    icon: .share,
                    title: viewModel.shareSuccess ? "✓ Shared!" : "Share Invitation",
                    isLoading: viewModel.loadingShare,
                    theme: block.theme
                ) {
                    Task { await viewModel.shareInvitation() }
                }
            }
            
            // SMS button
            if viewModel.isSmsEnabled {
                ShareButton(
                    icon: .sms,
                    title: "Share via SMS",
                    theme: block.theme
                ) {
                    viewModel.shareViaSms()
                }
            }
            
            // QR Code button
            if viewModel.isQrCodeEnabled {
                ShareButton(
                    icon: .qrCode,
                    title: "Show QR Code",
                    theme: block.theme
                ) {
                    viewModel.showQrCode()
                }
            }
            
            // LINE button
            if viewModel.isLineEnabled {
                ShareButton(
                    icon: .line,
                    title: "Share via LINE",
                    theme: block.theme
                ) {
                    viewModel.shareViaLine()
                }
            }
        }
        .padding(.horizontal)
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
            .padding()
            .backgroundStyle(backgroundStyle)
            .foregroundColor(foregroundColor)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }
}

// MARK: - Email Pill View

