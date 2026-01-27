import SwiftUI
import MessageUI

// MARK: - Simulator Detection

/// Check if running on iOS Simulator
private var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
}

// MARK: - Fake SMS Data Model (for Simulator)
/// Data model for the fake SMS preview, used with .sheet(item:) to avoid race conditions
private struct FakeSMSData: Identifiable {
    let id = UUID()
    let recipient: String
    let recipientName: String
    let messageBody: String
}

// MARK: - Fake SMS Preview View (for Simulator)
/// A fake SMS composer view that mimics the native iOS Messages compose screen.
/// Used on the iOS Simulator where MFMessageComposeViewController.canSendText() returns false
/// and the sms: URL scheme has known issues with displaying recipients.
private struct FakeSMSPreviewView: View {
    let data: FakeSMSData
    let onCancel: () -> Void
    let onSend: () -> Void
    
    var recipient: String { data.recipient }
    var recipientName: String { data.recipientName }
    var messageBody: String { data.messageBody }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Recipient field
                HStack {
                    Text("To:")
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                    
                    // Recipient pill
                    Text(recipientName)
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                // Message area
                ScrollView {
                    VStack(alignment: .trailing, spacing: 8) {
                        Spacer()
                            .frame(height: 20)
                        
                        // Message bubble (right-aligned, like sent messages)
                        HStack {
                            Spacer()
                            Text(messageBody)
                                .font(.system(size: 16))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(18)
                                .frame(maxWidth: 280, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGroupedBackground))
                
                Divider()
                
                // Input bar (disabled, just for visual)
                HStack(spacing: 12) {
                    // Camera button
                    Image(systemName: "camera.fill")
                        .foregroundColor(.gray)
                        .frame(width: 36, height: 36)
                    
                    // Text field (disabled)
                    HStack {
                        Text("iMessage")
                            .foregroundColor(.gray.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(20)
                    
                    // Send button
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
                
                // Simulator notice
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("Simulator Preview - SMS not actually sent")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("New Message")
                            .font(.headline)
                        Text(recipient)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - SMS Composer Helper

/// Helper class to present MFMessageComposeViewController from SwiftUI.
/// MFMessageComposeViewController must be presented from a UIViewController, not as a SwiftUI sheet.
/// This class is an ObservableObject so it can be properly retained by SwiftUI via @StateObject.
class SMSComposerHelper: NSObject, ObservableObject, MFMessageComposeViewControllerDelegate {
    private var onDismiss: ((MessageComposeResult) -> Void)?
    
    /// Presents the SMS composer from the topmost view controller.
    /// Caller must check `MFMessageComposeViewController.canSendText()` before calling.
    /// - Parameters:
    ///   - recipients: Array of phone numbers
    ///   - body: Pre-filled message body (NOT URL-encoded - will be used directly)
    ///   - onDismiss: Callback with the result when composer is dismissed
    func present(recipients: [String], body: String, onDismiss: @escaping (MessageComposeResult) -> Void) {
        // NOTE: canSendText() check is done by the caller (handleInvite) - not here.
        // This avoids duplicate checks and keeps fallback logic in one place.
        
        self.onDismiss = onDismiss
        
        let composer = MFMessageComposeViewController()
        composer.recipients = recipients
        composer.body = body  // Plain text, no URL encoding needed
        composer.messageComposeDelegate = self
        
        // Find the topmost view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            onDismiss(.failed)
            return
        }
        
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        // Present the composer - this will crash if canSendText() is false!
        topVC.present(composer, animated: true)
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true) { [weak self] in
            self?.onDismiss?(result)
            self?.onDismiss = nil
        }
    }
}

/// View that displays a list of contacts that can be invited via SMS.
/// Shows an "Invite your contacts" entry that navigates to a contacts list with search and invite buttons.
struct InviteContactsView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    /// Track if showing the contacts list view
    @State private var showContactsList = false
    
    /// Search query for filtering contacts
    @State private var searchQuery = ""
    
    /// Set of contact IDs that have been invited
    @State private var invitedContacts: Set<String> = []
    
    /// Contact ID currently being invited (for loading state)
    @State private var actionInProgress: String? = nil
    
    /// Helper for presenting the in-app SMS composer
    /// Must be @StateObject to properly retain the delegate reference
    @StateObject private var smsComposerHelper = SMSComposerHelper()
    
    /// Pending invite data for use after SMS composer dismisses
    @State private var pendingInviteContact: InviteContactsContact? = nil
    @State private var pendingShortLink: String? = nil
    
    /// State for showing fake SMS preview on simulator
    @State private var fakeSMSData: FakeSMSData?
    
    /// Sorted contacts from config
    private var contacts: [InviteContactsContact] {
        guard let config = viewModel.inviteContactsConfig else { return [] }
        return config.contacts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Filtered contacts based on search query
    private var filteredContacts: [InviteContactsContact] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return contacts
        }
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        return contacts.filter { contact in
            contact.name.lowercased().contains(query) ||
            contact.phoneNumber.contains(query)
        }
    }
    
    /// Text for the "Invite your contacts" entry (from widget configuration)
    private var inviteYourContactsText: String {
        block.settings?.customizations?["inviteYourContactsText"]?.textContent ?? "Invite your contacts"
    }
    
    /// Text for the "Invite" button (from widget configuration)
    private var inviteButtonText: String {
        block.settings?.customizations?["inviteButton"]?.textContent ?? "Invite"
    }
    
    /// Empty state message (from widget configuration)
    private var emptyStateMessage: String {
        block.settings?.customizations?["emptyStateMessage"]?.textContent ?? "No contacts to invite"
    }
    
    // MARK: - Theme Colors
    
    private var foregroundColor: Color {
        viewModel.themeForeground ?? Color(red: 0x33/255, green: 0x41/255, blue: 0x53/255)
    }
    
    private var secondaryForegroundColor: Color {
        viewModel.themeSecondaryForeground ?? Color(red: 0x35/255, green: 0x3e/255, blue: 0x5c/255)
    }
    
    private var borderColor: Color {
        viewModel.themeBorder ?? Color(UIColor.separator)
    }
    
    var body: some View {
        Group {
            // If no config or empty contacts, render nothing
            if viewModel.inviteContactsConfig == nil || contacts.isEmpty {
                EmptyView()
            } else if showContactsList {
                // Contacts list view
                contactsListView
            } else {
                // Main view: "Invite your contacts" entry
                inviteContactsEntryView
            }
        }
        .sheet(item: $fakeSMSData) { smsData in
            FakeSMSPreviewView(
                data: smsData,
                onCancel: {
                    // User cancelled - don't mark as invited
                    fakeSMSData = nil
                    pendingInviteContact = nil
                    pendingShortLink = nil
                },
                onSend: {
                    // User "sent" - mark as invited and call callback
                    fakeSMSData = nil
                    if let contact = pendingInviteContact, let shortLink = pendingShortLink {
                        invitedContacts.insert(contact.id)
                        viewModel.inviteContactsConfig?.onInvitationSent?(contact, shortLink)
                        // Fire internal event for other subcomponents to observe
                        viewModel.fireInvitationSentEvent(source: .inviteContacts, shortLink: shortLink)
                    }
                    pendingInviteContact = nil
                    pendingShortLink = nil
                }
            )
        }
    }
    
    // MARK: - Invite Contacts Entry View
    
    private var inviteContactsEntryView: some View {
        Button(action: {
            showContactsList = true
            viewModel.inviteContactsConfig?.onNavigateToContacts?()
        }) {
            HStack {
                HStack(spacing: 8) {
                    Text(inviteYourContactsText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(foregroundColor)
                    
                    Text("\(contacts.count)")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryForegroundColor)
                        .opacity(0.7)
                }
                
                Spacer()
                
                Text("›")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(secondaryForegroundColor)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    // MARK: - Contacts List View
    
    private var contactsListView: some View {
        LazyVStack(spacing: 0) {
            // Back header with search
            backHeaderView
            
            // Search box
            searchBoxView
            
            if filteredContacts.isEmpty {
                Text(searchQuery.isEmpty ? emptyStateMessage : "No contacts match your search")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryForegroundColor)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(filteredContacts) { contact in
                    InviteContactsItemView(
                        contact: contact,
                        block: block,
                        viewModel: viewModel,
                        inviteButtonText: inviteButtonText,
                        isInvited: invitedContacts.contains(contact.id),
                        isLoading: actionInProgress == contact.id,
                        onInvite: { handleInvite(contact) }
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    // MARK: - Back Header View
    
    private var backButtonText: String {
        block.settings?.customizations?["backButton"]?.textContent ?? "Back"
    }
    
    private var backHeaderView: some View {
        Button(action: {
            showContactsList = false
            searchQuery = ""
            viewModel.inviteContactsConfig?.onNavigateBack?()
        }) {
            HStack(spacing: 4) {
                Text("‹")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(secondaryForegroundColor)
                
                Text(backButtonText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foregroundColor)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
    
    // MARK: - Search Box View
    
    private var searchBoxView: some View {
        HStack {
            TextField("Search contacts...", text: $searchQuery)
                .font(.system(size: 16))
                .foregroundColor(foregroundColor)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.bottom, 12)
    }
    
    // MARK: - Invite Handler
    
    private func handleInvite(_ contact: InviteContactsContact) {
        actionInProgress = contact.id
        
        Task {
            // Create SMS invitation and get short link
            let shortLink = await viewModel.createSmsInvitation(phoneNumber: contact.phoneNumber, contactName: contact.name)
            
            if let shortLink = shortLink {
                // Get SMS message template and replace placeholder with actual link
                let smsMessage = viewModel.getSmsMessageTemplate()
                let message = smsMessage.replacingOccurrences(of: "{{link}}", with: shortLink)
                    .replacingOccurrences(of: "{{vortex_share_link}}", with: shortLink)
                
                // Store pending invite data for use after SMS composer dismisses
                pendingInviteContact = contact
                pendingShortLink = shortLink
                
                // Clear loading state before presenting SMS composer
                // The spinner should stop once we're ready to show the composer
                actionInProgress = nil
                
                // Check if device can send SMS using in-app composer
                if MFMessageComposeViewController.canSendText() {
                    // Use in-app SMS composer - present directly from UIViewController
                    // The message body is plain text, NOT URL-encoded
                    await MainActor.run {
                        smsComposerHelper.present(
                            recipients: [contact.phoneNumber],
                            body: message
                        ) { [self] result in
                            handleSMSComposerResult(result)
                        }
                    }
                } else if isSimulator {
                    // On simulator, show fake SMS preview instead of URL scheme
                    // (Messages app on simulator has known issues with sms: URL scheme)
                    // Using .sheet(item:) pattern to avoid race condition where sheet
                    // could display before state variables are updated
                    await MainActor.run {
                        fakeSMSData = FakeSMSData(
                            recipient: contact.phoneNumber,
                            recipientName: contact.name,
                            messageBody: message
                        )
                    }
                } else {
                    // Fallback to URL scheme (opens Messages app externally)
                    // Strip formatting from phone number (keep only digits and +)
                    let cleanPhoneNumber = contact.phoneNumber.filter { $0.isNumber || $0 == "+" }

                    // Build the SMS URL using URLComponents to avoid encoding issues
                    // The phone number goes in the path (after sms:), NOT the host (after sms://)
                    // Correct format: sms:+15551234567?body=message
                    // Wrong format:   sms://+15551234567?body=message (// makes phone number the host)
                    var components = URLComponents()
                    components.scheme = "sms"
                    components.path = cleanPhoneNumber  // e.g. "+15551234567"
                    components.queryItems = [
                        URLQueryItem(name: "body", value: message)  // URLComponents handles encoding
                    ]
                    
                    if let url = components.url {
                        print("Opening \(url)")
                        await MainActor.run {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    // Mark contact as invited and call callback immediately for fallback
                    // (We can't detect if user actually sent the message via URL scheme)
                    invitedContacts.insert(contact.id)
                    viewModel.inviteContactsConfig?.onInvitationSent?(contact, shortLink)
                    // Fire internal event for other subcomponents to observe
                    viewModel.fireInvitationSentEvent(source: .inviteContacts, shortLink: shortLink)
                    
                    // Clear pending state
                    pendingInviteContact = nil
                    pendingShortLink = nil
                }
            } else {
                actionInProgress = nil
            }
        }
    }
    
    // MARK: - SMS Composer Result Handler
    
    private func handleSMSComposerResult(_ result: MessageComposeResult) {
        // Handle the result from the in-app SMS composer
        if let contact = pendingInviteContact, let shortLink = pendingShortLink {
            switch result {
            case .sent:
                // User sent the message - mark as invited and call callback
                invitedContacts.insert(contact.id)
                viewModel.inviteContactsConfig?.onInvitationSent?(contact, shortLink)
                // Fire internal event for other subcomponents to observe
                viewModel.fireInvitationSentEvent(source: .inviteContacts, shortLink: shortLink)
            case .cancelled:
                // User cancelled - don't mark as invited
                break
            case .failed:
                // Message failed to send - don't mark as invited
                break
            @unknown default:
                break
            }
        }
        
        // Clear pending state
        pendingInviteContact = nil
        pendingShortLink = nil
    }
}

// MARK: - Contact Item View

private struct InviteContactsItemView: View {
    let contact: InviteContactsContact
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    let inviteButtonText: String
    let isInvited: Bool
    let isLoading: Bool
    let onInvite: () -> Void
    
    // MARK: - Theme Color Helpers
    
    /// Get a theme option value from block.theme.options by key
    private func getBlockThemeValue(_ key: String) -> String? {
        guard let options = block.theme?.options else { return nil }
        return options.first { $0.key == key }?.value
    }
    
    /// Theme colors with fallback chain: block.theme.options > vortex.theme > hardcoded defaults
    private var defaultColors: (
        primaryBackground: Color,
        primaryForeground: Color,
        secondaryBackground: Color,
        secondaryForeground: Color,
        foreground: Color,
        border: Color
    ) {
        (
            primaryBackground: viewModel.themePrimaryBackground ?? Color(red: 0x62/255, green: 0x91/255, blue: 0xd5/255),
            primaryForeground: viewModel.themePrimaryForeground ?? .white,
            secondaryBackground: viewModel.themeSecondaryBackground ?? Color(UIColor.tertiarySystemBackground),
            secondaryForeground: viewModel.themeSecondaryForeground ?? Color(red: 0x35/255, green: 0x3e/255, blue: 0x5c/255),
            foreground: viewModel.themeForeground ?? Color(red: 0x33/255, green: 0x41/255, blue: 0x53/255),
            border: viewModel.themeBorder ?? Color(UIColor.separator)
        )
    }
    
    // MARK: - Avatar Styles
    
    private var avatarBackgroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-avatar-background"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryBackground
    }
    
    private var avatarForegroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-avatar-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryForeground
    }
    
    // MARK: - Contact Name Styles
    
    private var contactNameColor: Color {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-name-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.foreground
    }
    
    // MARK: - Contact Phone Styles
    
    private var contactPhoneColor: Color {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-subtitle-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.secondaryForeground
    }
    
    // MARK: - Invite Button Styles
    
    private var inviteButtonBackgroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-invite-button-background") {
            // Skip gradient values - handled by inviteButtonGradient
            if value.contains("linear-gradient") {
                return .clear
            }
            if let color = Color(hex: value) {
                return color
            }
        }
        return defaultColors.primaryBackground
    }
    
    private var inviteButtonGradient: LinearGradient? {
        guard let value = getBlockThemeValue("--vrtx-invite-contacts-invite-button-background"),
              value.contains("linear-gradient") else {
            return nil
        }
        
        let colors = parseGradientColors(value)
        guard colors.count >= 2 else { return nil }
        
        // Parse angle (default 90deg = horizontal left to right)
        let angle = parseGradientAngle(value)
        let (start, end) = gradientPoints(for: angle)
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: start,
            endPoint: end
        )
    }
    
    private var inviteButtonForegroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-invite-button-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryForeground
    }
    
    private var inviteButtonBorderColor: Color {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-invite-button-border") {
            if let color = parseBorderColor(value) {
                return color
            }
        }
        return .clear
    }
    
    private var inviteButtonBorderWidth: CGFloat {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-invite-button-border") {
            return parseBorderWidth(value)
        }
        return 0
    }
    
    private var inviteButtonCornerRadius: CGFloat {
        if let value = getBlockThemeValue("--vrtx-invite-contacts-invite-button-border-radius"),
           let radius = Double(value.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(radius)
        }
        return 8
    }
    
    // MARK: - Gradient Parsing Helpers
    
    private func parseGradientColors(_ gradientString: String) -> [Color] {
        let colorPattern = #"(rgba?\([^)]+\)|#[0-9a-fA-F]{3,8})\s+\d+%"#
        guard let colorRegex = try? NSRegularExpression(pattern: colorPattern, options: .caseInsensitive) else {
            return []
        }
        
        let matches = colorRegex.matches(in: gradientString, range: NSRange(gradientString.startIndex..., in: gradientString))
        
        return matches.compactMap { match -> Color? in
            guard match.numberOfRanges >= 2,
                  let colorRange = Range(match.range(at: 1), in: gradientString) else {
                return nil
            }
            let colorStr = String(gradientString[colorRange]).trimmingCharacters(in: .whitespaces)
            return Color(hex: colorStr)
        }
    }
    
    private func parseGradientAngle(_ gradientString: String) -> Double {
        let anglePattern = #"linear-gradient\s*\(\s*(\d+)deg"#
        guard let regex = try? NSRegularExpression(pattern: anglePattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: gradientString, range: NSRange(gradientString.startIndex..., in: gradientString)),
              match.numberOfRanges >= 2,
              let angleRange = Range(match.range(at: 1), in: gradientString),
              let angle = Double(gradientString[angleRange]) else {
            return 90 // Default to horizontal
        }
        return angle
    }
    
    private func gradientPoints(for angle: Double) -> (UnitPoint, UnitPoint) {
        // CSS angles: 0deg = bottom to top, 90deg = left to right
        switch angle {
        case 0:
            return (.bottom, .top)
        case 45:
            return (.bottomLeading, .topTrailing)
        case 90:
            return (.leading, .trailing)
        case 135:
            return (.topLeading, .bottomTrailing)
        case 180:
            return (.top, .bottom)
        case 225:
            return (.topTrailing, .bottomLeading)
        case 270:
            return (.trailing, .leading)
        case 315:
            return (.bottomTrailing, .topLeading)
        default:
            return (.leading, .trailing)
        }
    }
    
    // MARK: - Border Parsing Helpers
    
    private func parseBorderColor(_ borderStr: String) -> Color? {
        let pattern = #"(\d+)px\s+(\w+)\s+(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: borderStr, range: NSRange(borderStr.startIndex..., in: borderStr)),
              match.numberOfRanges >= 4 else {
            return nil
        }
        
        if let colorRange = Range(match.range(at: 3), in: borderStr) {
            let colorStr = String(borderStr[colorRange]).trimmingCharacters(in: .whitespaces)
            return Color(hex: colorStr)
        }
        return nil
    }
    
    private func parseBorderWidth(_ borderStr: String) -> CGFloat {
        let pattern = #"(\d+)px"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: borderStr, range: NSRange(borderStr.startIndex..., in: borderStr)),
              match.numberOfRanges >= 2,
              let widthRange = Range(match.range(at: 1), in: borderStr),
              let width = Double(borderStr[widthRange]) else {
            return 1
        }
        return CGFloat(width)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Avatar
            avatarView
            
            // Contact info
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(contactNameColor)
                    .lineLimit(1)
                
                Text(contact.phoneNumber)
                    .font(.system(size: 13))
                    .foregroundColor(contactPhoneColor)
                    .lineLimit(1)
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            
            Spacer()
            
            // Action button
            actionButton
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private var avatarView: some View {
        if let avatarUrl = contact.avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                default:
                    initialsView
                }
            }
        } else {
            initialsView
        }
    }
    
    private var initialsView: some View {
        let initials = contact.name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
        
        return Text(initials)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(avatarForegroundColor)
            .frame(width: 44, height: 44)
            .background(avatarBackgroundColor)
            .clipShape(Circle())
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        Button(action: onInvite) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text(isInvited ? "✓" : inviteButtonText)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: 80)
            .foregroundColor(inviteButtonForegroundColor)
            .background(
                Group {
                    if let gradient = inviteButtonGradient {
                        gradient
                    } else {
                        inviteButtonBackgroundColor
                    }
                }
            )
            .cornerRadius(inviteButtonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: inviteButtonCornerRadius)
                    .stroke(inviteButtonBorderColor, lineWidth: inviteButtonBorderWidth)
            )
            .opacity(isInvited ? 0.7 : 1.0)
        }
        .disabled(isLoading)
    }
}
