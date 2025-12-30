import SwiftUI

struct ContactsImportView: View {
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
            
            // Import from Contacts button
            if viewModel.isNativeContactsEnabled {
                ShareButton(
                    icon: .importContacts,
                    title: "Add from Contacts",
                    theme: block.theme
                ) {
                    viewModel.selectFromContacts()
                }
            }
            
            // Import from Google Contacts button
            if viewModel.isGoogleContactsEnabled {
                ShareButton(
                    icon: .google,
                    title: "Add from Google Contacts",
                    theme: block.theme
                ) {
                    viewModel.selectFromGoogleContacts()
                }
            }
            
            // Add by Email button (navigates to email entry view)
            // This matches the RN SDK behavior where VrtxContactsImport renders "Add by Email"
            // when isEmailInvitationsEnabled() returns true
            if viewModel.isEmailInvitationsEnabled {
                ShareButton(
                    icon: .email,
                    title: "Add by Email",
                    theme: block.theme
                ) {
                    viewModel.currentView = .emailEntry
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
}

// MARK: - Email Pill View

struct EmailPillView: View {
    let email: String
    var backgroundStyle: BackgroundStyle? = nil
    let onRemove: () -> Void
    
    /// Default background color
    private static let defaultBackgroundColor = Color(UIColor.tertiarySystemBackground)
    
    /// Computed text color - use dark text for gradients, gray for default
    private var textColor: Color {
        if backgroundStyle != nil {
            return Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)
        }
        return .primary
    }
    
    /// Computed icon color - use dark color for gradients, gray for default
    private var iconColor: Color {
        if backgroundStyle != nil {
            return Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)
        }
        return .gray
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(email)
                .font(.subheadline)
                .foregroundColor(textColor)
            Button(action: onRemove) {
                VortexIcon(name: .close, size: 14, color: iconColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .backgroundStyle(backgroundStyle ?? .solid(Self.defaultBackgroundColor))
        .cornerRadius(16)
    }
}

// MARK: - Contact Row View

/// A row displaying a contact with an Invite button (matching RN SDK)
struct ContactRowView: View {
    let contact: VortexContact
    let isInvited: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onInvite: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Contact info
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(contact.email)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                // Show error message if present
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Invite button, Invited status, or Error with Retry
            if isInvited {
                Text("✓ Invited!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            } else if errorMessage != nil {
                // Show Retry button on error
                Button(action: onInvite) {
                    if isLoading {
                        ProgressView()
                            .frame(width: 60)
                    } else {
                        Text("Retry")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
                .frame(minWidth: 80)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
                .disabled(isLoading)
            } else {
                Button(action: onInvite) {
                    if isLoading {
                        ProgressView()
                            .frame(width: 60)
                    } else {
                        Text("Invite")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(minWidth: 80)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
                .disabled(isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
