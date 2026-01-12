import SwiftUI
import Contacts
import GoogleSignIn

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
    
    // Form field values for custom form elements
    @Published var formFieldValues: [String: String] = [:]
    
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
    
    // Analytics
    private let analyticsClient: VortexAnalyticsClient
    private let sessionId: String
    private let onEvent: ((VortexAnalyticsEvent) -> Void)?
    private let segmentation: [String: Any]?
    private var widgetRenderTracked = false
    private var formRenderTime: Date?
    private var deploymentId: String?
    
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
    
    /// Extract theme color map from vortex.theme configuration
    /// Returns a dictionary mapping CSS variable names (e.g., "--color-surface-background") to color values
    private var themeColorMap: [String: String] {
        guard let config = configuration,
              let themeProp = config.configuration.props["vortex.theme"],
              case .theme(let theme) = themeProp.value,
              let options = theme.options else {
            return [:]
        }
        
        var colorMap: [String: String] = [:]
        for option in options {
            colorMap[option.key] = option.value
        }
        return colorMap
    }
    
    /// Get the surface background color for form container background
    /// Priority: 1) Root element's inline style, 2) Theme's --color-surface-background
    var surfaceBackgroundColor: Color? {
        // First check root element's inline style (e.g., style.background: "#111323")
        if let rootStyle = formStructure?.style,
           let backgroundValue = rootStyle["background"],
           backgroundValue != "transparent" {
            // Handle both solid colors and gradients
            if let bgStyle = BackgroundStyle.parse(backgroundValue) {
                switch bgStyle {
                case .solid(let color):
                    return color
                case .gradient:
                    // For gradients, extract the first color as fallback
                    if let color = Color(hex: backgroundValue) {
                        return color
                    }
                }
            }
            // Try direct hex parsing
            if let color = Color(hex: backgroundValue) {
                return color
            }
        }
        
        // Fallback to theme's --color-surface-background
        guard let hexColor = themeColorMap["--color-surface-background"],
              hexColor != "transparent" else {
            return nil
        }
        return Color(hex: hexColor)
    }
    
    /// Get the surface foreground color from theme (for heading text)
    var surfaceForegroundColor: Color? {
        guard let hexColor = themeColorMap["--color-surface-foreground"] else {
            return nil
        }
        return Color(hex: hexColor)
    }
    
    /// Get share options from configuration (ordered array)
    var shareOptions: [String] {
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
    
    var isTwitterEnabled: Bool {
        shareOptions.contains("twitterDms")
    }
    
    var isInstagramEnabled: Bool {
        shareOptions.contains("instagramDms")
    }
    
    var isWhatsAppEnabled: Bool {
        shareOptions.contains("whatsApp")
    }
    
    var isFacebookMessengerEnabled: Bool {
        shareOptions.contains("facebookMessenger")
    }
    
    var isTelegramEnabled: Bool {
        shareOptions.contains("telegram")
    }
    
    var isDiscordEnabled: Bool {
        shareOptions.contains("discord")
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
    
    /// Find the email invitations block from the form structure
    var emailInvitationsBlock: ElementNode? {
        guard let root = formStructure else { return nil }
        return findBlock(in: root, withSubtype: "vrtx-email-invitations")
    }
    
    /// Recursively find a block by subtype in the element tree
    private func findBlock(in node: ElementNode, withSubtype subtype: String) -> ElementNode? {
        if node.subtype == subtype {
            return node
        }
        if let children = node.children {
            for child in children {
                if let found = findBlock(in: child, withSubtype: subtype) {
                    return found
                }
            }
        }
        return nil
    }
    
    // MARK: - Form Field Methods
    
    /// Set a form field value
    /// - Parameters:
    ///   - fieldName: The name of the form field
    ///   - value: The value to set
    func setFormFieldValue(_ fieldName: String, value: String) {
        formFieldValues[fieldName] = value
    }
    
    /// Get a form field value
    /// - Parameter fieldName: The name of the form field
    /// - Returns: The value of the form field, or nil if not set
    func getFormFieldValue(_ fieldName: String) -> String? {
        return formFieldValues[fieldName]
    }
    
    // MARK: - Initialization
    
    /// Default production analytics collector URL
    private static let defaultAnalyticsBaseURL = URL(string: "https://collector.vortexsoftware.com")!
    
    /// Optional initial configuration passed from prefetcher or cache
    private var initialConfiguration: WidgetConfiguration?
    private var initialDeploymentId: String?
    
    init(
        componentId: String,
        jwt: String?,
        apiBaseURL: URL,
        analyticsBaseURL: URL? = nil,
        group: GroupDTO?,
        googleIosClientId: String? = nil,
        onEvent: ((VortexAnalyticsEvent) -> Void)? = nil,
        segmentation: [String: Any]? = nil,
        onDismiss: (() -> Void)?,
        initialConfiguration: WidgetConfiguration? = nil,
        initialDeploymentId: String? = nil
    ) {
        self.componentId = componentId
        self.jwt = jwt
        self.group = group
        self.googleIosClientId = googleIosClientId
        self.onEvent = onEvent
        self.segmentation = segmentation
        self.onDismiss = onDismiss
        self.client = VortexClient(baseURL: apiBaseURL)
        self.initialConfiguration = initialConfiguration
        self.initialDeploymentId = initialDeploymentId
        
        // Initialize analytics with separate collector URL (defaults to production)
        self.sessionId = UUID().uuidString
        self.analyticsClient = VortexAnalyticsClient(
            baseURL: analyticsBaseURL ?? Self.defaultAnalyticsBaseURL,
            sessionId: sessionId,
            jwt: jwt
        )
    }
    
    // MARK: - Analytics
    
    /// Cached useragent string (computed once)
    private lazy var useragent: String = VortexDeviceInfo.useragent
    
    /// Cached foreign user ID extracted from JWT
    private lazy var foreignUserId: String? = VortexJWTParser.extractForeignUserId(from: jwt)
    
    /// Track an analytics event.
    /// - Parameters:
    ///   - name: The event name
    ///   - payload: Optional event-specific payload
    private func trackEvent(
        _ name: VortexEventName,
        payload: [String: Any]? = nil
    ) {
        let event = VortexAnalyticsEvent(
            name: name.rawValue,
            widgetConfigurationId: configuration?.id,
            deploymentId: deploymentId,
            platform: "ios",
            sessionId: sessionId,
            useragent: useragent,
            foreignUserId: foreignUserId,
            segmentation: segmentation?.toJSONValues(),
            payload: payload?.toJSONValues(),
            groups: group.map { [VortexAnalyticsEvent.GroupInfo(
                type: $0.type,
                id: $0.groupId ?? $0.id ?? "",
                name: $0.name
            )] }
        )
        
        // Call onEvent callback if provided
        onEvent?(event)
        
        // Send to analytics backend
        Task {
            await analyticsClient.track(event)
        }
    }
    
    /// Track widget render event (only once per session)
    func trackWidgetRender() {
        guard !widgetRenderTracked else { return }
        widgetRenderTracked = true
        formRenderTime = Date()
        trackEvent(.widgetRender)
    }
    
    /// Track widget error event
    /// - Parameter error: The error that occurred
    func trackWidgetError(_ error: VortexError) {
        trackEvent(.widgetError, payload: [
            "error": error.localizedDescription
        ])
    }
    
    /// Track email field focus event
    func trackEmailFieldFocus() {
        let timestamp = formRenderTime.map { Date().timeIntervalSince($0) * 1000 } ?? 0
        trackEvent(.widgetEmailFieldFocus, payload: [
            "timestamp": Int(timestamp)
        ])
    }
    
    /// Track email field blur event
    func trackEmailFieldBlur() {
        let timestamp = formRenderTime.map { Date().timeIntervalSince($0) * 1000 } ?? 0
        trackEvent(.widgetEmailFieldBlur, payload: [
            "timestamp": Int(timestamp)
        ])
    }
    
    /// Track email validation event
    /// - Parameters:
    ///   - email: The email being validated
    ///   - isValid: Whether the email is valid
    func trackEmailValidation(email: String, isValid: Bool) {
        trackEvent(.widgetEmailValidation, payload: [
            "email": email,
            "isValid": isValid
        ])
    }
    
    /// Track share link click event
    /// - Parameter clickName: The name/type of the share action (e.g., "copy", "whatsapp", "sms")
    func trackShareLinkClick(clickName: String) {
        trackEvent(.widgetShareLinkClick, payload: [
            "clickName": clickName
        ])
    }
    
    /// Track email invitations submitted event
    /// - Parameter formData: The form data being submitted
    func trackEmailInvitationsSubmitted(formData: [String: Any]) {
        trackEvent(.emailInvitationsSubmitted, payload: [
            "formData": formData
        ])
    }
    
    /// Track email validation error event (form submission validation failure)
    /// - Parameter formData: The form data that failed validation
    func trackEmailValidationError(formData: [String: Any]) {
        trackEvent(.widgetEmailValidationError, payload: [
            "formData": formData
        ])
    }
    
    /// Track email submit error event
    /// - Parameter error: The error message
    func trackEmailSubmitError(error: String) {
        trackEvent(.widgetEmailSubmitError, payload: [
            "error": error
        ])
    }
    
    // MARK: - Configuration Loading
    
    /// Load widget configuration with stale-while-revalidate pattern.
    /// If cached/prefetched configuration exists, it's used immediately (no loading spinner).
    /// Fresh configuration is always fetched in the background to ensure up-to-date data.
    func loadConfiguration() async {
        guard let jwt = jwt else {
            error = .missingJWT
            return
        }
        
        // Step 1: Check for initial configuration (passed via init) or cached configuration
        var hasCachedConfig = false
        
        if let initial = initialConfiguration {
            // Use configuration passed via init (from prefetcher or parent view)
            configuration = initial
            deploymentId = initialDeploymentId
            hasCachedConfig = true
        } else if let cached = await VortexConfigurationCache.shared.get(componentId) {
            // Use configuration from shared cache
            configuration = cached.configuration
            deploymentId = cached.deploymentId
            hasCachedConfig = true
        }
        
        // Step 2: Only show loading if we don't have any configuration yet
        if !hasCachedConfig {
            isLoading = true
        }
        error = nil
        
        // Step 3: Always fetch fresh configuration (stale-while-revalidate)
        do {
            let configData = try await client.getWidgetConfiguration(
                componentId: componentId,
                jwt: jwt
            )
            
            // Update configuration with fresh data
            configuration = configData.widgetConfiguration
            deploymentId = configData.deploymentId
            
            // Update shared cache for future use
            await VortexConfigurationCache.shared.set(
                componentId,
                configuration: configData.widgetConfiguration,
                deploymentId: configData.deploymentId
            )
            
            // Pre-fetch shareable link
            await fetchShareableLink()
        } catch let vortexError as VortexError {
            // Only set error if we don't have cached config to show
            if !hasCachedConfig {
                self.error = vortexError
            }
        } catch let otherError {
            // Only set error if we don't have cached config to show
            if !hasCachedConfig {
                self.error = .decodingError(otherError)
            }
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
        } catch {
        }
    }
    
    // MARK: - Share Actions
    
    func copyLink() async {
        loadingCopy = true
        
        // Track share link click
        trackShareLinkClick(clickName: "copyLink")
        
        // Fetch shareable link if not already cached
        if shareableLink == nil {
            await fetchShareableLink()
        }
        
        guard let link = shareableLink else {
            loadingCopy = false
            return
        }
        
        // Copy to clipboard
        UIPasteboard.general.string = link
        
        loadingCopy = false
        copySuccess = true
        
        // Reset success state after delay (2 seconds, matching RN SDK)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        copySuccess = false
    }
    
    func shareInvitation() async {
        loadingShare = true
        
        // Track share link click
        trackShareLinkClick(clickName: "shareViaNativeShare")
        
        // Fetch shareable link if not already cached
        if shareableLink == nil {
            await fetchShareableLink()
        }
        
        guard let link = shareableLink else {
            loadingShare = false
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
        
        
        // Present the share sheet from the topmost view controller
        topVC.present(activityVC, animated: true) {
        }
        
        // Set success state after a brief delay to allow the sheet to appear
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        shareSuccess = true
        
        // Reset success state after delay (2 seconds, matching RN SDK)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        shareSuccess = false
    }
    
    func shareViaSms() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaSMS")
        
        Task {
            // Fetch shareable link if not already cached
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else {
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
                return
            }
            
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    }
    
    func shareViaLine() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaLine")
        
        guard let link = shareableLink,
              let encodedLink = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://line.me/R/msg/text/?\(encodedLink)") else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    func showQrCode() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaQrCode")
        currentView = .qrCode
    }
    
    func shareViaEmail() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaEmail")
        
        Task {
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else { return }
            
            // Get subject and body from configuration
            var subject = "You're invited!"
            var body = link
            
            if let config = configuration {
                if let subjectProp = config.configuration.props["vortex.components.share.template.subject"],
                   case .string(let subjectTemplate) = subjectProp.value,
                   !subjectTemplate.isEmpty {
                    subject = subjectTemplate
                }
                if let bodyProp = config.configuration.props["vortex.components.share.template.body"],
                   case .string(let template) = bodyProp.value {
                    if template.contains("{{vortex_share_link}}") {
                        body = template.replacingOccurrences(of: "{{vortex_share_link}}", with: link)
                    } else {
                        body = template.hasSuffix(" ") ? "\(template)\(link)" : "\(template) \(link)"
                    }
                }
            }
            
            // Use urlQueryAllowed character set for proper mailto URL encoding
            // This is the standard approach matching JavaScript's encodeURIComponent
            guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") else {
                return
            }
            
            await MainActor.run {
                // Check if mailto URL can be opened (Mail app must be configured)
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    func shareViaTwitter() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaTwitter")
        
        Task {
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else { return }
            
            var text = link
            if let config = configuration,
               let bodyProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = bodyProp.value {
                if template.contains("{{vortex_share_link}}") {
                    text = template.replacingOccurrences(of: "{{vortex_share_link}}", with: link)
                } else {
                    text = template.hasSuffix(" ") ? "\(template)\(link)" : "\(template) \(link)"
                }
            }
            
            guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
            // Try Twitter app first, fallback to web
            let twitterAppURL = URL(string: "twitter://post?message=\(encodedText)")
            let twitterWebURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)")
            
            await MainActor.run {
                if let appURL = twitterAppURL, UIApplication.shared.canOpenURL(appURL) {
                    UIApplication.shared.open(appURL)
                } else if let webURL = twitterWebURL {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
    
    func shareViaInstagram() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaInstagram")
        
        // Instagram doesn't support direct sharing via URL scheme with pre-filled content
        // Open Instagram Direct inbox instead
        let instagramURL = URL(string: "instagram://direct-inbox")
        let instagramWebURL = URL(string: "https://instagram.com/direct/inbox")
        
        if let appURL = instagramURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = instagramWebURL {
            UIApplication.shared.open(webURL)
        }
    }
    
    func shareViaWhatsApp() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaWhatsApp")
        
        Task {
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else { return }
            
            var text = link
            if let config = configuration,
               let bodyProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = bodyProp.value {
                if template.contains("{{vortex_share_link}}") {
                    text = template.replacingOccurrences(of: "{{vortex_share_link}}", with: link)
                } else {
                    text = template.hasSuffix(" ") ? "\(template)\(link)" : "\(template) \(link)"
                }
            }
            
            guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
            let whatsappURL = URL(string: "whatsapp://send?text=\(encodedText)")
            let whatsappWebURL = URL(string: "https://wa.me/?text=\(encodedText)")
            
            await MainActor.run {
                if let appURL = whatsappURL, UIApplication.shared.canOpenURL(appURL) {
                    UIApplication.shared.open(appURL)
                } else if let webURL = whatsappWebURL {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
    
    func shareViaFacebookMessenger() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaFacebookMessenger")
        
        Task {
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink,
                  let encodedLink = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
            let messengerURL = URL(string: "fb-messenger://share?link=\(encodedLink)")
            let messengerWebURL = URL(string: "https://www.facebook.com/dialog/send?link=\(encodedLink)&app_id=0&redirect_uri=\(encodedLink)")
            
            await MainActor.run {
                if let appURL = messengerURL, UIApplication.shared.canOpenURL(appURL) {
                    UIApplication.shared.open(appURL)
                } else if let webURL = messengerWebURL {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
    
    func shareViaTelegram() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaTelegram")
        
        Task {
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else { return }
            
            var text = link
            if let config = configuration,
               let bodyProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = bodyProp.value {
                if template.contains("{{vortex_share_link}}") {
                    text = template.replacingOccurrences(of: "{{vortex_share_link}}", with: link)
                } else {
                    text = template.hasSuffix(" ") ? "\(template)\(link)" : "\(template) \(link)"
                }
            }
            
            guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
            let telegramURL = URL(string: "tg://msg?text=\(encodedText)")
            let telegramWebURL = URL(string: "https://t.me/share/url?url=\(encodedText)")
            
            await MainActor.run {
                if let appURL = telegramURL, UIApplication.shared.canOpenURL(appURL) {
                    UIApplication.shared.open(appURL)
                } else if let webURL = telegramWebURL {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
    
    func shareViaDiscord() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaDiscord")
        
        // Discord doesn't have a direct share URL scheme
        // Open Discord app or website
        let discordURL = URL(string: "discord://")
        let discordWebURL = URL(string: "https://discord.com/channels/@me")
        
        if let appURL = discordURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = discordWebURL {
            UIApplication.shared.open(webURL)
        }
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
            
        } catch let error as GoogleContactsError {
            googleContactsError = error
        } catch {
            googleContactsError = error
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
                          let _ = GIDSignIn.value(forKey: "sharedInstance") as? NSObject else {
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
        // Check GoogleSignIn availability
        guard NSClassFromString("GIDSignIn") != nil else {
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
                    return accessToken
                } else {
                    // Need to request additional scope - addScopes is on GIDGoogleUser in v7.x
                    let result = try await user.addScopes([contactsScope], presenting: presentingVC)
                    guard let accessToken = result.user.accessToken.tokenString as String? else {
                        throw GoogleContactsError.noAccessToken
                    }
                    return accessToken
                }
            }
        } catch {
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
            
        } catch {
            // Store error for UI display
            failedGoogleContactIds[contact.id] = error.localizedDescription
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
            case .authorized, .limited:
                break
            @unknown default:
                break
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
            
        } catch let error as ContactsError {
            contactsError = error
        } catch {
            contactsError = error
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
            
        } catch {
            // Store error for UI display
            failedContactIds[contact.id] = error.localizedDescription
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
        
        // Build form data for tracking
        let formData: [String: Any] = [
            "emails": emails,
            "formFieldValues": formFieldValues
        ]
        
        // Track email invitations submitted
        trackEmailInvitationsSubmitted(formData: formData)
        
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
            // Track email submit error
            trackEmailSubmitError(error: vortexError.localizedDescription)
        } catch let otherError {
            self.error = .encodingError(otherError)
            // Track email submit error
            trackEmailSubmitError(error: otherError.localizedDescription)
        }
        
        isSending = false
    }
    
    // MARK: - Dismiss
    
    func dismiss() {
        onDismiss?()
    }
}
