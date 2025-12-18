import SwiftUI
import UIKit
import Contacts
import GoogleSignIn

/// Main invitation form view component
/// This is the primary entry point for integrating Vortex invitations into your iOS app
public struct VortexInviteView: View {
    @StateObject private var viewModel: VortexInviteViewModel
    
    /// Initialize the VortexInviteView
    /// - Parameters:
    ///   - componentId: The widget/component ID from your Vortex dashboard
    ///   - jwt: JWT authentication token (required for API access)
    ///   - apiBaseURL: Base URL of the Vortex API (default: production)
    ///   - group: Optional group information for scoping invitations
    ///   - googleIosClientId: Google iOS Client ID for Google Contacts integration (optional)
    ///   - onDismiss: Callback when the view is dismissed
    public init(
        componentId: String,
        jwt: String?,
        apiBaseURL: URL = URL(string: "https://client-api.vortexsoftware.com")!,
        group: GroupDTO? = nil,
        googleIosClientId: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: VortexInviteViewModel(
            componentId: componentId,
            jwt: jwt,
            apiBaseURL: apiBaseURL,
            group: group,
            googleIosClientId: googleIosClientId,
            onDismiss: onDismiss
        ))
    }
    
    public var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismiss()
                }
            
            // Main content sheet
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Header with close/back button on the left (like RN SDK)
                    HStack {
                        Button(action: {
                            if viewModel.currentView == .main {
                                viewModel.dismiss()
                            } else {
                                viewModel.currentView = .main
                            }
                        }) {
                            VortexIcon(
                                name: viewModel.currentView == .main ? .close : .arrowBack,
                                size: 20,
                                color: .primary
                            )
                            .frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    
                    // Content based on loading state
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.error {
                        errorView(error: error)
                    } else if viewModel.configuration != nil {
                        formView
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.8)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .task {
            await viewModel.loadConfiguration()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: VortexError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                Task {
                    await viewModel.loadConfiguration()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var formView: some View {
        ScrollView {
            VStack(spacing: 16) {
                #if DEBUG
                // Debug info
                let _ = print("[VortexSDK] formView rendering, formStructure: \(viewModel.formStructure != nil ? "exists" : "nil")")
                let _ = print("[VortexSDK] currentView: \(viewModel.currentView)")
                #endif
                
                // Show different content based on currentView
                switch viewModel.currentView {
                case .main:
                    // Dynamic form rendering based on configuration
                    if let formRoot = viewModel.formStructure {
                        #if DEBUG
                        let _ = print("[VortexSDK] formRoot.children count: \(formRoot.children?.count ?? 0)")
                        #endif
                        ForEach(formRoot.children ?? [], id: \.id) { row in
                            #if DEBUG
                            let _ = print("[VortexSDK] Rendering row: \(row.id), type: \(row.type), hidden: \(row.hidden ?? false)")
                            #endif
                            renderRow(row)
                        }
                    } else {
                        #if DEBUG
                        let _ = print("[VortexSDK] formStructure is nil!")
                        #endif
                    }
                    
                case .emailEntry:
                    emailEntryView
                    
                case .contactsPicker:
                    contactsPickerView
                    
                case .googleContactsPicker:
                    googleContactsPickerView
                    
                case .qrCode:
                    qrCodeView
                }
                
                // Success message (can show in any view)
                if viewModel.showSuccess {
                    successMessageView
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Form Element Rendering
    
    @ViewBuilder
    private func renderRow(_ row: ElementNode) -> some View {
        if row.hidden != true {
            VStack(spacing: 12) {
                ForEach(row.children ?? [], id: \.id) { column in
                    renderColumn(column)
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderColumn(_ column: ElementNode) -> some View {
        if column.hidden != true {
            VStack(spacing: 12) {
                ForEach(column.children ?? [], id: \.id) { block in
                    renderBlock(block)
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderBlock(_ block: ElementNode) -> some View {
        if block.hidden != true {
            switch block.subtype {
            case "vrtx-share-options":
                ShareOptionsView(
                    block: block,
                    viewModel: viewModel
                )
            case "vrtx-contacts-import":
                ContactsImportView(
                    block: block,
                    viewModel: viewModel
                )
            case "vrtx-email-invitations":
                // Email invitations input is handled separately in emailEntryView
                EmptyView()
            case "vrtx-heading":
                HeadingView(block: block)
            case "vrtx-text":
                TextView(block: block)
            case "vrtx-select":
                // Select is currently not rendered (matches RN behavior)
                EmptyView()
            case "vrtx-submit":
                // Submit is currently not rendered (matches RN behavior)
                EmptyView()
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Email Entry View
    
    private var emailEntryView: some View {
        VStack(spacing: 16) {
            // Email pills for added emails
            if !viewModel.emails.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.emails, id: \.self) { email in
                            EmailPillView(email: email) {
                                viewModel.removeEmail(email)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Email input
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter email addresses", text: $viewModel.emailInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        viewModel.addEmailFromInput()
                    }
                
                Text("Press return to add each email")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Send button - enabled when there are emails in the list OR current input is a valid email
            Button(action: {
                Task {
                    // If there's a valid email in the input, add it first before sending
                    if viewModel.hasValidEmailInput {
                        viewModel.addEmailFromInput()
                    }
                    await viewModel.sendInvitation()
                }
            }) {
                HStack {
                    if viewModel.isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Invitation\(viewModel.emails.count > 1 || (viewModel.emails.count == 1 && !viewModel.hasValidEmailInput) ? "s" : "")")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canSendInvitation ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(viewModel.isSending || !viewModel.canSendInvitation)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Contacts Picker View
    
    private var contactsPickerView: some View {
        VStack(spacing: 16) {
            // Title (matching RN SDK)
            Text("Add from Contacts")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(UIColor.label))
                .padding(.top, 16)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search contacts...", text: $viewModel.contactsSearchQuery)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !viewModel.contactsSearchQuery.isEmpty {
                    Button(action: { viewModel.contactsSearchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Content: Loading, Error, or Contacts List
            if viewModel.loadingContacts {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading contacts...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else if let error = viewModel.contactsError {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Unable to Access Contacts")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Show settings hint if access denied
                    if error.localizedDescription.contains("Settings") {
                        Text("To grant access: Open Settings → Privacy & Security → Contacts → Enable for this app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            Button(action: { viewModel.openSettings() }) {
                                Text("Open Settings")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                Task { await viewModel.retryFetchContacts() }
                            }) {
                                Text("Retry")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: {
                            Task { await viewModel.retryFetchContacts() }
                        }) {
                            Text("Try Again")
                                .fontWeight(.medium)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if viewModel.filteredContacts.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(viewModel.contactsSearchQuery.isEmpty 
                         ? "No contacts with email addresses found" 
                         : "No contacts match your search")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Contacts list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredContacts) { contact in
                            ContactRowView(
                                contact: contact,
                                isInvited: viewModel.invitedContactIds.contains(contact.id),
                                isLoading: viewModel.loadingContactIds.contains(contact.id),
                                errorMessage: viewModel.failedContactIds[contact.id],
                                onInvite: {
                                    Task { await viewModel.inviteContact(contact) }
                                }
                            )
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Google Contacts Picker View
    
    private var googleContactsPickerView: some View {
        VStack(spacing: 16) {
            // Title (matching RN SDK)
            Text("Add from Google Contacts")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(UIColor.label))
                .padding(.top, 16)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search contacts...", text: $viewModel.googleContactsSearchQuery)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !viewModel.googleContactsSearchQuery.isEmpty {
                    Button(action: { viewModel.googleContactsSearchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Content: Loading, Error, or Contacts List
            if viewModel.loadingGoogleContacts {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Google contacts...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else if let error = viewModel.googleContactsError {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Unable to Access Google Contacts")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task { await viewModel.retryFetchGoogleContacts() }
                    }) {
                        Text("Try Again")
                            .fontWeight(.medium)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if viewModel.filteredGoogleContacts.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(viewModel.googleContactsSearchQuery.isEmpty 
                         ? "No Google contacts with email addresses found" 
                         : "No contacts match your search")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Contacts list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredGoogleContacts) { contact in
                            ContactRowView(
                                contact: contact,
                                isInvited: viewModel.invitedGoogleContactIds.contains(contact.id),
                                isLoading: viewModel.loadingGoogleContactIds.contains(contact.id),
                                errorMessage: viewModel.failedGoogleContactIds[contact.id],
                                onInvite: {
                                    Task { await viewModel.inviteGoogleContact(contact) }
                                }
                            )
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - QR Code View
    
    private var qrCodeView: some View {
        VStack(spacing: 20) {
            // Title (matching RN SDK)
            Text("Scan QR Code to Join")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(UIColor.label))
                .padding(.top, 16)
            
            // QR Code container
            VStack(spacing: 20) {
                if viewModel.loadingQrCode {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Generating QR Code...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 250, height: 250)
                } else if let link = viewModel.shareableLink, let qrImage = generateQRCode(from: link) {
                    // QR Code image
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                    
                    // Helper text (matching RN SDK)
                    Text("Have someone scan this code with their phone camera to receive the invitation link")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                } else {
                    // Error state
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("QR Code not available")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 250, height: 250)
                }
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .task {
            // Fetch shareable link when QR code view appears
            await viewModel.fetchShareableLinkForQrCode()
        }
    }
    
    /// Generate a QR code image from a string using CoreImage
    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up the QR code for better quality
        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        // Convert to UIImage with black QR code on white background
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Success Message View
    
    private var successMessageView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Invitation sent successfully!")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Share Options View

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

// MARK: - Contacts Import View

struct ContactsImportView: View {
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
            
            // Import from Contacts button
            if viewModel.isNativeContactsEnabled {
                ShareButton(
                    icon: .importContacts,
                    title: "Add from Contacts"
                ) {
                    viewModel.selectFromContacts()
                }
            }
            
            // Import from Google Contacts button
            if viewModel.isGoogleContactsEnabled {
                ShareButton(
                    icon: .google,
                    title: "Add from Google Contacts"
                ) {
                    viewModel.selectFromGoogleContacts()
                }
            }
            
            // Add by Email button (navigates to email entry view)
            ShareButton(
                icon: .email,
                title: "Add by Email"
            ) {
                viewModel.currentView = .emailEntry
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Heading View

struct HeadingView: View {
    let block: ElementNode
    
    var body: some View {
        if let text = block.textContent {
            Text(text)
                .font(.headline)
                .padding(.horizontal)
        }
    }
}

// MARK: - Text View

struct TextView: View {
    let block: ElementNode
    
    var body: some View {
        if let text = block.textContent {
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(6) // Approximates lineHeight: 20 with fontSize 14
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal)
        }
    }
}

// MARK: - Share Button Component

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

struct EmailPillView: View {
    let email: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(email)
                .font(.subheadline)
            Button(action: onRemove) {
                VortexIcon(name: .close, size: 14, color: .gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.tertiarySystemBackground))
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

// MARK: - Contact Model

/// Represents a contact with email for invitation
struct VortexContact: Identifiable {
    let id: String
    let name: String
    let email: String
}

/// Errors that can occur when accessing contacts
enum ContactsError: LocalizedError {
    case accessDenied
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Contacts access was denied. Please enable Contacts access in your device Settings to import contacts."
        case .fetchFailed(let error):
            return "Failed to fetch contacts: \(error.localizedDescription)"
        }
    }
}

/// Errors that can occur when accessing Google Contacts
enum GoogleContactsError: LocalizedError {
    case missingClientId
    case signInUnavailable
    case signInCancelled
    case signInFailed(Error)
    case noAccessToken
    case noPresentingViewController
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "Google iOS Client ID not configured. Please provide googleIosClientId parameter."
        case .signInUnavailable:
            return "Google Sign-In is not available. Please ensure GoogleSignIn SDK is properly configured."
        case .signInCancelled:
            return "Google Sign-In was cancelled."
        case .signInFailed(let error):
            return "Google Sign-In failed: \(error.localizedDescription)"
        case .noAccessToken:
            return "Failed to get access token from Google Sign-In."
        case .noPresentingViewController:
            return "Unable to present Google Sign-In. No view controller available."
        case .invalidURL:
            return "Invalid Google People API URL."
        case .invalidResponse:
            return "Invalid response from Google People API."
        case .apiError(let statusCode):
            return "Google People API error: HTTP \(statusCode)"
        case .fetchFailed(let error):
            return "Failed to fetch Google contacts: \(error.localizedDescription)"
        }
    }
}

// MARK: - View State Enum

enum InviteViewState {
    case main
    case emailEntry
    case contactsPicker
    case googleContactsPicker
    case qrCode
}

// MARK: - View Model

@MainActor
class VortexInviteViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var configuration: WidgetConfiguration?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: VortexError?
    @Published var emailInput = ""
    @Published var emails: [String] = []
    @Published var showSuccess = false
    @Published var currentView: InviteViewState = .main
    
    // Share state
    @Published var loadingCopy = false
    @Published var loadingShare = false
    @Published var loadingQrCode = false
    @Published var copySuccess = false
    @Published var shareSuccess = false
    @Published var shareableLink: String?
    
    // Contacts state (native)
    @Published var contacts: [VortexContact] = []
    @Published var loadingContacts = false
    @Published var contactsError: Error?
    @Published var contactsSearchQuery = ""
    @Published var invitedContactIds: Set<String> = []
    @Published var loadingContactIds: Set<String> = []
    @Published var failedContactIds: [String: String] = [:] // contactId -> error message
    
    // Google Contacts state
    @Published var googleContacts: [VortexContact] = []
    @Published var loadingGoogleContacts = false
    @Published var googleContactsError: Error?
    @Published var googleContactsSearchQuery = ""
    @Published var invitedGoogleContactIds: Set<String> = []
    @Published var loadingGoogleContactIds: Set<String> = []
    @Published var failedGoogleContactIds: [String: String] = [:] // contactId -> error message
    
    /// Filtered contacts based on search query
    var filteredContacts: [VortexContact] {
        if contactsSearchQuery.isEmpty {
            return contacts
        }
        let query = contactsSearchQuery.lowercased()
        return contacts.filter { contact in
            contact.name.lowercased().contains(query) ||
            contact.email.lowercased().contains(query)
        }
    }
    
    /// Filtered Google contacts based on search query
    var filteredGoogleContacts: [VortexContact] {
        if googleContactsSearchQuery.isEmpty {
            return googleContacts
        }
        let query = googleContactsSearchQuery.lowercased()
        return googleContacts.filter { contact in
            contact.name.lowercased().contains(query) ||
            contact.email.lowercased().contains(query)
        }
    }
    
    // MARK: - Private Properties
    
    private let componentId: String
    private let jwt: String?
    private let client: VortexClient
    private let group: GroupDTO?
    private let googleIosClientId: String?
    private let onDismiss: (() -> Void)?
    
    // MARK: - Computed Properties
    
    /// Get the form structure from widget configuration
    var formStructure: ElementNode? {
        guard let config = configuration else { return nil }
        
        // Access vortex.components.form property
        if let formProp = config.configuration.props["vortex.components.form"] {
            if case .pageData(let pageData) = formProp.value {
                return pageData.root
            }
        }
        return nil
    }
    
    /// Get share options from configuration
    private var shareOptions: [String] {
        guard let config = configuration,
              let prop = config.configuration.props["vortex.components.share.options"],
              case .array(let values) = prop.value else {
            return []
        }
        return values.compactMap { value in
            if case .string(let str) = value { return str }
            return nil
        }
    }
    
    /// Get enabled components from configuration
    private var enabledComponents: [String] {
        guard let config = configuration,
              let prop = config.configuration.props["vortex.components"],
              case .array(let values) = prop.value else {
            return []
        }
        return values.compactMap { value in
            if case .string(let str) = value { return str }
            return nil
        }
    }
    
    // Share options checks
    var isCopyLinkEnabled: Bool {
        shareOptions.contains("copyLink")
    }
    
    var isNativeShareEnabled: Bool {
        shareOptions.contains("nativeShareSheet")
    }
    
    var isSmsEnabled: Bool {
        shareOptions.contains("sms")
    }
    
    var isQrCodeEnabled: Bool {
        shareOptions.contains("qrCode")
    }
    
    var isLineEnabled: Bool {
        shareOptions.contains("line")
    }
    
    var isEmailShareEnabled: Bool {
        shareOptions.contains("email")
    }
    
    // Component checks
    var isNativeContactsEnabled: Bool {
        enabledComponents.contains("vortex.components.importcontacts.providers.importcontacts")
    }
    
    var isGoogleContactsEnabled: Bool {
        enabledComponents.contains("vortex.components.importcontacts.providers.google")
    }
    
    var isEmailInvitationsEnabled: Bool {
        enabledComponents.contains("vortex.components.emailinvitations")
    }
    
    // MARK: - Initialization
    
    init(
        componentId: String,
        jwt: String?,
        apiBaseURL: URL,
        group: GroupDTO?,
        googleIosClientId: String? = nil,
        onDismiss: (() -> Void)?
    ) {
        self.componentId = componentId
        self.jwt = jwt
        self.group = group
        self.googleIosClientId = googleIosClientId
        self.onDismiss = onDismiss
        self.client = VortexClient(baseURL: apiBaseURL)
    }
    
    // MARK: - Configuration Loading
    
    func loadConfiguration() async {
        guard let jwt = jwt else {
            error = .missingJWT
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            configuration = try await client.getWidgetConfiguration(
                componentId: componentId,
                jwt: jwt
            )
            
            #if DEBUG
            // Debug: Log configuration details
            if let config = configuration {
                print("[VortexSDK] Configuration loaded successfully")
                print("[VortexSDK] Props keys: \(config.configuration.props.keys)")
                
                if let formProp = config.configuration.props["vortex.components.form"] {
                    print("[VortexSDK] Form prop valueType: \(formProp.valueType)")
                    print("[VortexSDK] Form prop value type: \(type(of: formProp.value))")
                    switch formProp.value {
                    case .pageData(let pageData):
                        print("[VortexSDK] Form decoded as pageData, root id: \(pageData.root.id)")
                        print("[VortexSDK] Root children count: \(pageData.root.children?.count ?? 0)")
                    case .object(let obj):
                        print("[VortexSDK] Form decoded as object with keys: \(obj.keys)")
                    default:
                        print("[VortexSDK] Form decoded as: \(formProp.value)")
                    }
                } else {
                    print("[VortexSDK] No vortex.components.form prop found")
                }
                
                if let shareOptions = config.configuration.props["vortex.components.share.options"] {
                    print("[VortexSDK] Share options: \(shareOptions.value)")
                }
                
                if let components = config.configuration.props["vortex.components"] {
                    print("[VortexSDK] Components: \(components.value)")
                }
            }
            #endif
            
            // Pre-fetch shareable link
            await fetchShareableLink()
        } catch let vortexError as VortexError {
            self.error = vortexError
        } catch let otherError {
            self.error = .decodingError(otherError)
        }
        
        isLoading = false
    }
    
    // MARK: - Shareable Link
    
    private func fetchShareableLink() async {
        guard let jwt = jwt,
              let config = configuration else { return }
        
        do {
            var groups: [GroupDTO]? = nil
            if let group = group {
                groups = [group]
            }
            
            let response = try await client.getShareableLink(
                jwt: jwt,
                widgetConfigurationId: config.id,
                groups: groups
            )
            shareableLink = response.data.invitation.shortLink
            print("[VortexSDK] Fetched shareable link: \(response.data.invitation.shortLink)")
        } catch {
            print("[VortexSDK] Failed to fetch shareable link: \(error)")
        }
    }
    
    // MARK: - Share Actions
    
    func copyLink() async {
        loadingCopy = true
        
        // Fetch shareable link if not already cached
        if shareableLink == nil {
            await fetchShareableLink()
        }
        
        guard let link = shareableLink else {
            loadingCopy = false
            print("[VortexSDK] Failed to get shareable link for copy")
            return
        }
        
        // Copy to clipboard
        UIPasteboard.general.string = link
        print("[VortexSDK] Link copied to clipboard: \(link)")
        
        loadingCopy = false
        copySuccess = true
        
        // Reset success state after delay (2 seconds, matching RN SDK)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        copySuccess = false
    }
    
    func shareInvitation() async {
        loadingShare = true
        
        // Fetch shareable link if not already cached
        if shareableLink == nil {
            await fetchShareableLink()
        }
        
        guard let link = shareableLink else {
            loadingShare = false
            print("[VortexSDK] Failed to get shareable link for share")
            return
        }
        
        // Get the share template from configuration (matching RN SDK behavior)
        var shareText = link
        if let config = configuration,
           let templateProp = config.configuration.props["vortex.components.share.template.body"],
           case .string(let template) = templateProp.value {
            // Replace placeholder with actual link
            if template.contains("{{vortex_share_link}}") {
                shareText = template.replacingOccurrences(of: "{{vortex_share_link}}", with: link)
            } else {
                // If no placeholder, append link to template
                shareText = template.hasSuffix(" ") ? "\(template)\(link)" : "\(template) \(link)"
            }
        }
        
        // Get optional subject from configuration
        var shareSubject: String? = nil
        if let config = configuration,
           let subjectProp = config.configuration.props["vortex.components.share.template.subject"],
           case .string(let subject) = subjectProp.value,
           !subject.trimmingCharacters(in: .whitespaces).isEmpty {
            shareSubject = subject.trimmingCharacters(in: .whitespaces)
        }
        
        print("[VortexSDK] Sharing invitation with text: \(shareText)")
        
        // Build activity items - include both text and URL for rich sharing
        var activityItems: [Any] = [shareText]
        if let url = URL(string: link) {
            activityItems.append(url)
        }
        
        // Create the activity view controller
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Set subject for email sharing
        if let subject = shareSubject {
            activityVC.setValue(subject, forKey: "subject")
        }
        
        // Find the topmost view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            loadingShare = false
            print("[VortexSDK] Failed to get root view controller for share sheet")
            return
        }
        
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        // For iPad - configure popover presentation
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Set loading to false before presenting (UI will update)
        loadingShare = false
        
        print("[VortexSDK] Presenting share sheet from topVC: \(type(of: topVC))")
        
        // Present the share sheet from the topmost view controller
        topVC.present(activityVC, animated: true) {
            print("[VortexSDK] Share sheet presented successfully")
        }
        
        // Set success state after a brief delay to allow the sheet to appear
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        shareSuccess = true
        
        // Reset success state after delay (2 seconds, matching RN SDK)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        shareSuccess = false
    }
    
    func shareViaSms() {
        Task {
            // Fetch shareable link if not already cached
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else {
                print("[VortexSDK] Failed to get shareable link for SMS")
                return
            }
            
            // Get the share template from configuration (matching RN SDK behavior)
            var smsBody = link
            if let config = configuration,
               let templateProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = templateProp.value {
                // Replace placeholder with actual link
                if template.contains("{{vortex_share_link}}") {
                    smsBody = template.replacingOccurrences(of: "{{vortex_share_link}}", with: link)
                } else {
                    // If no placeholder, append link to template
                    smsBody = template.hasSuffix(" ") ? "\(template)\(link)" : "\(template) \(link)"
                }
            }
            
            // URL encode the body
            guard let encodedBody = smsBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "sms:?body=\(encodedBody)") else {
                print("[VortexSDK] Failed to create SMS URL")
                return
            }
            
            print("[VortexSDK] Opening SMS with body: \(smsBody)")
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    }
    
    func shareViaLine() {
        guard let link = shareableLink,
              let encodedLink = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://line.me/R/msg/text/?\(encodedLink)") else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    func showQrCode() {
        currentView = .qrCode
    }
    
    /// Fetch shareable link specifically for QR code display
    func fetchShareableLinkForQrCode() async {
        // If we already have a link, no need to fetch again
        if shareableLink != nil {
            return
        }
        
        loadingQrCode = true
        await fetchShareableLink()
        loadingQrCode = false
    }
    
    // MARK: - Contact Actions
    
    func selectFromContacts() {
        currentView = .contactsPicker
        contactsSearchQuery = ""
        
        // Fetch contacts if not already loaded
        if contacts.isEmpty && !loadingContacts {
            Task {
                await fetchContacts()
            }
        }
    }
    
    func selectFromGoogleContacts() {
        currentView = .googleContactsPicker
        googleContactsSearchQuery = ""
        
        // Fetch Google contacts if not already loaded
        if googleContacts.isEmpty && !loadingGoogleContacts {
            Task {
                await fetchGoogleContacts()
            }
        }
    }
    
    /// Fetch contacts from Google using Google Sign-In and People API
    func fetchGoogleContacts() async {
        guard let clientId = googleIosClientId, !clientId.isEmpty else {
            googleContactsError = GoogleContactsError.missingClientId
            print("[VortexSDK] Google iOS Client ID not provided")
            return
        }
        
        loadingGoogleContacts = true
        googleContactsError = nil
        
        do {
            // Import GoogleSignIn dynamically to avoid hard dependency issues
            let accessToken = try await performGoogleSignIn(clientId: clientId)
            
            // Fetch contacts from Google People API
            let contacts = try await fetchContactsFromPeopleAPI(accessToken: accessToken)
            googleContacts = contacts
            print("[VortexSDK] Fetched \(contacts.count) Google contacts with email addresses")
            
        } catch let error as GoogleContactsError {
            googleContactsError = error
            print("[VortexSDK] Google Contacts error: \(error.localizedDescription)")
        } catch {
            googleContactsError = error
            print("[VortexSDK] Failed to fetch Google contacts: \(error)")
        }
        
        loadingGoogleContacts = false
    }
    
    /// Perform Google Sign-In and return access token
    private func performGoogleSignIn(clientId: String) async throws -> String {
        // Use GoogleSignIn SDK
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // Dynamic import of GoogleSignIn
                    guard let GIDSignIn = NSClassFromString("GIDSignIn") as? NSObject.Type,
                          let sharedInstance = GIDSignIn.value(forKey: "sharedInstance") as? NSObject else {
                        // Fallback: try direct import
                        try await self.performGoogleSignInDirect(clientId: clientId, continuation: continuation)
                        return
                    }
                    
                    try await self.performGoogleSignInDirect(clientId: clientId, continuation: continuation)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Direct Google Sign-In implementation
    @MainActor
    private func performGoogleSignInDirect(clientId: String, continuation: CheckedContinuation<String, Error>) async throws {
        // Import GoogleSignIn
        guard let googleSignInModule = NSClassFromString("GIDSignIn") else {
            continuation.resume(throwing: GoogleContactsError.signInUnavailable)
            return
        }
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            continuation.resume(throwing: GoogleContactsError.noPresentingViewController)
            return
        }
        
        // Find topmost view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        // Use GoogleSignIn directly via the imported module
        performGoogleSignInWithSDK(clientId: clientId, presentingVC: topVC, continuation: continuation)
    }
    
    /// Perform sign-in using GoogleSignIn SDK
    @MainActor
    private func performGoogleSignInWithSDK(clientId: String, presentingVC: UIViewController, continuation: CheckedContinuation<String, Error>) {
        // Import and use GoogleSignIn
        Task {
            do {
                let accessToken = try await signInWithGoogle(clientId: clientId, presentingVC: presentingVC)
                continuation.resume(returning: accessToken)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Sign in with Google and get access token
    @MainActor
    private func signInWithGoogle(clientId: String, presentingVC: UIViewController) async throws -> String {
        // Configure GoogleSignIn with the client ID
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        
        // Define the contacts scope
        let contactsScope = "https://www.googleapis.com/auth/contacts.readonly"
        
        // Try silent sign-in first (uses cached credentials)
        do {
            if GIDSignIn.sharedInstance.hasPreviousSignIn() {
                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                
                // Check if we have the contacts scope
                let grantedScopes = user.grantedScopes ?? []
                if grantedScopes.contains(contactsScope) {
                    // Refresh tokens if needed
                    try await user.refreshTokensIfNeeded()
                    guard let accessToken = user.accessToken.tokenString as String? else {
                        throw GoogleContactsError.noAccessToken
                    }
                    print("[VortexSDK] Google silent sign-in success")
                    return accessToken
                } else {
                    // Need to request additional scope - addScopes is on GIDGoogleUser in v7.x
                    let result = try await user.addScopes([contactsScope], presenting: presentingVC)
                    guard let accessToken = result.user.accessToken.tokenString as String? else {
                        throw GoogleContactsError.noAccessToken
                    }
                    print("[VortexSDK] Google scope added successfully")
                    return accessToken
                }
            }
        } catch {
            print("[VortexSDK] Silent sign-in failed, trying interactive: \(error)")
        }
        
        // Interactive sign-in
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingVC,
                hint: nil,
                additionalScopes: [contactsScope]
            )
            
            guard let accessToken = result.user.accessToken.tokenString as String? else {
                throw GoogleContactsError.noAccessToken
            }
            
            print("[VortexSDK] Google interactive sign-in success")
            return accessToken
            
        } catch let error as GIDSignInError {
            switch error.code {
            case .canceled:
                throw GoogleContactsError.signInCancelled
            case .hasNoAuthInKeychain:
                throw GoogleContactsError.signInFailed(error)
            default:
                throw GoogleContactsError.signInFailed(error)
            }
        } catch {
            throw GoogleContactsError.signInFailed(error)
        }
    }
    
    /// Fetch contacts from Google People API
    private func fetchContactsFromPeopleAPI(accessToken: String) async throws -> [VortexContact] {
        let urlString = "https://people.googleapis.com/v1/people/me/connections?personFields=names,emailAddresses&pageSize=1000"
        guard let url = URL(string: urlString) else {
            throw GoogleContactsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleContactsError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GoogleContactsError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let connections = json?["connections"] as? [[String: Any]] ?? []
        
        var contactMap: [String: VortexContact] = [:]
        
        for person in connections {
            guard let emailAddresses = person["emailAddresses"] as? [[String: Any]] else { continue }
            let resourceName = person["resourceName"] as? String ?? UUID().uuidString
            let names = person["names"] as? [[String: Any]]
            let displayName = names?.first?["displayName"] as? String
            
            for emailObj in emailAddresses {
                guard let email = emailObj["value"] as? String else { continue }
                let key = "\(resourceName)-\(email)"
                
                if contactMap[key] == nil {
                    let name = displayName ?? inferNameFromEmail(email)
                    contactMap[key] = VortexContact(id: key, name: name, email: email)
                }
            }
        }
        
        return Array(contactMap.values).sorted { $0.name < $1.name }
    }
    
    /// Invite a Google contact by sending an invitation to their email
    func inviteGoogleContact(_ contact: VortexContact) async {
        guard let jwt = jwt,
              let config = configuration else {
            let errorMsg = "Cannot invite contact: missing JWT or configuration"
            print("[VortexSDK] \(errorMsg)")
            failedGoogleContactIds[contact.id] = errorMsg
            return
        }
        
        // Clear any previous error for this contact
        failedGoogleContactIds.removeValue(forKey: contact.id)
        
        // Add to loading set
        loadingGoogleContactIds.insert(contact.id)
        
        do {
            // Build payload matching RN SDK format
            let payload: [String: Any] = [
                "invitee_email": ["value": contact.email, "type": "email"],
                "invitee_name": ["value": contact.name, "type": "string"]
            ]
            
            var groups: [GroupDTO]? = nil
            if let group = group {
                groups = [group]
            }
            
            _ = try await client.createInvitation(
                jwt: jwt,
                widgetConfigurationId: config.id,
                payload: payload,
                groups: groups
            )
            
            // Mark as invited
            invitedGoogleContactIds.insert(contact.id)
            print("[VortexSDK] Successfully invited Google contact: \(contact.email)")
            
        } catch {
            // Extract meaningful error message
            let errorMessage: String
            if let vortexError = error as? VortexError {
                errorMessage = vortexError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            
            // Log detailed error to console
            print("[VortexSDK] ❌ Failed to invite Google contact \(contact.email): \(error)")
            print("[VortexSDK] Error details: \(errorMessage)")
            
            // Store error for UI display
            failedGoogleContactIds[contact.id] = "Failed to send invitation"
        }
        
        // Remove from loading set
        loadingGoogleContactIds.remove(contact.id)
    }
    
    /// Retry fetching Google contacts
    func retryFetchGoogleContacts() async {
        googleContacts = []
        googleContactsError = nil
        await fetchGoogleContacts()
    }
    
    /// Fetch contacts from the device using iOS Contacts framework
    func fetchContacts() async {
        loadingContacts = true
        contactsError = nil
        
        do {
            let store = CNContactStore()
            
            // Request permission
            let status = CNContactStore.authorizationStatus(for: .contacts)
            
            switch status {
            case .notDetermined:
                // Request access
                let granted = try await store.requestAccess(for: .contacts)
                if !granted {
                    throw ContactsError.accessDenied
                }
            case .denied, .restricted:
                throw ContactsError.accessDenied
            case .authorized:
                break
            @unknown default:
                throw ContactsError.accessDenied
            }
            
            // Fetch contacts with email addresses
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor
            ]
            
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            request.sortOrder = .givenName
            
            var fetchedContacts: [VortexContact] = []
            
            try store.enumerateContacts(with: request) { contact, _ in
                // Only include contacts with email addresses
                for email in contact.emailAddresses {
                    let emailString = email.value as String
                    let name = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    let displayName = name.isEmpty ? self.inferNameFromEmail(emailString) : name
                    
                    // Create unique ID combining contact ID and email
                    let uniqueId = "\(contact.identifier)-\(emailString)"
                    
                    fetchedContacts.append(VortexContact(
                        id: uniqueId,
                        name: displayName,
                        email: emailString
                    ))
                }
            }
            
            contacts = fetchedContacts
            print("[VortexSDK] Fetched \(fetchedContacts.count) contacts with email addresses")
            
        } catch let error as ContactsError {
            contactsError = error
            print("[VortexSDK] Contacts error: \(error.localizedDescription)")
        } catch {
            contactsError = error
            print("[VortexSDK] Failed to fetch contacts: \(error)")
        }
        
        loadingContacts = false
    }
    
    /// Infer a display name from an email address
    private func inferNameFromEmail(_ email: String) -> String {
        guard let localPart = email.split(separator: "@").first else {
            return email
        }
        
        // Replace common separators with spaces and capitalize
        let name = String(localPart)
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        
        return name.isEmpty ? email : name
    }
    
    /// Invite a contact by sending an invitation to their email
    func inviteContact(_ contact: VortexContact) async {
        guard let jwt = jwt,
              let config = configuration else {
            let errorMsg = "Cannot invite contact: missing JWT or configuration"
            print("[VortexSDK] \(errorMsg)")
            failedContactIds[contact.id] = errorMsg
            return
        }
        
        // Clear any previous error for this contact
        failedContactIds.removeValue(forKey: contact.id)
        
        // Add to loading set
        loadingContactIds.insert(contact.id)
        
        do {
            // Build payload matching RN SDK format
            let payload: [String: Any] = [
                "invitee_email": ["value": contact.email, "type": "email"],
                "invitee_name": ["value": contact.name, "type": "string"]
            ]
            
            var groups: [GroupDTO]? = nil
            if let group = group {
                groups = [group]
            }
            
            _ = try await client.createInvitation(
                jwt: jwt,
                widgetConfigurationId: config.id,
                payload: payload,
                groups: groups
            )
            
            // Mark as invited
            invitedContactIds.insert(contact.id)
            print("[VortexSDK] Successfully invited contact: \(contact.email)")
            
        } catch {
            // Extract meaningful error message
            let errorMessage: String
            if let vortexError = error as? VortexError {
                errorMessage = vortexError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            
            // Log detailed error to console
            print("[VortexSDK] ❌ Failed to invite contact \(contact.email): \(error)")
            print("[VortexSDK] Error details: \(errorMessage)")
            
            // Store error for UI display
            failedContactIds[contact.id] = "Failed to send invitation"
        }
        
        // Remove from loading set
        loadingContactIds.remove(contact.id)
    }
    
    /// Retry fetching contacts (e.g., after user grants permission in Settings)
    func retryFetchContacts() async {
        contacts = []
        contactsError = nil
        await fetchContacts()
    }
    
    /// Open iOS Settings app for the user to grant contacts permission
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Email Actions
    
    func addEmailFromInput() {
        let trimmed = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isValidEmail(trimmed), !emails.contains(trimmed) else {
            return
        }
        emails.append(trimmed)
        emailInput = ""
    }
    
    func removeEmail(_ email: String) {
        emails.removeAll { $0 == email }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Whether the current email input contains a valid email address
    var hasValidEmailInput: Bool {
        let trimmed = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && isValidEmail(trimmed) && !emails.contains(trimmed)
    }
    
    /// Whether the send invitation button should be enabled
    /// True if there are emails in the list OR the current input is a valid email
    var canSendInvitation: Bool {
        !emails.isEmpty || hasValidEmailInput
    }
    
    // MARK: - Send Invitation
    
    func sendInvitation() async {
        guard let jwt = jwt,
              let config = configuration,
              !emails.isEmpty else {
            return
        }
        
        isSending = true
        showSuccess = false
        
        do {
            // Send invitation for each email
            for email in emails {
                let payload: [String: Any] = [
                    "invitee_email": ["value": email, "type": "email"]
                ]
                
                var groups: [GroupDTO]? = nil
                if let group = group {
                    groups = [group]
                }
                
                _ = try await client.createInvitation(
                    jwt: jwt,
                    widgetConfigurationId: config.id,
                    payload: payload,
                    groups: groups
                )
            }
            
            showSuccess = true
            emails = []
            emailInput = ""
            currentView = .main
            
            // Hide success message after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showSuccess = false
            
        } catch let vortexError as VortexError {
            self.error = vortexError
        } catch let otherError {
            self.error = .encodingError(otherError)
        }
        
        isSending = false
    }
    
    // MARK: - Dismiss
    
    func dismiss() {
        onDismiss?()
    }
}

// MARK: - Helper Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - AttributeValue Extension

extension AttributeValue {
    /// Get the string value if this is a string attribute
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .bool(let value):
            return String(value)
        }
    }
}
