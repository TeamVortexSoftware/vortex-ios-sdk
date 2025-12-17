import SwiftUI
import UIKit

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
    ///   - onDismiss: Callback when the view is dismissed
    public init(
        componentId: String,
        jwt: String?,
        apiBaseURL: URL = URL(string: "https://client-api.vortexsoftware.com")!,
        group: GroupDTO? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: VortexInviteViewModel(
            componentId: componentId,
            jwt: jwt,
            apiBaseURL: apiBaseURL,
            group: group,
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
                    .autocapitalization(.none)
                    .onSubmit {
                        viewModel.addEmailFromInput()
                    }
                
                Text("Press return to add each email")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Send button
            Button(action: {
                Task {
                    await viewModel.sendInvitation()
                }
            }) {
                HStack {
                    if viewModel.isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Invitation\(viewModel.emails.count > 1 ? "s" : "")")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.emails.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(viewModel.isSending || viewModel.emails.isEmpty)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Contacts Picker View
    
    private var contactsPickerView: some View {
        VStack(spacing: 16) {
            Text("Contacts picker coming soon")
                .foregroundColor(.secondary)
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

// MARK: - View State Enum

enum InviteViewState {
    case main
    case emailEntry
    case contactsPicker
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
    
    // MARK: - Private Properties
    
    private let componentId: String
    private let jwt: String?
    private let client: VortexClient
    private let group: GroupDTO?
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
        onDismiss: (() -> Void)?
    ) {
        self.componentId = componentId
        self.jwt = jwt
        self.group = group
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
        // TODO: Implement native contacts picker
    }
    
    func selectFromGoogleContacts() {
        // TODO: Implement Google contacts integration
        print("[VortexSDK] Google contacts integration not yet implemented")
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
