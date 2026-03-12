import SwiftUI
import Contacts
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - Invitation Sent Event

/// Event fired when an invitation is sent from any subcomponent.
/// Other subcomponents can observe this via the ViewModel's `invitationSentEvent` property.
public struct InvitationSentEvent: Equatable {
    /// The source component that sent the invitation
    public let source: InvitationSource
    /// The short link that was created for the invitation
    public let shortLink: String
    /// Timestamp when the event was fired
    public let timestamp: Date
    
    public init(source: InvitationSource, shortLink: String, timestamp: Date = Date()) {
        self.source = source
        self.shortLink = shortLink
        self.timestamp = timestamp
    }
    
    /// Source component types that can fire invitation events
    public enum InvitationSource: String, Equatable {
        case inviteContacts = "invite_contacts"
        case findFriends = "find_friends"
        case invitationSuggestions = "invitation_suggestions"
        case emailInvitations = "email_invitations"
        case shareLink = "share_link"
    }
}

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
    @Published var googleAuthenticatedEmail: String = ""
    
    // Form field values for custom form elements
    @Published var formFieldValues: [String: String] = [:]
    
    // Find Friends state
    @Published var findFriendsActionInProgress: String? = nil
    @Published var connectedFindFriendsContactIds: Set<String> = []
    
    // Search Box state
    @Published var searchBoxQuery: String = ""
    @Published var searchBoxResults: [SearchBoxContact]? = nil
    @Published var searchBoxIsSearching: Bool = false
    @Published var searchBoxActionInProgress: String? = nil
    @Published var searchBoxDismissFocusToken: Int = 0
    
    // Invitation Suggestions state
    @Published var invitationSuggestionsActionInProgress: String? = nil
    @Published var invitedInvitationSuggestionIds: Set<String> = []
    @Published var dismissedInvitationSuggestionIds: Set<String> = []

    // Dynamic visibility flags (set by components after async loading)
    @Published var isIncomingInvitationsVisible: Bool = false
    @Published var isFindFriendsVisible: Bool = false
    @Published var isInvitationSuggestionsVisible: Bool = false
    @Published var isOutgoingInvitationsVisible: Bool = false

    // Outgoing invitations fetched from API (shared cache to avoid duplicate calls)
    @Published var fetchedOutgoingInvitations: [OutgoingInvitation] = []
    // Outgoing invitation user IDs (for filtering suggestions, find friends, search box)
    @Published var outgoingInvitationUserIds: Set<String> = []
    // Whether outgoing invitations have been loaded (for per-component shimmer placeholders)
    @Published var isOutgoingInvitationsLoaded = false
    
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
    
    /// Filtered frequently contacted (calendar) contacts based on search query
    var filteredFrequentlyContacted: [VortexContact] {
        let calendar = googleContacts.filter { $0.source == .calendar }
        if googleContactsSearchQuery.isEmpty {
            return calendar
        }
        let query = googleContactsSearchQuery.lowercased()
        return calendar.filter { contact in
            contact.name.lowercased().contains(query) ||
            contact.email.lowercased().contains(query)
        }
    }
    
    /// Filtered main (non-calendar) Google contacts based on search query
    var filteredMainContacts: [VortexContact] {
        let main = googleContacts.filter { $0.source != .calendar }
        if googleContactsSearchQuery.isEmpty {
            return main
        }
        let query = googleContactsSearchQuery.lowercased()
        return main.filter { contact in
            contact.name.lowercased().contains(query) ||
            contact.email.lowercased().contains(query)
        }
    }
    
    /// Grouped main contacts by first letter for alphabetic section headers
    var groupedMainContacts: [(letter: String, contacts: [VortexContact])] {
        let contacts = filteredMainContacts
        var groups: [String: [VortexContact]] = [:]
        for contact in contacts {
            let firstChar = contact.name.first.map { String($0).uppercased() } ?? "#"
            let letter = firstChar.rangeOfCharacter(from: .letters) != nil ? firstChar : "#"
            groups[letter, default: []].append(contact)
        }
        return groups.sorted { $0.key < $1.key }.map { (letter: $0.key, contacts: $0.value) }
    }
    
    /// Combined filtered Google contacts (for empty state check)
    var filteredGoogleContacts: [VortexContact] {
        filteredFrequentlyContacted + filteredMainContacts
    }
    
    // MARK: - Private Properties
    
    private let componentId: String
    private let group: GroupDTO?
    
    // Internal (for subcomponents like OutgoingInvitationsView)
    let jwt: String?
    let client: VortexClient
    private let googleIosClientId: String?
    private let onDismiss: (() -> Void)?
    private let locale: String?
    
    // Find Friends
    let findFriendsConfig: FindFriendsConfig?
    
    // Invitation Suggestions
    let invitationSuggestionsConfig: InvitationSuggestionsConfig?
    
    // Invite Contacts
    let inviteContactsConfig: InviteContactsConfig?
    
    // Search Box
    let searchBoxConfig: SearchBoxConfig?
    
    // Outgoing Invitations
    let outgoingInvitationsConfig: OutgoingInvitationsConfig?
    
    // Incoming Invitations
    let incomingInvitationsConfig: IncomingInvitationsConfig?
    
    // Unfurl configuration for Open Graph metadata
    private let unfurlConfig: UnfurlConfig?
    
    // MARK: - Internal Events
    
    /// Publisher that fires when an invitation is created/sent from any subcomponent.
    /// Other subcomponents can observe this to refresh their data (e.g., Outgoing Invitations).
    @Published var invitationSentEvent: InvitationSentEvent?
    
    // Analytics
    private let analyticsClient: VortexAnalyticsClient
    private let sessionId: String
    private let onEvent: ((VortexAnalyticsEvent) -> Void)?
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

    /// Get a theme color value with fallback support.
    /// Tries the new --vrtx-* token first, then falls back to the legacy token.
    /// - Parameters:
    ///   - newKey: The new --vrtx-* prefixed token key
    ///   - fallbackKey: The legacy token key to use if new key is not found
    /// - Returns: The color value string, or nil if neither key exists
    private func getThemeColor(newKey: String, fallbackKey: String) -> String? {
        // Try new token first
        if let color = themeColorMap[newKey], !color.isEmpty {
            return color
        }
        // Fallback to old token
        if let color = themeColorMap[fallbackKey], !color.isEmpty {
            return color
        }
        return nil
    }

    /// Get a theme color value with multiple fallback options.
    /// Tries each key in order until one is found.
    /// - Parameter keys: Array of token keys to try in order
    /// - Returns: The color value string, or nil if no key exists
    private func getThemeColor(keys: [String]) -> String? {
        for key in keys {
            if let color = themeColorMap[key], !color.isEmpty {
                return color
            }
        }
        return nil
    }
    
    /// Get the surface background color for form container background
    /// Priority: 1) Root element's inline style, 2) Theme's --vrtx-root-background, 3) Legacy --color-surface-background
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

        // Try new --vrtx-root-background, fallback to legacy --color-surface-background
        guard let hexColor = getThemeColor(newKey: "--vrtx-root-background", fallbackKey: "--color-surface-background"),
              hexColor != "transparent" else {
            return nil
        }
        return Color(hex: hexColor)
    }

    /// Get the form title from widget configuration (mobile-specific key takes priority)
    var configFormTitle: String? {
        return formStructure?.settings?.customizations?["mobile.formTitle"]?.textContent
            ?? formStructure?.settings?.customizations?["formTitle"]?.textContent
    }

    /// Helper to get a value from the root element's theme options
    private func getRootThemeOption(_ key: String) -> String? {
        guard let options = formStructure?.theme?.options else { return nil }
        return options.first(where: { $0.key == key })?.value
    }

    /// Get form title style from root element's theme options (--vrtx-form-title-*)
    var formTitleColor: Color? {
        guard let hex = getRootThemeOption("--vrtx-form-title-color"), !hex.isEmpty else { return nil }
        return Color(hex: hex)
    }

    var formTitleFontSize: CGFloat? {
        guard let str = getRootThemeOption("--vrtx-form-title-font-size"), !str.isEmpty else { return nil }
        // Strip "px" suffix if present
        let cleaned = str.replacingOccurrences(of: "px", with: "")
        guard let val = Double(cleaned) else { return nil }
        return CGFloat(val)
    }

    var formTitleFontWeight: Font.Weight? {
        guard let str = getRootThemeOption("--vrtx-form-title-font-weight"), !str.isEmpty else { return nil }
        switch str {
        case "bold", "700": return .bold
        case "600": return .semibold
        case "500": return .medium
        case "400", "normal": return .regular
        case "300": return .light
        default: return nil
        }
    }

    /// Get the surface foreground color from theme (for heading text)
    /// Priority: 1) New --vrtx-root-color, 2) Legacy --color-surface-foreground
    var surfaceForegroundColor: Color? {
        guard let hexColor = getThemeColor(newKey: "--vrtx-root-color", fallbackKey: "--color-surface-foreground") else {
            return nil
        }
        return Color(hex: hexColor)
    }
    
    // MARK: - Theme Colors for Find Friends
    // These colors are extracted from vortex.theme configuration and used as fallbacks
    // when block.theme.options doesn't have specific values set.
    // Each property tries new --vrtx-* tokens first, then falls back to legacy tokens.

    /// Primary background color from theme (e.g., for Connect button background)
    /// Priority: 1) --vrtx-button-primary-background, 2) --vrtx-button-background, 3) --color-primary-background
    var themePrimaryBackground: Color? {
        guard let hexColor = getThemeColor(keys: [
            "--vrtx-button-primary-background",
            "--vrtx-button-background",
            "--color-primary-background"
        ]) else {
            return nil
        }
        return Color(hex: hexColor)
    }

    /// Primary foreground color from theme (e.g., for Connect button text)
    /// Priority: 1) --vrtx-button-primary-color, 2) --vrtx-button-color, 3) --color-primary-foreground
    var themePrimaryForeground: Color? {
        guard let hexColor = getThemeColor(keys: [
            "--vrtx-button-primary-color",
            "--vrtx-button-color",
            "--color-primary-foreground"
        ]) else {
            return nil
        }
        return Color(hex: hexColor)
    }

    /// Secondary background color from theme (e.g., for Invite button background)
    /// Priority: 1) --vrtx-button-secondary-background, 2) --vrtx-button-background, 3) --color-secondary-background
    var themeSecondaryBackground: Color? {
        guard let hexColor = getThemeColor(keys: [
            "--vrtx-button-secondary-background",
            "--vrtx-button-background",
            "--color-secondary-background"
        ]) else {
            return nil
        }
        return Color(hex: hexColor)
    }

    /// Secondary foreground color from theme (e.g., for Invite button text)
    /// Priority: 1) --vrtx-button-secondary-color, 2) --vrtx-button-color, 3) --color-secondary-foreground
    var themeSecondaryForeground: Color? {
        guard let hexColor = getThemeColor(keys: [
            "--vrtx-button-secondary-color",
            "--vrtx-button-color",
            "--color-secondary-foreground"
        ]) else {
            return nil
        }
        return Color(hex: hexColor)
    }

    /// Foreground color from theme (e.g., for contact name text)
    /// Priority: 1) --vrtx-root-color, 2) --color-foreground
    var themeForeground: Color? {
        guard let hexColor = getThemeColor(keys: [
            "--vrtx-root-color",
            "--color-foreground"
        ]) else {
            return nil
        }
        return Color(hex: hexColor)
    }

    /// Border color from theme (e.g., for Invite button border)
    /// Priority: 1) --vrtx-form-control-border-color, 2) --color-border
    var themeBorder: Color? {
        guard let hexColor = getThemeColor(keys: [
            "--vrtx-form-control-border-color",
            "--color-border"
        ]) else {
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
    
    var isLineLiffEnabled: Bool {
        shareOptions.contains("lineLiff")
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
        // Google Contacts requires iOS 15+ (GoogleSignIn SDK requirement)
        guard #available(iOS 15.0, *) else { return false }
        return enabledComponents.contains("vortex.components.importcontacts.providers.google")
    }
    
    var isGoogleWorkspaceEnabled: Bool {
        enabledComponents.contains("vortex.components.importcontacts.providers.google.workspace.directory")
    }
    
    var isGoogleCalendarEnabled: Bool {
        enabledComponents.contains("vortex.components.importcontacts.providers.google.calendar.guests")
    }
    
    /// Dynamic OAuth scopes based on enabled toggles
    private var googleOAuthScopes: [String] {
        var scopes = [
            "https://www.googleapis.com/auth/contacts.readonly",
            "https://www.googleapis.com/auth/userinfo.email"
        ]
        if isGoogleWorkspaceEnabled {
            scopes.append("https://www.googleapis.com/auth/directory.readonly")
        }
        if isGoogleCalendarEnabled {
            scopes.append("https://www.googleapis.com/auth/calendar.readonly")
        }
        return scopes
    }
    
    var isEmailInvitationsEnabled: Bool {
        enabledComponents.contains("vortex.components.emailinvitations")
    }
    
    /// Find the email invitations block from the form structure
    var emailInvitationsBlock: ElementNode? {
        guard let root = formStructure else { return nil }
        return findBlock(in: root, withSubtype: "vrtx-email-invitations")
    }
    
    /// Find the contacts import block from the form structure
    var contactsImportBlock: ElementNode? {
        guard let root = formStructure else { return nil }
        return findBlock(in: root, withSubtype: "vrtx-contacts-import")
    }
    
    /// Find the invite contacts block from the form structure
    var inviteContactsBlock: ElementNode? {
        guard let root = formStructure else { return nil }
        return findBlock(in: root, withSubtype: "vrtx-invite-contacts")
    }
    
    /// Read a customization label from any element block, falling back to a default
    func customLabel(from block: ElementNode?, key: String, default defaultValue: String) -> String {
        // Try flat dotted key first (e.g. "google.frequentlyContactedTitle")
        if let text = block?.settings?.customizations?[key]?.textContent {
            return text
        }
        // Editor saves via nested path (e.g. google -> frequentlyContactedTitle -> textContent),
        // while API defaults use dotted-key format. Try nested lookup.
        let keyParts = key.split(separator: ".").map(String.init)
        if keyParts.count >= 2, let customizations = block?.settings?.customizations {
            // Navigate nested: customizations["google"]?... but customizations is [String: ButtonCustomization]
            // The nested structure means the first part is a key whose value contains sub-keys.
            // Since our model is flat [String: ButtonCustomization], we need to check if the config
            // was decoded with nested dictionaries. For now, try the raw JSON approach.
            if let nestedBlock = block?.settings?.rawCustomizations {
                var current: Any? = nestedBlock as Any
                for part in keyParts {
                    if let dict = current as? [String: AnyCodable] {
                        current = dict[part]?.value
                    } else if let dict = current as? [String: Any] {
                        current = dict[part]
                    } else {
                        current = nil
                        break
                    }
                }
                if let dict = current as? [String: Any], let text = dict["textContent"] as? String {
                    return text
                }
            }
        }
        return defaultValue
    }
    
    /// Read a customization label from the root element (vrtx-root)
    func rootLabel(key: String, default defaultValue: String) -> String {
        formStructure?.settings?.customizations?[key]?.textContent ?? defaultValue
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
    
    init(
        componentId: String,
        jwt: String?,
        apiBaseURL: URL,
        analyticsBaseURL: URL? = nil,
        group: GroupDTO?,
        googleIosClientId: String? = nil,
        onEvent: ((VortexAnalyticsEvent) -> Void)? = nil,
        onDismiss: (() -> Void)?,
        findFriendsConfig: FindFriendsConfig? = nil,
        invitationSuggestionsConfig: InvitationSuggestionsConfig? = nil,
        inviteContactsConfig: InviteContactsConfig? = nil,
        searchBoxConfig: SearchBoxConfig? = nil,
        outgoingInvitationsConfig: OutgoingInvitationsConfig? = nil,
        incomingInvitationsConfig: IncomingInvitationsConfig? = nil,
        locale: String? = nil,
        unfurlConfig: UnfurlConfig? = nil
    ) {
        self.componentId = componentId
        self.jwt = jwt
        self.group = group
        self.googleIosClientId = googleIosClientId
        self.onEvent = onEvent
        self.onDismiss = onDismiss
        self.client = VortexClient(baseURL: apiBaseURL)
        self.findFriendsConfig = findFriendsConfig
        self.invitationSuggestionsConfig = invitationSuggestionsConfig
        self.inviteContactsConfig = inviteContactsConfig
        self.searchBoxConfig = searchBoxConfig
        self.outgoingInvitationsConfig = outgoingInvitationsConfig
        self.incomingInvitationsConfig = incomingInvitationsConfig
        self.locale = locale
        self.unfurlConfig = unfurlConfig
        
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
    
    /// Track invite form render success event (only once per session)
    func trackWidgetRender() {
        guard !widgetRenderTracked else { return }
        widgetRenderTracked = true
        formRenderTime = Date()
        trackEvent(.inviteFormRenderSucceeded)
    }

    /// Track invite form render failure event
    /// - Parameter error: The error that occurred
    func trackWidgetError(_ error: VortexError) {
        trackEvent(.inviteFormRenderFailed, payload: [
            "error": error.localizedDescription
        ])
    }

    /// Track email field focus event
    func trackEmailFieldFocus() {
        let timestamp = formRenderTime.map { Date().timeIntervalSince($0) * 1000 } ?? 0
        trackEvent(.emailFieldFocussed, payload: [
            "timestamp": Int(timestamp)
        ])
    }

    /// Track email field blur event
    func trackEmailFieldBlur() {
        let timestamp = formRenderTime.map { Date().timeIntervalSince($0) * 1000 } ?? 0
        trackEvent(.emailFieldBlurred, payload: [
            "timestamp": Int(timestamp)
        ])
    }

    /// Track email validation event
    /// - Parameters:
    ///   - email: The email being validated
    ///   - isValid: Whether the email is valid
    func trackEmailValidation(email: String, isValid: Bool) {
        trackEvent(.emailSubmissionValidated, payload: [
            "email": email,
            "isValid": isValid
        ])
    }

    /// Track sharing destination button click event
    /// - Parameter clickName: The name/type of the share action (e.g., "copy", "whatsapp", "sms")
    func trackShareLinkClick(clickName: String) {
        trackEvent(.sharingDestinationButtonClicked, payload: [
            "clickName": clickName
        ])
    }

    /// Track email field submission success event
    /// - Parameter formData: The form data being submitted
    func trackEmailInvitationsSubmitted(formData: [String: Any]) {
        trackEvent(.emailFieldSubmissionSucceeded, payload: [
            "formData": formData
        ])
    }

    /// Track email field submission failure event
    /// - Parameter error: The error message
    func trackEmailSubmitError(error: String) {
        trackEvent(.emailFieldSubmissionFailed, payload: [
            "error": error
        ])
    }

    // MARK: - Invitation Action Events

    /// Track inbound invitation accept button click event
    /// - Parameters:
    ///   - invitationId: The ID of the invitation being accepted
    ///   - inviterName: The name of the person who sent the invitation
    func trackInboundInvitationAccept(invitationId: String, inviterName: String) {
        trackEvent(.inboundInvitationAcceptClicked, payload: [
            "invitationId": invitationId,
            "inviterName": inviterName
        ])
    }

    /// Track inbound invitation delete button click event
    /// - Parameters:
    ///   - invitationId: The ID of the invitation being deleted
    ///   - inviterName: The name of the person who sent the invitation
    func trackInboundInvitationDelete(invitationId: String, inviterName: String) {
        trackEvent(.inboundInvitationDeleteClicked, payload: [
            "invitationId": invitationId,
            "inviterName": inviterName
        ])
    }

    /// Track outbound invitation delete button click event
    /// - Parameters:
    ///   - invitationId: The ID of the invitation being deleted/cancelled
    ///   - inviteeName: The name of the recipient of the invitation
    func trackOutboundInvitationDelete(invitationId: String, inviteeName: String) {
        trackEvent(.outboundInvitationDeleteClicked, payload: [
            "invitationId": invitationId,
            "inviteeName": inviteeName
        ])
    }

    // MARK: - PYMK (People You May Know) Events

    /// Track PYMK invite button click event
    /// - Parameters:
    ///   - suggestionId: The ID of the suggestion being invited
    ///   - suggestionName: The name of the person being invited
    func trackPymkInvite(suggestionId: String, suggestionName: String) {
        trackEvent(.pymkInviteClicked, payload: [
            "suggestionId": suggestionId,
            "suggestionName": suggestionName
        ])
    }

    /// Track PYMK delete/dismiss button click event
    /// - Parameters:
    ///   - suggestionId: The ID of the suggestion being dismissed
    ///   - suggestionName: The name of the person being dismissed
    func trackPymkDelete(suggestionId: String, suggestionName: String) {
        trackEvent(.pymkDeleteClicked, payload: [
            "suggestionId": suggestionId,
            "suggestionName": suggestionName
        ])
    }

    // MARK: - Find Friends Events

    /// Track find friends invite button click event
    /// - Parameters:
    ///   - contactId: The ID of the contact being invited
    ///   - contactName: The name of the contact being invited
    func trackFindFriendsInvite(contactId: String, contactName: String) {
        trackEvent(.findFriendsInviteClicked, payload: [
            "contactId": contactId,
            "contactName": contactName
        ])
    }

    /// Track find friends list displayed event
    /// - Parameter count: The number of friends being displayed
    func trackFindFriendsListDisplayed(count: Int) {
        trackEvent(.findFriendsListDisplayed, payload: [
            "count": count
        ])
    }

    // MARK: - Invite Contacts Events

    /// Track contacts link click event (when user clicks to view contacts list)
    func trackContactsLinkClicked() {
        trackEvent(.contactsLinkClicked)
    }

    /// Track contacts invite button click event (when user clicks to invite a specific contact)
    func trackContactsInviteButtonClicked() {
        trackEvent(.contactsInviteButtonClicked)
    }

    // MARK: - Deprecated/Removed Events

    // trackEmailValidationError is not used - validation errors should be tracked via
    // trackEmailValidation(email:isValid:) with isValid: false, which emits the
    // EMAIL_SUBMISSION_VALIDATED event with the validation result in the payload.
    // This matches the pattern used in vortex-wc and vortex-react-native.
    //
    // func trackEmailValidationError(formData: [String: Any]) {
    //     trackEvent(.emailSubmissionValidated, payload: [
    //         "formData": formData,
    //         "isValid": false
    //     ])
    // }
    
    // MARK: - Configuration Loading
    
    /// Guards against concurrent and rapid-fire configuration fetches.
    private var isLoadingConfiguration = false
    private var lastFetchTime: Date?
    private let minFetchInterval: TimeInterval = 30
    
    /// Load widget configuration with stale-while-revalidate pattern.
    /// If cached/prefetched configuration exists, it's used immediately (no loading spinner).
    /// Fresh configuration is always fetched in the background to ensure up-to-date data.
    func loadConfiguration() async {
        guard !isLoadingConfiguration else { return }
        isLoadingConfiguration = true
        defer { isLoadingConfiguration = false }
        
        guard let jwt = jwt else {
            error = .missingJWT
            return
        }
        
        error = nil

        // Step 1: Check for cached configuration (from prefetcher or previous load)
        var hasCachedConfig = false

        if let cached = await VortexConfigurationCache.shared.get(componentId, locale: locale) {
            // Use configuration from shared cache (locale-aware)
            configuration = cached.configuration
            deploymentId = cached.deploymentId
            hasCachedConfig = true
        }

        // Check for cached outgoing invitations (from prefetcher) early,
        // so components render with filtered data immediately (no shimmer)
        if let cachedOutgoing = await VortexConfigurationCache.shared.getOutgoingInvitations(jwt: jwt) {
            fetchedOutgoingInvitations = cachedOutgoing
            updateOutgoingInvitationUserIds()
            isOutgoingInvitationsLoaded = true
        }

        // Only show global loading spinner if there's no cached config
        if !hasCachedConfig {
            isLoading = true
        }

        // Step 3: Fetch fresh configuration (stale-while-revalidate) unless recently fetched
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < minFetchInterval,
           hasCachedConfig {
            isLoading = false
            Task { @MainActor in
                await fetchOutgoingInvitations()
                isOutgoingInvitationsLoaded = true
            }
            return
        }
        
        do {
            let configData = try await client.getWidgetConfiguration(
                componentId: componentId,
                jwt: jwt,
                locale: locale
            )
            
            // Update configuration with fresh data
            configuration = configData.widgetConfiguration
            deploymentId = configData.deploymentId
            
            // Update shared cache for future use (locale-aware)
            await VortexConfigurationCache.shared.set(
                componentId,
                configuration: configData.widgetConfiguration,
                deploymentId: configData.deploymentId,
                locale: locale
            )
            
            lastFetchTime = Date()
            
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
        // Fetch outgoing invitations (SWR if cached, fresh if not)
        // Components show shimmer only if not already loaded
        Task { @MainActor in
            await fetchOutgoingInvitations()
            isOutgoingInvitationsLoaded = true
        }
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
                groups: groups,
                metadata: unfurlConfig?.toMetadata()
            )
            shareableLink = response.data.invitation.shortLink
        } catch {
        }
    }
    
    // MARK: - SMS Invitation (for Invite Contacts)
    
    /// Create an SMS invitation and return the short link.
    /// Used by InviteContactsView to create invitations for contacts.
    /// - Parameters:
    ///   - phoneNumber: The phone number to invite
    ///   - contactName: Optional name of the contact (for analytics)
    /// - Returns: The short link for the invitation, or nil if creation failed
    func createSmsInvitation(phoneNumber: String, contactName: String?) async -> String? {
        guard let jwt = jwt,
              let config = configuration else { return nil }

        do {
            var groups: [GroupDTO]? = nil
            if let group = group {
                groups = [group]
            }

            // Server expects value as array of objects with value and name
            var valueObject: [String: Any] = ["value": phoneNumber]
            if let name = contactName {
                valueObject["name"] = name
            }
            let smsTarget: [String: Any] = [
                "type": "phone",
                "value": [valueObject]
            ]
            let payload: [String: Any] = [
                "smsTarget": smsTarget
            ]

            let response = try await client.createInvitation(
                jwt: jwt,
                widgetConfigurationId: config.id,
                payload: payload,
                source: "phone",
                groups: groups,
                targets: nil,
                templateVariables: nil,
                metadata: unfurlConfig?.toMetadata()
            )

            // Fire invitation sent event so outgoing invitations list refreshes
            if let shortLink = response.data.invitationEntries?.first?.shortLink {
                fireInvitationSentEvent(source: .inviteContacts, shortLink: shortLink)
                return shortLink
            }
            return nil
        } catch {
            return nil
        }
    }
    
    /// Get the SMS message template from configuration.
    /// Returns the template with placeholder for the link.
    func getSmsMessageTemplate() -> String {
        if let config = configuration,
           let templateProp = config.configuration.props["vortex.components.share.template.body"],
           case .string(let template) = templateProp.value {
            return template
        }
        // Default template if none configured
        return "{{vortex_share_link}}"
    }
    
    // MARK: - Internal Event Firing
    
    /// Fire an invitation sent event that other subcomponents can observe.
    /// Call this when an invitation is successfully sent from any subcomponent.
    /// - Parameters:
    ///   - source: The component that sent the invitation
    ///   - shortLink: The invitation short link that was created
    func fireInvitationSentEvent(source: InvitationSentEvent.InvitationSource, shortLink: String) {
        invitationSentEvent = InvitationSentEvent(source: source, shortLink: shortLink)
    }
    
    // MARK: - Share Source Tracking
    
    /// Source code mapping for share platform tracking (matches web widget DEV-1600)
    private let shareSourceCodes: [String: String] = [
        "sms": "m",
        "email": "e",
        "native": "n",
        "qrcode": "q",
        "whatsapp": "w",
        "twitter": "t",
        "facebook": "f",
        "instagram": "i",
        "slack": "s",
        "linkedin": "l",
        "telegram": "g",
        "discord": "d",
        "line": "y",
        "msteams": "p"
    ]
    
    /// Transforms a shareable link URL to include a source code for tracking.
    /// Converts `/i/shortcode` → `/i/{code}/shortcode`
    func injectShareSource(_ baseUrl: String, _ source: String) -> String {
        guard let code = shareSourceCodes[source],
              var urlComponents = URLComponents(string: baseUrl) else {
            return baseUrl
        }
        
        let pathParts = urlComponents.path.split(separator: "/")
        if let inviteIndex = pathParts.firstIndex(of: "i"),
           inviteIndex < pathParts.count - 1 {
            var newParts = Array(pathParts)
            newParts.insert(Substring(code), at: inviteIndex + 1)
            urlComponents.path = "/" + newParts.joined(separator: "/")
            return urlComponents.string ?? baseUrl
        }
        return baseUrl
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
        
        // Copy to clipboard (no source injection for copy link, matches web widget)
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
        
        let trackedLink = injectShareSource(link, "native")
        
        // Get the share template from configuration (matching RN SDK behavior)
        var shareText = trackedLink
        if let config = configuration,
           let templateProp = config.configuration.props["vortex.components.share.template.body"],
           case .string(let template) = templateProp.value {
            // Replace placeholder with actual link
            if template.contains("{{vortex_share_link}}") {
                shareText = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
            } else {
                // If no placeholder, append link to template
                shareText = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
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
        if let url = URL(string: trackedLink) {
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
            
            let trackedLink = injectShareSource(link, "sms")
            
            // Get the share template from configuration (matching RN SDK behavior)
            var smsBody = trackedLink
            if let config = configuration,
               let templateProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = templateProp.value {
                // Replace placeholder with actual link
                if template.contains("{{vortex_share_link}}") {
                    smsBody = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
                } else {
                    // If no placeholder, append link to template
                    smsBody = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
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
        
        Task {
            // Fetch shareable link if not already cached
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else {
                return
            }
            
            let trackedLink = injectShareSource(link, "line")
            
            // Get the share template from configuration (matching SMS behavior)
            var message = trackedLink
            if let config = configuration,
               let templateProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = templateProp.value {
                // Replace placeholder with actual link
                if template.contains("{{vortex_share_link}}") {
                    message = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
                } else {
                    // If no placeholder, append link to template
                    message = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
                }
            }
            
            // Use LINE's standard share URL
            guard let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://line.me/R/msg/text/?\(encodedMessage)") else {
                return
            }
            
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    }
    
    func shareViaLineLiff() {
        // Track share link click
        trackShareLinkClick(clickName: "shareViaLineLiff")
        
        Task {
            // Fetch shareable link if not already cached
            if shareableLink == nil {
                await fetchShareableLink()
            }
            
            guard let link = shareableLink else {
                return
            }
            
            let trackedLink = injectShareSource(link, "line")
            
            // Get the share template from configuration (matching SMS behavior)
            var message = trackedLink
            if let config = configuration,
               let templateProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = templateProp.value {
                // Replace placeholder with actual link
                if template.contains("{{vortex_share_link}}") {
                    message = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
                } else {
                    // If no placeholder, append link to template
                    message = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
                }
            }
            
            // Build LIFF URL with invitationLink and message parameters
            // Hard-coded LIFF app URL for proof of concept
            let liffBaseUrl = "https://liff.line.me/2008909352-RwnncfLZ"
            
            guard let encodedLink = trackedLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "\(liffBaseUrl)?invitationLink=\(encodedLink)&message=\(encodedMessage)") else {
                return
            }
            
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
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
            
            let trackedLink = injectShareSource(link, "email")
            
            // Get subject and body from configuration
            var subject = "You're invited!"
            var body = trackedLink
            
            if let config = configuration {
                if let subjectProp = config.configuration.props["vortex.components.share.template.subject"],
                   case .string(let subjectTemplate) = subjectProp.value,
                   !subjectTemplate.isEmpty {
                    subject = subjectTemplate
                }
                if let bodyProp = config.configuration.props["vortex.components.share.template.body"],
                   case .string(let template) = bodyProp.value {
                    if template.contains("{{vortex_share_link}}") {
                        body = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
                    } else {
                        body = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
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
            
            let trackedLink = injectShareSource(link, "twitter")
            
            var text = trackedLink
            if let config = configuration,
               let bodyProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = bodyProp.value {
                if template.contains("{{vortex_share_link}}") {
                    text = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
                } else {
                    text = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
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
            
            let trackedLink = injectShareSource(link, "whatsapp")
            
            var text = trackedLink
            if let config = configuration,
               let bodyProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = bodyProp.value {
                if template.contains("{{vortex_share_link}}") {
                    text = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
                } else {
                    text = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
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
            
            guard let link = shareableLink else { return }
            
            let trackedLink = injectShareSource(link, "facebook")
            
            guard let encodedLink = trackedLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            
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
            
            let trackedLink = injectShareSource(link, "telegram")
            
            var text = trackedLink
            if let config = configuration,
               let bodyProp = config.configuration.props["vortex.components.share.template.body"],
               case .string(let template) = bodyProp.value {
                if template.contains("{{vortex_share_link}}") {
                    text = template.replacingOccurrences(of: "{{vortex_share_link}}", with: trackedLink)
                } else {
                    text = template.hasSuffix(" ") ? "\(template)\(trackedLink)" : "\(template) \(trackedLink)"
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
            let accessToken = try await performGoogleSignIn(clientId: clientId)
            
            // Fetch authenticated user's email for self-exclusion
            let userEmail = await fetchAuthenticatedUserEmail(accessToken: accessToken)
            if !userEmail.isEmpty {
                googleAuthenticatedEmail = userEmail
            }
            
            // Fetch all enabled sources in parallel
            var allContacts: [VortexContact] = []
            var calendarContacts: [VortexContact] = []
            
            await withTaskGroup(of: (String, [VortexContact]).self) { group in
                // Personal contacts (always fetched when google is enabled)
                group.addTask {
                    do {
                        let contacts = try await self.fetchContactsFromPeopleAPI(accessToken: accessToken)
                        return ("contacts", contacts)
                    } catch {
                        return ("contacts", [])
                    }
                }
                
                // Workspace directory
                if isGoogleWorkspaceEnabled {
                    group.addTask {
                        do {
                            let contacts = try await self.fetchWorkspaceDirectory(accessToken: accessToken)
                            return ("workspace", contacts)
                        } catch {
                            return ("workspace_error", [])
                        }
                    }
                }
                
                // Calendar guests
                if isGoogleCalendarEnabled {
                    group.addTask {
                        do {
                            let contacts = try await self.fetchCalendarGuests(accessToken: accessToken)
                            return ("calendar", contacts)
                        } catch {
                            return ("calendar", [])
                        }
                    }
                }
                
                for await (source, contacts) in group {
                    switch source {
                    case "contacts":
                        allContacts.append(contentsOf: contacts)
                    case "workspace":
                        allContacts.append(contentsOf: contacts)
                    case "workspace_error":
                        break
                    case "calendar":
                        calendarContacts = contacts
                    default:
                        break
                    }
                }
                
            }
            
            // Self-exclusion: filter out authenticated user's email
            let selfEmail = userEmail.lowercased()
            if !selfEmail.isEmpty {
                allContacts = allContacts.filter { $0.email.lowercased() != selfEmail }
                calendarContacts = calendarContacts.filter { $0.email.lowercased() != selfEmail }
            }
            
            // Deduplicate contacts + workspace by email (lowercase)
            var seenEmails: Set<String> = []
            var dedupedMain: [VortexContact] = []
            for contact in allContacts.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                let key = contact.email.lowercased()
                if !seenEmails.contains(key) {
                    seenEmails.insert(key)
                    dedupedMain.append(contact)
                }
            }
            
            // Deduplicate calendar contacts by email
            var calendarEmails: Set<String> = []
            var dedupedCalendar: [VortexContact] = []
            for contact in calendarContacts {
                let key = contact.email.lowercased()
                if !calendarEmails.contains(key) {
                    calendarEmails.insert(key)
                    dedupedCalendar.append(contact)
                }
            }
            
            // Cross-source dedup: if email in calendar, remove from main
            let calendarEmailSet = Set(dedupedCalendar.map { $0.email.lowercased() })
            dedupedMain = dedupedMain.filter { !calendarEmailSet.contains($0.email.lowercased()) }
            
            googleContacts = dedupedCalendar + dedupedMain
            
        } catch let error as GoogleContactsError {
            googleContactsError = error
        } catch {
            googleContactsError = error
        }
        
        loadingGoogleContacts = false
    }
    
    /// Fetch the authenticated user's email from Google userinfo endpoint
    private func fetchAuthenticatedUserEmail(accessToken: String) async -> String {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo") else { return "" }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["email"] as? String ?? ""
        } catch {
            return ""
        }
    }
    
    /// Fetch contacts from Google Workspace Directory
    /// Tries DOMAIN_PROFILE → DOMAIN_CONTACT → searchDirectoryPeople (matching RN SDK)
    private func fetchWorkspaceDirectory(accessToken: String) async throws -> [VortexContact] {
        let sources: [(String, String)] = [
            ("listDirectoryPeople", "https://people.googleapis.com/v1/people:listDirectoryPeople?sources=DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE&readMask=names,emailAddresses,photos&pageSize=1000"),
            ("listDirectoryPeople", "https://people.googleapis.com/v1/people:listDirectoryPeople?sources=DIRECTORY_SOURCE_TYPE_DOMAIN_CONTACT&readMask=names,emailAddresses,photos&pageSize=1000"),
            ("searchDirectoryPeople", "https://people.googleapis.com/v1/people:searchDirectoryPeople?sources=DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE&readMask=names,emailAddresses,photos&pageSize=500&query="),
        ]
        
        for (_, urlString) in sources {
            guard let url = URL(string: urlString) else { continue }
            do {
                var request = URLRequest(url: url)
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else { continue }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let people = json?["people"] as? [[String: Any]] ?? []
                if people.isEmpty { continue }
                
                var contacts: [VortexContact] = []
                for person in people {
                    guard let emailAddresses = person["emailAddresses"] as? [[String: Any]] else { continue }
                    let resourceName = person["resourceName"] as? String ?? UUID().uuidString
                    let names = person["names"] as? [[String: Any]]
                    let displayName = names?.first?["displayName"] as? String
                    let photos = person["photos"] as? [[String: Any]]
                    let photoUrl = photos?.first?["url"] as? String
                    let isDefaultPhoto = photos?.first?["default"] as? Bool ?? false
                    let imageUrl = (photoUrl != nil && !isDefaultPhoto) ? photoUrl : nil
                    
                    for emailObj in emailAddresses {
                        guard let email = emailObj["value"] as? String else { continue }
                        let key = "ws-\(resourceName)-\(email)"
                        let name = displayName ?? inferNameFromEmail(email)
                        contacts.append(VortexContact(id: key, name: name, email: email, source: .workspace, imageUrl: imageUrl))
                    }
                }
                return contacts
            } catch {
                continue
            }
        }
        return []
    }
    
    /// Fetch calendar guests from Google Calendar API and apply frequently contacted algorithm
    private func fetchCalendarGuests(accessToken: String) async throws -> [VortexContact] {
        let calendar = Calendar.current
        let now = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return [] }
        
        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: thirtyDaysAgo)
        let timeMax = formatter.string(from: now)
        
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&timeMax=\(timeMax)&maxResults=500&singleEvents=true"
        guard let url = URL(string: urlString) else { throw GoogleContactsError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GoogleContactsError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []
        
        // Count frequency of each attendee email
        var attendeeCounts: [String: (name: String, count: Int)] = [:]
        for event in items {
            guard let attendees = event["attendees"] as? [[String: Any]] else { continue }
            for attendee in attendees {
                guard let email = attendee["email"] as? String else { continue }
                let emailLower = email.lowercased().trimmingCharacters(in: .whitespaces)
                if emailLower.isEmpty { continue }
                // Skip self, resource calendars, and group calendars (matching RN)
                if emailLower == googleAuthenticatedEmail.lowercased() { continue }
                if emailLower.contains("resource.calendar.google.com") { continue }
                if emailLower.hasPrefix("group.calendar.google.com") { continue }
                let displayName = attendee["displayName"] as? String
                let name: String
                if let dn = displayName, !dn.isEmpty, dn != emailLower {
                    name = dn
                } else {
                    name = inferNameFromEmail(email)
                }
                if let existing = attendeeCounts[emailLower] {
                    attendeeCounts[emailLower] = (name: existing.name, count: existing.count + 1)
                } else {
                    attendeeCounts[emailLower] = (name: name, count: 1)
                }
            }
        }
        
        // Frequently contacted algorithm
        // 1. Require minimum 2 shared events
        let qualified = attendeeCounts.filter { $0.value.count >= 2 }
        // 2. Sort by frequency descending
        let sorted = qualified.sorted { $0.value.count > $1.value.count }
        // 3. Top 20%, capped at 10, floor of 3
        let twentyPercent = Int(ceil(Double(sorted.count) * 0.2))
        let limit = min(max(twentyPercent, 3), 10)
        let frequentlyContacted = Array(sorted.prefix(limit))
        // 4. Sort alphabetically by name
        let result = frequentlyContacted.sorted { $0.value.name.localizedCaseInsensitiveCompare($1.value.name) == .orderedAscending }
        
        return result.map { email, info in
            VortexContact(id: "cal-\(email)", name: info.name, email: email, source: .calendar)
        }
    }
    
    /// Switch Google account - signs out and re-fetches
    func switchGoogleAccount() async {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        googleContacts = []
        googleAuthenticatedEmail = ""
        await fetchGoogleContacts()
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
        #if canImport(GoogleSignIn)
        if #available(iOS 15.0, *) {
            // Configure GoogleSignIn with the client ID
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            
            // Build dynamic scopes based on enabled toggles
            let scopes = googleOAuthScopes
            
            // Try silent sign-in first (uses cached credentials)
            do {
                if GIDSignIn.sharedInstance.hasPreviousSignIn() {
                    let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                    
                    // Check if we have all required scopes
                    let grantedScopes = user.grantedScopes ?? []
                    let missingScopes = scopes.filter { !grantedScopes.contains($0) }
                    if missingScopes.isEmpty {
                        // Refresh tokens if needed
                        try await user.refreshTokensIfNeeded()
                        guard let accessToken = user.accessToken.tokenString as String? else {
                            throw GoogleContactsError.noAccessToken
                        }
                        return accessToken
                    } else {
                        // Need to request additional scopes
                        let result = try await user.addScopes(missingScopes, presenting: presentingVC)
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
                    additionalScopes: scopes
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
        } else {
            throw GoogleContactsError.signInUnavailable
        }
        #else
        throw GoogleContactsError.signInUnavailable
        #endif
    }
    
    /// Fetch contacts from Google People API
    private func fetchContactsFromPeopleAPI(accessToken: String) async throws -> [VortexContact] {
        let urlString = "https://people.googleapis.com/v1/people/me/connections?personFields=names,emailAddresses,photos&pageSize=1000"
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
            
            // Extract photo URL (skip default/placeholder photos)
            let photos = person["photos"] as? [[String: Any]]
            let photoUrl: String? = {
                guard let photo = photos?.first,
                      let url = photo["url"] as? String,
                      photo["default"] as? Bool != true else { return nil }
                return url
            }()
            
            for emailObj in emailAddresses {
                guard let email = emailObj["value"] as? String else { continue }
                let key = "\(resourceName)-\(email)"
                
                if contactMap[key] == nil {
                    let name = displayName ?? inferNameFromEmail(email)
                    contactMap[key] = VortexContact(id: key, name: name, email: email, imageUrl: photoUrl)
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
                groups: groups,
                metadata: unfurlConfig?.toMetadata()
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
                groups: groups,
                metadata: unfurlConfig?.toMetadata()
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
                    groups: groups,
                    metadata: unfurlConfig?.toMetadata()
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
    
    // MARK: - Find Friends
    
    /// Handle Connect button tap for a contact in Find Friends
    /// Creates an invitation with targetType=internalId
    func handleFindFriendsConnect(_ contact: FindFriendsContact) {
        guard findFriendsConfig != nil else { return }

        // Track the find friends invite button click
        trackFindFriendsInvite(contactId: contact.id, contactName: contact.name)

        findFriendsActionInProgress = contact.id

        Task {
            await createUserIdInvitation(for: contact)
            findFriendsActionInProgress = nil
        }
    }
    
    /// Create an invitation with target type = internalId
    private func createUserIdInvitation(for contact: FindFriendsContact) async {
        guard let jwt = jwt, let widgetConfig = configuration else {
            return
        }
        
        // The backend extracts targets from payload fields with type: "internal"
        // Key must be "internalId" (camelCase) to match React Native SDK
        // The value is an object { value: internalId, name: contactName, avatarUrl?: string } so the backend can populate target fields
        var targetValue: [String: Any] = [
            "value": contact.userId,
            "name": contact.name
        ]
        if let avatarUrl = contact.avatarUrl {
            targetValue["avatarUrl"] = avatarUrl
        }
        let payload: [String: Any] = [
            "internalId": [
                "type": "internal",
                "value": targetValue
            ]
        ]
        
        var groups: [GroupDTO]? = nil
        if let group = group {
            groups = [group]
        }
        
        // Merge contact metadata with unfurl metadata (contact metadata takes precedence)
        var mergedMetadata: [String: Any] = unfurlConfig?.toMetadata() ?? [:]
        if let contactMetadata = contact.metadata {
            for (key, value) in contactMetadata {
                mergedMetadata[key] = value
            }
        }
        
        do {
            _ = try await client.createInvitation(
                jwt: jwt,
                widgetConfigurationId: widgetConfig.id,
                payload: payload,
                source: "internal",
                groups: groups,
                metadata: mergedMetadata.isEmpty ? nil : mergedMetadata,
                subtype: "find-friends"
            )

            // Fire the invitation sent event so other components (like Outgoing Invitations) can refresh
            invitationSentEvent = InvitationSentEvent(
                source: .findFriends,
                shortLink: ""
            )

            // Mark contact as connected so it's removed from the list
            connectedFindFriendsContactIds.insert(contact.id)
            
            // Notify the customer that the invitation was created
            findFriendsConfig?.onInvitationCreated?(contact)
            
        } catch {
            // Invitation creation failed - contact remains in the list
        }
    }
    
    // MARK: - Outgoing Invitation Filtering

    /// Fetches outgoing invitations from the API and caches them.
    /// Also updates the outgoingInvitationUserIds set for filtering.
    func fetchOutgoingInvitations() async {
        guard let jwt = jwt else { return }

        // Fetch from API
        do {
            let fetched = try await client.getOutgoingInvitations(jwt: jwt)
            fetchedOutgoingInvitations = fetched
            // Update shared cache
            await VortexConfigurationCache.shared.setOutgoingInvitations(jwt: jwt, invitations: fetched)
        } catch {
            // Silently fail - keep previous fetched data
        }

        updateOutgoingInvitationUserIds()
        
        // Remove locally-connected Find Friends contacts whose invitations were revoked,
        // so they reappear in the Find Friends list.
        connectedFindFriendsContactIds = connectedFindFriendsContactIds.filter { outgoingInvitationUserIds.contains($0) }
    }

    /// Derives the set of user IDs from both internal and API-fetched outgoing invitations.
    private func updateOutgoingInvitationUserIds() {
        var userIds = Set<String>()
        if let internalInvitations = outgoingInvitationsConfig?.internalInvitations {
            for item in internalInvitations {
                if let userId = item.userId {
                    userIds.insert(userId)
                }
            }
        }
        for invitation in fetchedOutgoingInvitations {
            if let targetValue = invitation.targets?.first?.targetValue {
                userIds.insert(targetValue)
            }
        }
        outgoingInvitationUserIds = userIds
    }

    // MARK: - Invitation Suggestions
    
    /// Handle Invite button tap for a contact in Invitation Suggestions
    /// Creates an invitation with targetType=internalId
    func handleInvitationSuggestionInvite(_ contact: InvitationSuggestionContact) {
        guard invitationSuggestionsConfig != nil else { return }

        // Track the PYMK invite button click
        trackPymkInvite(suggestionId: contact.id, suggestionName: contact.name)

        invitationSuggestionsActionInProgress = contact.id

        Task {
            // Create invitation with targetType = internalId
            await createInvitationSuggestionInvitation(for: contact)
            
            invitationSuggestionsActionInProgress = nil
        }
    }
    
    /// Handle Dismiss (X) button tap for a contact in Invitation Suggestions
    func handleInvitationSuggestionDismiss(_ contact: InvitationSuggestionContact) {
        // Track the PYMK delete/dismiss button click
        trackPymkDelete(suggestionId: contact.id, suggestionName: contact.name)

        // Mark as dismissed so it's removed from the list
        dismissedInvitationSuggestionIds.insert(contact.id)

        // Call the customer's onDismiss callback
        invitationSuggestionsConfig?.onDismiss(contact)
    }
    
    /// Create an invitation for an invitation suggestion with target type = internalId
    private func createInvitationSuggestionInvitation(for contact: InvitationSuggestionContact) async {
        guard let jwt = jwt, let widgetConfig = configuration else {
            invitationSuggestionsConfig?.onInvitationFailed?(contact, VortexError.missingConfiguration)
            return
        }
        
        // The backend extracts targets from payload fields with type: "internal"
        // Key must be "internalId" (camelCase) to match React Native SDK
        // The value is an object { value: internalId, name: contactName, avatarUrl?: string } so the backend can populate target fields
        var targetValue: [String: Any] = [
            "value": contact.userId,
            "name": contact.name
        ]
        if let avatarUrl = contact.avatarUrl {
            targetValue["avatarUrl"] = avatarUrl
        }
        let payload: [String: Any] = [
            "internalId": [
                "type": "internal",
                "value": targetValue
            ]
        ]
        
        var groups: [GroupDTO]? = nil
        if let group = group {
            groups = [group]
        }
        
        // Merge contact metadata with unfurl metadata (contact metadata takes precedence)
        var mergedMetadata: [String: Any] = unfurlConfig?.toMetadata() ?? [:]
        if let contactMetadata = contact.metadata {
            for (key, value) in contactMetadata {
                mergedMetadata[key] = value
            }
        }
        
        do {
            _ = try await client.createInvitation(
                jwt: jwt,
                widgetConfigurationId: widgetConfig.id,
                payload: payload,
                source: "internal",
                groups: groups,
                metadata: mergedMetadata.isEmpty ? nil : mergedMetadata,
                subtype: "suggestions"
            )

            // Fire the invitation sent event so other components (like Outgoing Invitations) can refresh
            invitationSentEvent = InvitationSentEvent(
                source: .invitationSuggestions,
                shortLink: ""
            )
            
            // Mark contact as invited so it's removed from the list
            invitedInvitationSuggestionIds.insert(contact.id)
            
            // Notify the customer that the invitation was created
            invitationSuggestionsConfig?.onInvitationCreated?(contact)
            
        } catch {
            invitationSuggestionsConfig?.onInvitationFailed?(contact, error)
        }
    }
    
    // MARK: - Search Box
    
    /// Handle search button tap in Search Box
    func handleSearchBoxSearch() {
        guard let config = searchBoxConfig, !searchBoxQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        searchBoxIsSearching = true
        
        Task {
            do {
                let results = await config.onSearch(searchBoxQuery.trimmingCharacters(in: .whitespaces))
                searchBoxResults = results
            }
            searchBoxIsSearching = false
        }
    }
    
    /// Handle Connect button tap for a contact in Search Box results
    func handleSearchBoxConnect(_ contact: SearchBoxContact) {
        guard searchBoxConfig != nil else { return }
        
        searchBoxDismissFocusToken += 1
        searchBoxActionInProgress = contact.id
        
        Task {
            await performSearchBoxConnect(contact)
            searchBoxActionInProgress = nil
        }
    }
    
    /// Perform the search box connect action
    private func performSearchBoxConnect(_ contact: SearchBoxContact) async {
        guard searchBoxConfig != nil else { return }
        
        // Create invitation via backend (identical to Find Friends behavior)
        await createSearchBoxInvitation(for: contact)
    }
    
    /// Create an invitation for a search box result with target type = internalId
    private func createSearchBoxInvitation(for contact: SearchBoxContact) async {
        guard let jwt = jwt, let widgetConfig = configuration else {
            return
        }
        
        var targetValue: [String: Any] = [
            "value": contact.userId,
            "name": contact.name
        ]
        if let avatarUrl = contact.avatarUrl {
            targetValue["avatarUrl"] = avatarUrl
        }
        let payload: [String: Any] = [
            "internalId": [
                "type": "internal",
                "value": targetValue
            ]
        ]
        
        var groups: [GroupDTO]? = nil
        if let group = group {
            groups = [group]
        }
        
        // Merge contact metadata with unfurl metadata (contact metadata takes precedence)
        var mergedMetadata: [String: Any] = unfurlConfig?.toMetadata() ?? [:]
        if let contactMetadata = contact.metadata {
            for (key, value) in contactMetadata {
                mergedMetadata[key] = value
            }
        }
        
        do {
            _ = try await client.createInvitation(
                jwt: jwt,
                widgetConfigurationId: widgetConfig.id,
                payload: payload,
                source: "internal",
                groups: groups,
                metadata: mergedMetadata.isEmpty ? nil : mergedMetadata,
                subtype: "search-box"
            )

            invitationSentEvent = InvitationSentEvent(
                source: .findFriends,
                shortLink: ""
            )

            // Remove the connected contact from the search results list
            searchBoxResults?.removeAll { $0.id == contact.id }
            
            // If all results have been connected, clear the search state
            if searchBoxResults?.isEmpty == true {
                searchBoxResults = nil
                searchBoxQuery = ""
            }
            
            // Notify the customer that the invitation was created
            searchBoxConfig?.onInvitationCreated?(contact)
            
        } catch {
            // Invitation creation failed - contact remains in the list
        }
    }
}
