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
                    isLoading: viewModel.loadingCopy
                ) {
                    Task { await viewModel.copyLink() }
                }
            }
            
            // Native Share button
            if viewModel.isNativeShareEnabled {
                ShareButton(
                    icon: .share,
                    title: viewModel.shareSuccess ? "✓ Shared!" : "Share Invitation",
                    isLoading: viewModel.loadingShare
                ) {
                    Task { await viewModel.shareInvitation() }
                }
            }
            
            // SMS button
            if viewModel.isSmsEnabled {
                ShareButton(
                    icon: .sms,
                    title: "Share via SMS"
                ) {
                    viewModel.shareViaSms()
                }
            }
            
            // QR Code button
            if viewModel.isQrCodeEnabled {
                ShareButton(
                    icon: .qrCode,
                    title: "Show QR Code"
                ) {
                    viewModel.showQrCode()
                }
            }
            
            // LINE button
            if viewModel.isLineEnabled {
                ShareButton(
                    icon: .line,
                    title: "Share via LINE"
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .frame(width: 24, height: 18)
                } else {
                    // Use width: 24, height: 18 to match RN SDK's buttonIconContainer
                    // This prevents the link icon (which is wider than tall) from being clipped
                    VortexIcon(name: icon, size: 18, color: .primary)
                        .frame(width: 24, height: 18)
                }
                Text(title)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }
}

// MARK: - Email Pill View

