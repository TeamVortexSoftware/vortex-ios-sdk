import SwiftUI

/// View that displays a list of contacts with Connect buttons
/// When user taps Connect, the onConnect callback is called. If it returns true,
/// an invitation with target type = internalId is created.
struct FindFriendsView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    /// Title from block attributes
    private var title: String? {
        block.attributes?["title"]?.stringValue
    }
    
    /// Contacts from findFriendsConfig, excluding already connected ones
    private var contacts: [FindFriendsContact] {
        let allContacts = viewModel.findFriendsConfig?.contacts ?? []
        return allContacts.filter { !viewModel.connectedFindFriendsContactIds.contains($0.id) }
    }
    
    /// Primary color from theme or default blue
    private var primaryColor: Color {
        viewModel.surfaceForegroundColor ?? Color(red: 0x62/255, green: 0x91/255, blue: 0xd5/255)
    }
    
    /// Theme colors for UI elements
    private var foregroundColor: Color {
        viewModel.themeForeground ?? Color(red: 0x33/255, green: 0x41/255, blue: 0x53/255)
    }
    
    /// Get a theme option value from block.theme.options by key
    private func getBlockThemeValue(_ key: String) -> String? {
        guard let options = block.theme?.options else { return nil }
        return options.first { $0.key == key }?.value
    }
    
    // MARK: - Title Styles
    
    private var titleColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-title-color"),
           let color = Color(hex: value) {
            return color
        }
        return foregroundColor
    }
    
    private var titleFontSize: CGFloat {
        if let value = getBlockThemeValue("--vrtx-find-friends-title-font-size"),
           let size = Double(value.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 18
    }
    
    private var titleFontWeight: Font.Weight {
        if let value = getBlockThemeValue("--vrtx-find-friends-title-font-weight") {
            switch value {
            case "100": return .ultraLight
            case "200": return .thin
            case "300": return .light
            case "400": return .regular
            case "500": return .medium
            case "600": return .semibold
            case "700": return .bold
            case "800": return .heavy
            case "900": return .black
            default: return .semibold
            }
        }
        return .semibold
    }
    
    var body: some View {
        Group {
            if viewModel.findFriendsConfig == nil {
                placeholderView
            } else if contacts.isEmpty {
                // No-op: render nothing (0 height) when no contacts are provided
                EmptyView()
            } else {
                contactsListView
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
    
    
    // MARK: - Contacts List View
    
    private var contactsListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title above the contacts list (like Outgoing Invitations)
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.system(size: titleFontSize, weight: titleFontWeight))
                    .foregroundColor(titleColor)
                    .padding(.bottom, 16)
            }
            
            LazyVStack(spacing: 0) {
                ForEach(contacts) { contact in
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
}

// MARK: - Contact Item View

private struct FindFriendsContactItemView: View {
    let contact: FindFriendsContact
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    private var isLoading: Bool {
        viewModel.findFriendsActionInProgress == contact.id
    }
    
    private var buttonText: String {
        // Get text from widget config customizations
        if let customText = block.settings?.customizations?["connectButton"]?.textContent {
            return customText
        }
        return "Connect"
    }
    
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
        secondaryForeground: Color,
        foreground: Color
    ) {
        (
            primaryBackground: viewModel.themePrimaryBackground ?? Color(red: 0x62/255, green: 0x91/255, blue: 0xd5/255),
            primaryForeground: viewModel.themePrimaryForeground ?? .white,
            secondaryForeground: viewModel.themeSecondaryForeground ?? Color(red: 0x35/255, green: 0x3e/255, blue: 0x5c/255),
            foreground: viewModel.themeForeground ?? Color(red: 0x33/255, green: 0x41/255, blue: 0x53/255)
        )
    }
    
    // MARK: - Avatar Styles
    
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
    
    // MARK: - Contact Name Styles
    
    private var contactNameColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-contact-name-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.foreground
    }
    
    // MARK: - Contact Subtitle Styles
    
    private var contactSubtitleColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-contact-subtitle-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.secondaryForeground
    }
    
    // MARK: - Connect Button Styles
    
    private var connectButtonBackgroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-find-friends-connect-button-background") {
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
    
    // MARK: - Gradient Parsing Helpers
    
    private struct ParsedGradient {
        let colors: [Color]
        let stops: [CGFloat]
        let angle: Double
        
        var startPoint: UnitPoint {
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
    
    private func parseLinearGradient(_ gradientString: String) -> ParsedGradient? {
        guard gradientString.contains("linear-gradient") else {
            return nil
        }
        
        var angle: Double = 180
        let anglePattern = #"linear-gradient\s*\(\s*(\d+)deg"#
        if let angleRegex = try? NSRegularExpression(pattern: anglePattern, options: .caseInsensitive),
           let angleMatch = angleRegex.firstMatch(in: gradientString, range: NSRange(gradientString.startIndex..., in: gradientString)),
           angleMatch.numberOfRanges >= 2,
           let angleRange = Range(angleMatch.range(at: 1), in: gradientString),
           let parsedAngle = Double(gradientString[angleRange]) {
            angle = parsedAngle
        }
        
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
    
    private func parseGradientFirstColor(_ gradientString: String) -> Color? {
        guard let gradient = parseLinearGradient(gradientString),
              let firstColor = gradient.colors.first else {
            return nil
        }
        return firstColor
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
    
    private var connectButtonBackgroundValue: String? {
        getBlockThemeValue("--vrtx-find-friends-connect-button-background")
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
                
                if let subtitle = contact.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(contactSubtitleColor)
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
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private var avatarView: some View {
        if let avatarUrl = contact.avatarUrl, let url = URL(string: avatarUrl) {
            if #available(iOS 15.0, *) {
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
        let backgroundValue = connectButtonBackgroundValue
        let foregroundColor = connectButtonForegroundColor
        let borderColor = connectButtonBorderColor
        let borderWidth = connectButtonBorderWidth
        let cornerRadius = connectButtonCornerRadius
        
        Button(action: {
            viewModel.handleFindFriendsConnect(contact)
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
    
    @ViewBuilder
    private func buttonBackground(for backgroundValue: String?, cornerRadius: CGFloat) -> some View {
        if let value = backgroundValue, let gradient = parseLinearGradient(value) {
            LinearGradient(
                stops: zip(gradient.colors, gradient.stops).map { Gradient.Stop(color: $0, location: $1) },
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
        } else if let value = backgroundValue, let color = Color(hex: value) {
            color
        } else {
            defaultColors.primaryBackground
        }
    }
}
