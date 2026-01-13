import SwiftUI

/// Loading state for the Find Friends component
enum FindFriendsLoadingState: Equatable {
    case idle
    case fetching
    case classifying
    case error(String)
}

/// View that displays a list of contacts with Connect/Invite buttons
/// Members show "Connect" button, non-members show "Invite" button
struct FindFriendsView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    /// Track if contacts have been loaded to prevent re-loading
    @State private var hasLoaded = false
    
    /// Track if showing the non-members list (secondary view)
    @State private var showNonMembersList = false
    
    /// Primary color from theme or default blue
    private var primaryColor: Color {
        viewModel.surfaceForegroundColor ?? Color(red: 0x62/255, green: 0x91/255, blue: 0xd5/255)
    }
    
    /// Filtered list of member contacts (shown in main view)
    private var memberContacts: [FindFriendsClassifiedContact] {
        viewModel.findFriendsContacts.filter { $0.status == .member }
    }
    
    /// Filtered list of non-member contacts (shown in secondary view)
    private var nonMemberContacts: [FindFriendsClassifiedContact] {
        viewModel.findFriendsContacts.filter { $0.status == .nonMember }
    }
    
    /// Text for the "Invite your contacts" entry
    private var inviteContactsEntryText: String {
        // Check block customizations first, then config, then default
        if let customText = block.attributes?["inviteContactsEntryText"]?.stringValue {
            return customText
        }
        return viewModel.findFriendsConfig?.inviteContactsEntryText ?? "Invite your contacts"
    }
    
    /// Theme colors for UI elements
    private var foregroundColor: Color {
        viewModel.themeForeground ?? Color(red: 0x33/255, green: 0x41/255, blue: 0x53/255)
    }
    
    private var secondaryForegroundColor: Color {
        viewModel.themeSecondaryForeground ?? Color(red: 0x35/255, green: 0x3e/255, blue: 0x5c/255)
    }
    
    var body: some View {
        Group {
            if viewModel.findFriendsConfig == nil {
                placeholderView
            } else {
                switch viewModel.findFriendsLoadingState {
                case .fetching, .classifying:
                    loadingView
                case .error(let message):
                    errorView(message: message)
                case .idle:
                    if viewModel.findFriendsContacts.isEmpty {
                        emptyView
                    } else if showNonMembersList {
                        // Secondary view: Non-members list
                        nonMembersListView
                    } else {
                        // Main view: Members list with "Invite your contacts" entry
                        membersListView
                    }
                }
            }
        }
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                viewModel.loadFindFriendsContacts()
            }
        }
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            if let label = block.attributes?["label"]?.stringValue {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            Text("Find Friends component - provide findFriendsConfig to enable")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(minHeight: 120)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text(viewModel.findFriendsLoadingState == .fetching 
                 ? (viewModel.findFriendsConfig?.loadingMessage ?? "Finding friends...")
                 : "Classifying contacts...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(minHeight: 120)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.85, green: 0.33, blue: 0.31))
                .multilineTextAlignment(.center)
            
            Button(action: {
                viewModel.loadFindFriendsContacts()
            }) {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(primaryColor)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .frame(minHeight: 120)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack {
            Text(viewModel.findFriendsConfig?.emptyStateMessage ?? "No contacts found")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(minHeight: 120)
    }
    
    // MARK: - Members List View (Main View)
    
    private var membersListView: some View {
        LazyVStack(spacing: 0) {
            if memberContacts.isEmpty {
                // No members but have non-members - show invite entry only
                if !nonMemberContacts.isEmpty {
                    inviteContactsEntryView
                } else {
                    // Fallback empty state (shouldn't happen as we check isEmpty above)
                    Text(viewModel.findFriendsConfig?.emptyStateMessage ?? "No contacts found")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(16)
                }
            } else {
                // Show member contacts
                ForEach(memberContacts) { contact in
                    FindFriendsContactItemView(
                        contact: contact,
                        block: block,
                        viewModel: viewModel
                    )
                }
                
                // Show "Invite your contacts" entry at the bottom if there are non-members
                if !nonMemberContacts.isEmpty {
                    inviteContactsEntryView
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    // MARK: - Non-Members List View (Secondary View)
    
    private var nonMembersListView: some View {
        LazyVStack(spacing: 0) {
            // Back header
            backHeaderView
            
            if nonMemberContacts.isEmpty {
                Text("No contacts to invite")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(16)
            } else {
                ForEach(nonMemberContacts) { contact in
                    FindFriendsContactItemView(
                        contact: contact,
                        block: block,
                        viewModel: viewModel
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    // MARK: - Invite Contacts Entry View
    
    private var inviteContactsEntryView: some View {
        Button(action: {
            showNonMembersList = true
            viewModel.findFriendsConfig?.onNavigateToInviteContacts?()
        }) {
            HStack {
                HStack(spacing: 8) {
                    Text(inviteContactsEntryText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(foregroundColor)
                    
                    Text("\(nonMemberContacts.count)")
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
        .padding(.top, 8)
    }
    
    // MARK: - Back Header View
    
    private var backHeaderView: some View {
        Button(action: {
            showNonMembersList = false
            viewModel.findFriendsConfig?.onNavigateBackFromInviteContacts?()
        }) {
            HStack(spacing: 4) {
                Text("‹")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(secondaryForegroundColor)
                
                Text("Back")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foregroundColor)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

// MARK: - Contact Item View

private struct FindFriendsContactItemView: View {
    let contact: FindFriendsClassifiedContact
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    private var isMember: Bool {
        contact.status == .member
    }
    
    private var isLoading: Bool {
        viewModel.findFriendsActionInProgress == contact.id
    }
    
    private var buttonText: String {
        if isMember {
            return viewModel.findFriendsConfig?.connectButtonText ?? "Connect"
        } else {
            return viewModel.findFriendsConfig?.inviteButtonText ?? "Invite"
        }
    }
    
    // MARK: - Theme Color Helpers
    
    /// Get a theme option value from block.theme.options by key
    private func getBlockThemeValue(_ key: String) -> String? {
        guard let options = block.theme?.options else { return nil }
        return options.first { $0.key == key }?.value
    }
    
    /// Theme colors with fallback chain: block.theme.options > vortex.theme > hardcoded defaults
    /// This matches the RN SDK's priority for color resolution
    private var defaultColors: (
        primaryBackground: Color,
        primaryForeground: Color,
        secondaryBackground: Color,
        secondaryForeground: Color,
        foreground: Color,
        border: Color
    ) {
        (
            // Use ViewModel's theme colors (from vortex.theme) as first fallback, then hardcoded defaults
            primaryBackground: viewModel.themePrimaryBackground ?? Color(red: 0x62/255, green: 0x91/255, blue: 0xd5/255),
            primaryForeground: viewModel.themePrimaryForeground ?? .white,
            secondaryBackground: viewModel.themeSecondaryBackground ?? Color(UIColor.tertiarySystemBackground),
            secondaryForeground: viewModel.themeSecondaryForeground ?? Color(red: 0x35/255, green: 0x3e/255, blue: 0x5c/255),
            foreground: viewModel.themeForeground ?? Color(red: 0x33/255, green: 0x41/255, blue: 0x53/255),
            border: viewModel.themeBorder ?? Color(UIColor.separator)
        )
    }
    
    // MARK: - Avatar Styles (from block.theme.options)
    
    private var avatarBackgroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-avatar-background"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryBackground
    }
    
    private var avatarForegroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-avatar-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryForeground
    }
    
    // MARK: - Contact Name Styles (from block.theme.options)
    
    private var contactNameColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-contact-name-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.foreground
    }
    
    // MARK: - Contact Email Styles (from block.theme.options)
    
    private var contactEmailColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-contact-email-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.secondaryForeground
    }
    
    // MARK: - Connect Button Styles (from block.theme.options)
    
    private var connectButtonBackgroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-connect-button-background") {
            // Try parsing as gradient first, then as solid color
            if let color = parseGradientFirstColor(value) {
                return color
            }
            if let color = Color(hex: value) {
                return color
            }
        }
        return defaultColors.primaryBackground
    }
    
    private var connectButtonForegroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-connect-button-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryForeground
    }
    
    private var connectButtonBorderColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-connect-button-border") {
            // Parse border string like "1px solid #ccc"
            if let color = parseBorderColor(value) {
                return color
            }
        }
        return .clear
    }
    
    private var connectButtonBorderWidth: CGFloat {
        if let value = getBlockThemeValue("--vrtx-find-friends-connect-button-border") {
            return parseBorderWidth(value)
        }
        return 0
    }
    
    private var connectButtonCornerRadius: CGFloat {
        if let value = getBlockThemeValue("--vrtx-find-friends-connect-button-borderRadius"),
           let radius = Double(value.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(radius)
        }
        return 8
    }
    
    // MARK: - Invite Button Styles (from block.theme.options)
    
    private var inviteButtonBackgroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-invite-button-background") {
            // Try parsing as gradient first, then as solid color
            if let color = parseGradientFirstColor(value) {
                return color
            }
            if let color = Color(hex: value) {
                return color
            }
        }
        return defaultColors.secondaryBackground
    }
    
    private var inviteButtonForegroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-invite-button-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.secondaryForeground
    }
    
    private var inviteButtonBorderColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-invite-button-border") {
            if let color = parseBorderColor(value) {
                return color
            }
        }
        return defaultColors.border
    }
    
    private var inviteButtonBorderWidth: CGFloat {
        if let value = getBlockThemeValue("--vrtx-find-friends-invite-button-border") {
            return parseBorderWidth(value)
        }
        return 1
    }
    
    private var inviteButtonCornerRadius: CGFloat {
        if let value = getBlockThemeValue("--vrtx-find-friends-invite-button-borderRadius"),
           let radius = Double(value.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(radius)
        }
        return 8
    }
    
    // MARK: - Gradient Parsing Helpers
    
    /// Parsed gradient data structure
    private struct ParsedGradient {
        let colors: [Color]
        let stops: [CGFloat]
        let angle: Double // in degrees
        
        /// Convert angle to SwiftUI start/end points
        var startPoint: UnitPoint {
            // Convert CSS angle (0deg = to top, 90deg = to right) to SwiftUI UnitPoint
            let radians = (angle - 90) * .pi / 180
            let x = 0.5 - cos(radians) * 0.5
            let y = 0.5 + sin(radians) * 0.5
            return UnitPoint(x: x, y: y)
        }
        
        var endPoint: UnitPoint {
            let radians = (angle - 90) * .pi / 180
            let x = 0.5 + cos(radians) * 0.5
            let y = 0.5 - sin(radians) * 0.5
            return UnitPoint(x: x, y: y)
        }
    }
    
    /// Parse CSS linear-gradient to extract all colors and stops
    /// Example: "linear-gradient(90deg, #ff9e99 0%, #cad34b 100%)" -> ParsedGradient
    private func parseLinearGradient(_ gradientString: String) -> ParsedGradient? {
        guard gradientString.contains("linear-gradient") else {
            return nil
        }
        
        // Extract angle (default to 180deg if not specified - top to bottom)
        var angle: Double = 180
        let anglePattern = #"linear-gradient\s*\(\s*(\d+)deg"#
        if let angleRegex = try? NSRegularExpression(pattern: anglePattern, options: .caseInsensitive),
           let angleMatch = angleRegex.firstMatch(in: gradientString, range: NSRange(gradientString.startIndex..., in: gradientString)),
           angleMatch.numberOfRanges >= 2,
           let angleRange = Range(angleMatch.range(at: 1), in: gradientString),
           let parsedAngle = Double(gradientString[angleRange]) {
            angle = parsedAngle
        }
        
        // Extract all color stops
        let colorPattern = #"(rgba?\([^)]+\)|#[0-9a-fA-F]{3,8})\s+(\d+)%"#
        guard let colorRegex = try? NSRegularExpression(pattern: colorPattern, options: .caseInsensitive) else {
            return nil
        }
        
        let matches = colorRegex.matches(in: gradientString, range: NSRange(gradientString.startIndex..., in: gradientString))
        
        var colors: [Color] = []
        var stops: [CGFloat] = []
        
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let colorRange = Range(match.range(at: 1), in: gradientString),
                  let stopRange = Range(match.range(at: 2), in: gradientString) else {
                continue
            }
            
            let colorStr = String(gradientString[colorRange]).trimmingCharacters(in: .whitespaces)
            let stopStr = String(gradientString[stopRange])
            
            if let color = Color(hex: colorStr),
               let stopValue = Double(stopStr) {
                colors.append(color)
                stops.append(CGFloat(stopValue / 100.0))
            }
        }
        
        guard colors.count >= 2 else {
            return nil
        }
        
        return ParsedGradient(colors: colors, stops: stops, angle: angle)
    }
    
    /// Parse CSS linear-gradient to extract first color for fallback (legacy)
    /// Matches the RN SDK's parseGradientFirstColor function
    /// Example: "linear-gradient(90deg, #ff9e99 0%, #cad34b 100%)" -> "#ff9e99"
    private func parseGradientFirstColor(_ gradientString: String) -> Color? {
        guard let gradient = parseLinearGradient(gradientString),
              let firstColor = gradient.colors.first else {
            return nil
        }
        return firstColor
    }
    
    /// Check if a string contains a gradient
    private func isGradient(_ value: String?) -> Bool {
        guard let value = value else { return false }
        return value.contains("linear-gradient")
    }
    
    /// Get the raw background value for connect button
    private var connectButtonBackgroundValue: String? {
        getBlockThemeValue("--vrtx-find-friends-connect-button-background")
    }
    
    /// Get the raw background value for invite button
    private var inviteButtonBackgroundValue: String? {
        getBlockThemeValue("--vrtx-find-friends-invite-button-background")
    }
    
    // MARK: - Border Parsing Helpers
    
    /// Parse border color from CSS border string like "1px solid #ccc"
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
    
    /// Parse border width from CSS border string like "1px solid #ccc"
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
            
            // Contact info - marginLeft 12, marginRight 12 to match RN SDK
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(contactNameColor)
                    .lineLimit(1)
                
                if let email = contact.emails.first {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundColor(contactEmailColor)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            
            Spacer()
            
            // Action button
            actionButton
        }
        .padding(.vertical, 12)
        // No horizontal padding on contactItem - matches RN SDK's contactItem style
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
        let backgroundValue = isMember ? connectButtonBackgroundValue : inviteButtonBackgroundValue
        let foregroundColor = isMember ? connectButtonForegroundColor : inviteButtonForegroundColor
        let borderColor = isMember ? connectButtonBorderColor : inviteButtonBorderColor
        let borderWidth = isMember ? connectButtonBorderWidth : inviteButtonBorderWidth
        let cornerRadius = isMember ? connectButtonCornerRadius : inviteButtonCornerRadius
        
        Button(action: {
            if isMember {
                viewModel.handleFindFriendsConnect(contact)
            } else {
                viewModel.handleFindFriendsInvite(contact)
            }
        }) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text(buttonText)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: 80)
            .foregroundColor(foregroundColor)
            .background(buttonBackground(for: backgroundValue, cornerRadius: cornerRadius))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .disabled(isLoading)
    }
    
    /// Creates the appropriate background for a button - either a LinearGradient or solid Color
    @ViewBuilder
    private func buttonBackground(for backgroundValue: String?, cornerRadius: CGFloat) -> some View {
        if let value = backgroundValue, let gradient = parseLinearGradient(value) {
            // Use LinearGradient with all color stops
            LinearGradient(
                stops: zip(gradient.colors, gradient.stops).map { Gradient.Stop(color: $0, location: $1) },
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
        } else if let value = backgroundValue, let color = Color(hex: value) {
            // Solid color from theme
            color
        } else {
            // Default fallback color
            if isMember {
                defaultColors.primaryBackground
            } else {
                defaultColors.secondaryBackground
            }
        }
    }
}
