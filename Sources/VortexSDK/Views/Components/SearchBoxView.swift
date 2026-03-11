import SwiftUI

/// View that displays a search box with a search button, and renders matching contacts below.
/// When user taps Connect, an invitation is created via the Vortex backend.
struct SearchBoxView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    /// Title from block attributes
    private var title: String? {
        block.attributes?["title"]?.stringValue
    }
    
    /// Placeholder text from block settings customizations
    private var placeholder: String {
        block.settings?.customizations?["searchPlaceholder"]?.textContent ?? "Search..."
    }
    
    /// Connect button text from block settings customizations
    private var connectButtonText: String {
        block.settings?.customizations?["connectButton"]?.textContent ?? "Connect"
    }
    
    /// No results message from block settings customizations
    private var noResultsMessage: String {
        block.settings?.customizations?["noResultsMessage"]?.textContent ?? "No results found"
    }
    
    /// Primary color from theme or default blue
    private var primaryColor: Color {
        viewModel.surfaceForegroundColor ?? Color(red: 0x62/255, green: 0x91/255, blue: 0xd5/255)
    }
    
    /// Theme colors for UI elements
    private var foregroundColor: Color {
        viewModel.themeForeground ?? Color(red: 0x33/255, green: 0x41/255, blue: 0x53/255)
    }
    
    private var secondaryForegroundColor: Color {
        viewModel.themeSecondaryForeground ?? Color(red: 0x35/255, green: 0x3e/255, blue: 0x5c/255)
    }
    
    private var borderColor: Color {
        viewModel.themeBorder ?? Color(red: 0xcc/255, green: 0xcc/255, blue: 0xcc/255)
    }
    
    /// Get a theme option value from block.theme.options by key
    private func getBlockThemeValue(_ key: String) -> String? {
        guard let options = block.theme?.options else { return nil }
        return options.first { $0.key == key }?.value
    }
    
    // MARK: - Input Styles
    
    private var inputColor: Color? {
        if let value = getBlockThemeValue("--vrtx-search-box-input-color"),
           let color = Color(hex: value) {
            return color
        }
        return nil
    }
    
    private var inputFontSize: CGFloat {
        if let value = getBlockThemeValue("--vrtx-search-box-input-font-size"),
           let size = Double(value.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 16
    }
    
    private var inputFontWeight: Font.Weight {
        if let value = getBlockThemeValue("--vrtx-search-box-input-font-weight") {
            return parseFontWeight(value)
        }
        return .regular
    }
    
    // MARK: - Placeholder Styles
    
    private var placeholderColor: Color? {
        if let value = getBlockThemeValue("--vrtx-search-box-placeholder-color"),
           let color = Color(hex: value) {
            return color
        }
        return nil
    }
    
    // MARK: - Title Styles
    
    private var titleColor: Color {
        if let value = getBlockThemeValue("--vrtx-search-box-title-color"),
           let color = Color(hex: value) {
            return color
        }
        return foregroundColor
    }
    
    private var titleFontSize: CGFloat {
        if let value = getBlockThemeValue("--vrtx-search-box-title-font-size"),
           let size = Double(value.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 18
    }
    
    private var titleFontWeight: Font.Weight {
        if let value = getBlockThemeValue("--vrtx-search-box-title-font-weight") {
            return parseFontWeight(value)
        }
        return .semibold
    }
    
    var body: some View {
        Group {
            if viewModel.searchBoxConfig == nil {
                placeholderView
            } else {
                searchBoxContentView
            }
        }
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.system(size: titleFontSize, weight: titleFontWeight))
                    .foregroundColor(titleColor)
            }
            Text("Search Box component - provide searchBoxConfig to enable")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(minHeight: 120)
    }
    
    // MARK: - Search Box Content View
    
    private var searchBoxContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Optional title
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.system(size: titleFontSize, weight: titleFontWeight))
                    .foregroundColor(titleColor)
                    .padding(.bottom, 16)
            }
            
            // Search input row
            searchRow
            
            // Results
            if let allResults = viewModel.searchBoxResults {
                let results = allResults.filter { !viewModel.outgoingInvitationUserIds.contains($0.userId) }
                if results.isEmpty && !viewModel.searchBoxIsSearching {
                    // No results message
                    Text(noResultsMessage)
                        .font(.system(size: 14))
                        .foregroundColor(secondaryForegroundColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                } else if !results.isEmpty {
                    // Results list
                    LazyVStack(spacing: 0) {
                        ForEach(results) { contact in
                            SearchBoxContactItemView(
                                contact: contact,
                                block: block,
                                viewModel: viewModel,
                                connectButtonText: connectButtonText
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Search Row
    
    @ViewBuilder
    private var searchRow: some View {
        if #available(iOS 15.0, *) {
            SearchRowFocusable(
                placeholder: placeholder,
                placeholderColor: placeholderColor,
                inputColor: inputColor,
                inputFontSize: inputFontSize,
                inputFontWeight: inputFontWeight,
                query: $viewModel.searchBoxQuery,
                foregroundColor: foregroundColor,
                borderColor: borderColor,
                isSearching: viewModel.searchBoxIsSearching,
                isDisabled: viewModel.searchBoxQuery.trimmingCharacters(in: .whitespaces).isEmpty,
                searchButtonForegroundColor: searchButtonForegroundColor,
                searchButtonBackgroundValue: searchButtonBackgroundValue,
                defaultPrimaryBackground: defaultPrimaryBackground,
                parseGradient: parseSearchButtonLinearGradient,
                dismissFocusToken: viewModel.searchBoxDismissFocusToken,
                onCommit: { viewModel.handleSearchBoxSearch() }
            )
            .padding(.bottom, 12)
        } else {
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if viewModel.searchBoxQuery.isEmpty {
                        Text(placeholder)
                            .font(.system(size: inputFontSize))
                            .foregroundColor(placeholderColor ?? Color(UIColor.placeholderText))
                            .padding(.horizontal, 12)
                    }
                    TextField("", text: $viewModel.searchBoxQuery, onCommit: {
                        viewModel.handleSearchBoxSearch()
                    })
                    .font(.system(size: inputFontSize, weight: inputFontWeight))
                    .foregroundColor(inputColor ?? foregroundColor)
                    .padding(.horizontal, 12)
                }
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                
                searchButton
            }
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Search Button
    
    private var searchButtonBackgroundValue: String? {
        getBlockThemeValue("--vrtx-search-box-search-button-background")
    }
    
    private var searchButtonForegroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-search-box-search-button-color"),
           let color = Color(hex: value) {
            return color
        }
        return viewModel.themePrimaryForeground ?? .white
    }
    
    private var defaultPrimaryBackground: Color {
        viewModel.themePrimaryBackground ?? Color(red: 0x62/255, green: 0x91/255, blue: 0xd5/255)
    }
    
    @ViewBuilder
    private func searchButtonBackground(cornerRadius: CGFloat) -> some View {
        if let value = searchButtonBackgroundValue, let gradient = parseSearchButtonLinearGradient(value) {
            LinearGradient(
                stops: zip(gradient.colors, gradient.stops).map { Gradient.Stop(color: $0, location: $1) },
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
        } else if let value = searchButtonBackgroundValue, let color = Color(hex: value) {
            color
        } else {
            defaultPrimaryBackground
        }
    }
    
    private var searchButton: some View {
        Button(action: {
            viewModel.handleSearchBoxSearch()
        }) {
            Group {
                if viewModel.searchBoxIsSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .foregroundColor(searchButtonForegroundColor)
            .frame(width: 44, height: 44)
            .background(searchButtonBackground(cornerRadius: 8))
            .cornerRadius(8)
        }
        .disabled(viewModel.searchBoxIsSearching || viewModel.searchBoxQuery.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    
    // MARK: - Helpers
    
    private func parseFontWeight(_ value: String) -> Font.Weight {
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
    
    // MARK: - Search Button Gradient Parsing
    
    private func parseSearchButtonLinearGradient(_ gradientString: String) -> SearchButtonGradient? {
        guard gradientString.contains("linear-gradient") else { return nil }
        
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
        
        guard colors.count >= 2 else { return nil }
        return SearchButtonGradient(colors: colors, stops: stops, angle: angle)
    }
}

// MARK: - Contact Item View

private struct SearchBoxContactItemView: View {
    let contact: SearchBoxContact
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    let connectButtonText: String
    
    private var isLoading: Bool {
        viewModel.searchBoxActionInProgress == contact.id
    }
    
    /// Get a theme option value from block.theme.options by key
    private func getBlockThemeValue(_ key: String) -> String? {
        guard let options = block.theme?.options else { return nil }
        return options.first { $0.key == key }?.value
    }
    
    /// Theme colors with fallback chain
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
        if let value = getBlockThemeValue("--vrtx-search-box-avatar-background"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryBackground
    }
    
    private var avatarForegroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-search-box-avatar-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryForeground
    }
    
    // MARK: - Contact Name Styles
    
    private var contactNameColor: Color {
        if let value = getBlockThemeValue("--vrtx-search-box-contact-name-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.foreground
    }
    
    // MARK: - Contact Subtitle Styles
    
    private var contactSubtitleColor: Color {
        if let value = getBlockThemeValue("--vrtx-search-box-contact-subtitle-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.secondaryForeground
    }
    
    // MARK: - Connect Button Styles
    
    private var connectButtonBackgroundColor: Color {
        if let value = getBlockThemeValue("--vrtx-search-box-connect-button-background") {
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
        if let value = getBlockThemeValue("--vrtx-search-box-connect-button-color"),
           let color = Color(hex: value) {
            return color
        }
        return defaultColors.primaryForeground
    }
    
    private var connectButtonBorderColor: Color {
        if let value = getBlockThemeValue("--vrtx-search-box-connect-button-border") {
            if let color = parseBorderColor(value) {
                return color
            }
        }
        return .clear
    }
    
    private var connectButtonBorderWidth: CGFloat {
        if let value = getBlockThemeValue("--vrtx-search-box-connect-button-border") {
            return parseBorderWidth(value)
        }
        return 0
    }
    
    private var connectButtonCornerRadius: CGFloat {
        if let value = getBlockThemeValue("--vrtx-search-box-connect-button-border-radius"),
           let radius = Double(value.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(radius)
        }
        return 8
    }
    
    private var connectButtonBackgroundValue: String? {
        getBlockThemeValue("--vrtx-search-box-connect-button-background")
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
        let fgColor = connectButtonForegroundColor
        let bdrColor = connectButtonBorderColor
        let bdrWidth = connectButtonBorderWidth
        let cornerRadius = connectButtonCornerRadius
        
        Button(action: {
            viewModel.handleSearchBoxConnect(contact)
        }) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text(connectButtonText)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: 80)
            .foregroundColor(fgColor)
            .background(buttonBackground(for: backgroundValue, cornerRadius: cornerRadius))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(bdrColor, lineWidth: bdrWidth)
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
        guard gradientString.contains("linear-gradient") else { return nil }
        
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
        
        guard colors.count >= 2 else { return nil }
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
}

// MARK: - Search Row with Focus Management (iOS 15+)

/// A self-contained search row that uses @FocusState to prevent the TextField from
/// automatically regaining focus when other parts of the form change (e.g., when an
/// outgoing invitation is removed after cancellation, causing a re-render that
/// restores focus to the previously-focused text field).
///
/// The key technique: after the user taps the search button (or presses Return),
/// we explicitly set `isFieldFocused = false` so the field is no longer the
/// "last focused" element. This prevents SwiftUI's focus restoration from
/// scrolling back to the search box when unrelated UI changes occur.
@available(iOS 15.0, *)
private struct SearchRowFocusable: View {
    let placeholder: String
    let placeholderColor: Color?
    let inputColor: Color?
    let inputFontSize: CGFloat
    let inputFontWeight: Font.Weight
    @Binding var query: String
    let foregroundColor: Color
    let borderColor: Color
    let isSearching: Bool
    let isDisabled: Bool
    let searchButtonForegroundColor: Color
    let searchButtonBackgroundValue: String?
    let defaultPrimaryBackground: Color
    let parseGradient: (String) -> SearchButtonGradient?
    let dismissFocusToken: Int
    let onCommit: () -> Void
    
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if query.isEmpty {
                    Text(placeholder)
                        .font(.system(size: inputFontSize))
                        .foregroundColor(placeholderColor ?? Color(UIColor.placeholderText))
                        .padding(.horizontal, 12)
                }
                TextField("", text: $query)
                    .focused($isFieldFocused)
                    .font(.system(size: inputFontSize, weight: inputFontWeight))
                    .foregroundColor(inputColor ?? foregroundColor)
                    .padding(.horizontal, 12)
            }
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
            .onTapGesture {
                isFieldFocused = true
            }
            .submitLabel(.search)
            .onSubmit {
                isFieldFocused = false
                onCommit()
            }
            
            Button(action: {
                isFieldFocused = false
                onCommit()
            }) {
                Group {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                .foregroundColor(searchButtonForegroundColor)
                .frame(width: 44, height: 44)
                .background(searchButtonBg)
                .cornerRadius(8)
            }
            .disabled(isSearching || isDisabled)
        }
        .onChange(of: dismissFocusToken) { _ in
            isFieldFocused = false
        }
    }
    
    @ViewBuilder
    private var searchButtonBg: some View {
        if let value = searchButtonBackgroundValue, let gradient = parseGradient(value) {
            LinearGradient(
                stops: zip(gradient.colors, gradient.stops).map { Gradient.Stop(color: $0, location: $1) },
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
        } else if let value = searchButtonBackgroundValue, let color = Color(hex: value) {
            color
        } else {
            defaultPrimaryBackground
        }
    }
}

/// Shared gradient result type used by SearchRowFocusable
private struct SearchButtonGradient {
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
