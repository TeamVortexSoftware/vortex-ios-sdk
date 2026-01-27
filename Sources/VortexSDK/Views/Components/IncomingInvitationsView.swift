import SwiftUI

/// View component for displaying incoming invitations with Accept/Delete actions
struct IncomingInvitationsView: View {
    let block: ElementNode
    let theme: Theme?
    let config: IncomingInvitationsConfig?
    let client: VortexClient?
    let jwt: String?
    
    @State private var invitations: [IncomingInvitationItem] = []
    @State private var isLoading = true
    @State private var actionInProgress: String? = nil
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var alertAction: (() async -> Void)? = nil
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if invitations.isEmpty {
                Text(emptyStateMessage)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let title = blockTitle, !title.isEmpty {
                        Text(title)
                            .font(.system(size: titleFontSize, weight: titleFontWeight))
                            .foregroundColor(titleColor)
                            .padding(.bottom, 12)
                    }
                    
                    ForEach(invitations) { invitation in
                        invitationRow(invitation)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .task {
            await loadInvitations()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button(cancelButtonText, role: .cancel) { }
            Button(confirmButtonText) {
                if let action = alertAction {
                    Task {
                        await action()
                    }
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Block Title Helper
    
    private var blockTitle: String? {
        guard let attributes = block.attributes,
              let titleValue = attributes["title"] else {
            return nil
        }
        if case .string(let title) = titleValue {
            return title
        }
        return nil
    }
    
    // MARK: - Customization from block settings (widget config) and config props
    
    private var acceptButtonText: String {
        // Priority: block.settings.customizations > config props > default
        block.settings?.customizations?["acceptButton"]?.textContent ??
        config?.acceptButtonText ?? "Accept"
    }
    
    private var deleteButtonText: String {
        block.settings?.customizations?["deleteButton"]?.textContent ??
        config?.deleteButtonText ?? "Delete"
    }
    
    private var emptyStateMessage: String {
        block.settings?.customizations?["emptyStateMessage"]?.textContent ??
        config?.emptyStateMessage ?? "No incoming invitations"
    }
    
    private var acceptConfirmTitle: String {
        block.settings?.customizations?["acceptConfirmTitle"]?.textContent ??
        config?.acceptConfirmTitle ?? "Accept Invitation"
    }
    
    private var acceptConfirmMessage: String {
        block.settings?.customizations?["acceptConfirmMessage"]?.textContent ??
        config?.acceptConfirmMessage ?? "Accept invitation from {name}?"
    }
    
    private var deleteConfirmTitle: String {
        block.settings?.customizations?["deleteConfirmTitle"]?.textContent ??
        config?.deleteConfirmTitle ?? "Delete Invitation"
    }
    
    private var deleteConfirmMessage: String {
        block.settings?.customizations?["deleteConfirmMessage"]?.textContent ??
        config?.deleteConfirmMessage ?? "Delete invitation from {name}?"
    }
    
    private var confirmButtonText: String {
        block.settings?.customizations?["confirmButtonText"]?.textContent ??
        config?.confirmButtonText ?? "Confirm"
    }
    
    private var cancelButtonText: String {
        block.settings?.customizations?["cancelButtonText"]?.textContent ??
        config?.cancelButtonText ?? "Cancel"
    }
    
    // MARK: - Invitation Row
    
    @ViewBuilder
    private func invitationRow(_ invitation: IncomingInvitationItem) -> some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView(for: invitation)
            
            // Name and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.name)
                    .font(.system(size: nameFontSize, weight: nameFontWeight))
                    .foregroundColor(nameColor)
                    .lineLimit(1)
                
                if let subtitle = invitation.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: subtitleFontSize))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Delete button
                Button(action: {
                    showDeleteConfirmation(for: invitation)
                }) {
                    if actionInProgress == invitation.id {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: deleteButtonTextColor))
                    } else {
                        Text(deleteButtonText)
                            .font(.system(size: deleteButtonFontSize, weight: deleteButtonFontWeight))
                            .foregroundColor(deleteButtonTextColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(deleteButtonBackground)
                .cornerRadius(deleteButtonBorderRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: deleteButtonBorderRadius)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
                .disabled(actionInProgress != nil)
                
                // Accept button
                Button(action: {
                    Task {
                        await handleAccept(invitation)
                    }
                }) {
                    if actionInProgress == invitation.id {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: acceptButtonTextColor))
                    } else {
                        Text(acceptButtonText)
                            .font(.system(size: acceptButtonFontSize, weight: acceptButtonFontWeight))
                            .foregroundColor(acceptButtonTextColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .backgroundStyle(acceptButtonBackgroundStyle)
                .cornerRadius(acceptButtonBorderRadius)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(actionInProgress != nil)
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private func avatarView(for invitation: IncomingInvitationItem) -> some View {
        if let avatarUrl = invitation.avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                initialsView(for: invitation.name)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            initialsView(for: invitation.name)
        }
    }
    
    private func initialsView(for name: String) -> some View {
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
        
        return Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(avatarTextColor)
            .frame(width: 44, height: 44)
            .background(avatarBackground)
            .clipShape(Circle())
    }
    
    // MARK: - Actions
    
    private func loadInvitations() async {
        isLoading = true
        
        var allInvitations: [IncomingInvitationItem] = []
        
        // Add internal invitations from config
        if let internalInvitations = config?.internalInvitations {
            allInvitations.append(contentsOf: internalInvitations)
        }
        
        // Fetch from API if we have client and jwt
        if let client = client, let jwt = jwt {
            do {
                let apiInvitations = try await client.getIncomingInvitations(jwt: jwt)
                // Filter out already accepted invitations (client-side filter since API doesn't exclude them by default)
                let pendingInvitations = apiInvitations.filter { inv in
                    let status = inv.status?.lowercased() ?? ""
                    return status != "accepted" && status != "accepted_elsewhere"
                }
                let mappedInvitations = pendingInvitations.map { inv -> IncomingInvitationItem in
                    let name = inv.senderIdentifier ?? "Unknown"
                    let subtitle = inv.targets?.first?.targetValue
                    return IncomingInvitationItem(
                        id: inv.id,
                        name: name,
                        subtitle: subtitle,
                        avatarUrl: inv.avatarUrl,
                        isFromVortexAPI: true,
                        metadata: nil
                    )
                }
                allInvitations.append(contentsOf: mappedInvitations)
            } catch {
                // Silently fail - just show internal invitations
                #if DEBUG
                print("[VortexSDK] Failed to fetch incoming invitations: \(error)")
                #endif
            }
        }
        
        invitations = allInvitations
        isLoading = false
    }
    
    private func showAcceptConfirmation(for invitation: IncomingInvitationItem) {
        alertTitle = acceptConfirmTitle
        alertMessage = acceptConfirmMessage.replacingOccurrences(of: "{name}", with: invitation.name)
        alertAction = {
            await handleAccept(invitation)
        }
        showingAlert = true
    }
    
    private func showDeleteConfirmation(for invitation: IncomingInvitationItem) {
        alertTitle = deleteConfirmTitle
        alertMessage = deleteConfirmMessage.replacingOccurrences(of: "{name}", with: invitation.name)
        alertAction = {
            await handleDelete(invitation)
        }
        showingAlert = true
    }
    
    private func handleAccept(_ invitation: IncomingInvitationItem) async {
        actionInProgress = invitation.id
        
        // Call the callback first - it must return true to proceed
        var shouldProceed = false
        if let onAccept = config?.onAccept {
            shouldProceed = await onAccept(invitation)
        }
        
        // If callback returns true and it's from Vortex API, call the accept endpoint
        if shouldProceed && invitation.isFromVortexAPI {
            if let client = client, let jwt = jwt {
                do {
                    try await client.acceptIncomingInvitation(jwt: jwt, invitationId: invitation.id)
                } catch {
                    #if DEBUG
                    print("[VortexSDK] Failed to accept invitation: \(error)")
                    #endif
                    actionInProgress = nil
                    return
                }
            }
        }
        
        if shouldProceed {
            // Remove from list with animation
            withAnimation {
                invitations.removeAll { $0.id == invitation.id }
            }
        }
        
        actionInProgress = nil
    }
    
    private func handleDelete(_ invitation: IncomingInvitationItem) async {
        actionInProgress = invitation.id
        
        // Call the callback first
        var shouldProceed = true
        if let onDelete = config?.onDelete {
            shouldProceed = await onDelete(invitation)
        }
        
        // If callback returns true and it's from Vortex API, call the delete endpoint
        if shouldProceed && invitation.isFromVortexAPI {
            if let client = client, let jwt = jwt {
                do {
                    try await client.deleteIncomingInvitation(jwt: jwt, invitationId: invitation.id)
                } catch {
                    #if DEBUG
                    print("[VortexSDK] Failed to delete invitation: \(error)")
                    #endif
                    actionInProgress = nil
                    return
                }
            }
        }
        
        if shouldProceed {
            // Remove from list with animation
            withAnimation {
                invitations.removeAll { $0.id == invitation.id }
            }
        }
        
        actionInProgress = nil
    }
    
    // MARK: - Theme Helpers
    
    private func getBlockThemeValue(_ key: String) -> String? {
        guard let options = block.theme?.options else { return nil }
        return options.first { $0.key == key }?.value
    }
    
    // Default colors
    private let defaultPrimaryBackground = Color(hex: "#6291d5") ?? .blue
    private let defaultPrimaryForeground = Color.white
    private let defaultSecondaryBackground = Color.white
    private let defaultSecondaryForeground = Color(hex: "#353e5c") ?? .gray
    private let defaultForeground = Color(hex: "#334153") ?? .primary
    
    // Colors from theme
    private var primaryBackground: Color {
        if let hex = theme?.colors?.primary {
            return Color(hex: hex) ?? defaultPrimaryBackground
        }
        return defaultPrimaryBackground
    }
    
    private var primaryForeground: Color {
        if let hex = theme?.colors?.onPrimary {
            return Color(hex: hex) ?? defaultPrimaryForeground
        }
        return defaultPrimaryForeground
    }
    
    private var secondaryBackground: Color {
        if let hex = theme?.colors?.secondary {
            return Color(hex: hex) ?? defaultSecondaryBackground
        }
        return defaultSecondaryBackground
    }
    
    private var secondaryForeground: Color {
        if let hex = theme?.colors?.onSecondary {
            return Color(hex: hex) ?? defaultSecondaryForeground
        }
        return defaultSecondaryForeground
    }
    
    private var foregroundColor: Color {
        if let hex = theme?.colors?.onBackground {
            return Color(hex: hex) ?? defaultForeground
        }
        return defaultForeground
    }
    
    // Title styles
    private var titleColor: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-title-color") {
            return Color(hex: hex) ?? foregroundColor
        }
        return foregroundColor
    }
    
    private var titleFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-incoming-invitations-title-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 16
    }
    
    private var titleFontWeight: Font.Weight {
        if let weight = getBlockThemeValue("--vrtx-incoming-invitations-title-font-weight") {
            return fontWeight(from: weight)
        }
        return .semibold
    }
    
    // Name styles
    private var nameColor: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-name-color") {
            return Color(hex: hex) ?? foregroundColor
        }
        return foregroundColor
    }
    
    private var nameFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-incoming-invitations-name-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 16
    }
    
    private var nameFontWeight: Font.Weight {
        if let weight = getBlockThemeValue("--vrtx-incoming-invitations-name-font-weight") {
            return fontWeight(from: weight)
        }
        return .medium
    }
    
    // Subtitle styles
    private var subtitleColor: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-subtitle-color") {
            return Color(hex: hex) ?? secondaryForeground
        }
        return secondaryForeground
    }
    
    private var subtitleFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-incoming-invitations-subtitle-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 13
    }
    
    // Avatar styles
    private var avatarBackground: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-avatar-background") {
            return Color(hex: hex) ?? primaryBackground
        }
        return primaryBackground
    }
    
    private var avatarTextColor: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-avatar-color") {
            return Color(hex: hex) ?? primaryForeground
        }
        return primaryForeground
    }
    
    // Accept button styles
    private var acceptButtonBackgroundStyle: BackgroundStyle {
        if let value = getBlockThemeValue("--vrtx-incoming-invitations-accept-button-background"),
           let style = BackgroundStyle.parse(value) {
            return style
        }
        return .solid(primaryBackground)
    }
    
    private var acceptButtonTextColor: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-accept-button-color") {
            return Color(hex: hex) ?? primaryForeground
        }
        return primaryForeground
    }
    
    private var acceptButtonBorderRadius: CGFloat {
        if let radiusStr = getBlockThemeValue("--vrtx-incoming-invitations-accept-button-border-radius"),
           let radius = Double(radiusStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(radius)
        }
        return 8
    }
    
    private var acceptButtonFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-incoming-invitations-accept-button-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 14
    }
    
    private var acceptButtonFontWeight: Font.Weight {
        if let weight = getBlockThemeValue("--vrtx-incoming-invitations-accept-button-font-weight") {
            return fontWeight(from: weight)
        }
        return .semibold
    }
    
    // Delete button styles
    private var deleteButtonBackground: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-delete-button-background") {
            return Color(hex: hex) ?? secondaryBackground
        }
        return secondaryBackground
    }
    
    private var deleteButtonTextColor: Color {
        if let hex = getBlockThemeValue("--vrtx-incoming-invitations-delete-button-color") {
            return Color(hex: hex) ?? secondaryForeground
        }
        return secondaryForeground
    }
    
    private var deleteButtonBorderRadius: CGFloat {
        if let radiusStr = getBlockThemeValue("--vrtx-incoming-invitations-delete-button-border-radius"),
           let radius = Double(radiusStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(radius)
        }
        return 8
    }
    
    private var deleteButtonFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-incoming-invitations-delete-button-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 14
    }
    
    private var deleteButtonFontWeight: Font.Weight {
        if let weight = getBlockThemeValue("--vrtx-incoming-invitations-delete-button-font-weight") {
            return fontWeight(from: weight)
        }
        return .semibold
    }
    
    // MARK: - Font Weight Helper
    
    private func fontWeight(from string: String) -> Font.Weight {
        switch string.lowercased() {
        case "100", "thin": return .thin
        case "200", "ultralight": return .ultraLight
        case "300", "light": return .light
        case "400", "regular", "normal": return .regular
        case "500", "medium": return .medium
        case "600", "semibold": return .semibold
        case "700", "bold": return .bold
        case "800", "heavy": return .heavy
        case "900", "black": return .black
        default: return .regular
        }
    }
}
