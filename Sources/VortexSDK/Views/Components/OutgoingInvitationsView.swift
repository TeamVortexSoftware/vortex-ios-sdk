import SwiftUI

// MARK: - Outgoing Invitations View

/// Displays outgoing invitations with cancel functionality
struct OutgoingInvitationsView: View {
    let block: ElementNode
    let theme: Theme?
    let client: VortexClient
    let jwt: String?
    let config: OutgoingInvitationsConfig?
    @ObservedObject var viewModel: VortexInviteViewModel
    
    @State private var invitations: [OutgoingInvitationItem] = []
    @State private var vortexInvitationMap: [String: OutgoingInvitation] = [:]
    @State private var isLoading = true
    @State private var error: String?
    @State private var actionInProgress: String?
    @State private var showingCancelConfirmation = false
    @State private var invitationToCancel: OutgoingInvitationItem?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if invitations.isEmpty {
                // No-op: render nothing (0 height) when no invitations
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let title = blockTitle, !title.isEmpty {
                        Text(title)
                            .font(.system(size: titleFontSize, weight: titleFontWeight))
                            .foregroundColor(titleColor)
                            .padding(.bottom, 12)
                    }

                    ForEach(invitations) { item in
                        invitationRow(item)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            Task {
                await loadInvitations()
            }
        }
        .onChange(of: jwt) { newJwt in
            if newJwt != nil && invitations.isEmpty {
                Task {
                    await loadInvitations()
                }
            }
        }
        .onChange(of: viewModel.invitationSentEvent) { _ in
            Task {
                await loadInvitations()
            }
        }
        .alert(isPresented: $showingCancelConfirmation) {
            Alert(
                title: Text(cancelConfirmTitle),
                message: Text(cancelConfirmMessage.replacingOccurrences(of: "{name}", with: invitationToCancel?.name ?? "")),
                primaryButton: .destructive(Text(confirmButtonText)) {
                    if let item = invitationToCancel {
                        Task {
                            await cancelInvitation(item)
                        }
                    }
                },
                secondaryButton: .cancel(Text(dismissButtonText))
            )
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
    
    // MARK: - Invitation Row
    
    @ViewBuilder
    private func invitationRow(_ item: OutgoingInvitationItem) -> some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView(for: item)
            
            // Name and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: nameFontSize, weight: nameFontWeight))
                    .foregroundColor(nameColor)
                    .lineLimit(1)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: subtitleFontSize))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Cancel button
            Button {
                invitationToCancel = item
                showingCancelConfirmation = true
            } label: {
                if actionInProgress == item.id {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: cancelButtonTextColor))
                } else {
                    Text(cancelButtonText)
                        .font(.system(size: cancelButtonFontSize, weight: cancelButtonFontWeight))
                        .foregroundColor(cancelButtonTextColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(cancelButtonBackground)
            .cornerRadius(cancelButtonBorderRadius)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(actionInProgress != nil)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private func avatarView(for item: OutgoingInvitationItem) -> some View {
        if let avatarUrl = item.avatarUrl, let url = URL(string: avatarUrl) {
            if #available(iOS 15.0, *) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsView(for: item.name)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                initialsView(for: item.name)
            }
        } else {
            initialsView(for: item.name)
        }
    }
    
    private func initialsView(for name: String) -> some View {
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
        
        return Text(initials)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(avatarTextColor)
            .frame(width: 44, height: 44)
            .background(avatarBackground)
            .clipShape(Circle())
    }
    
    // MARK: - Actions
    
    private func loadInvitations() async {
        isLoading = true
        error = nil
        
        var allInvitations: [OutgoingInvitationItem] = []
        var invitationMap: [String: OutgoingInvitation] = [:]
        
        // Add internal invitations from config
        if let internalInvitations = config?.internalInvitations {
            allInvitations.append(contentsOf: internalInvitations)
        }
        
        // Fetch from API if we have jwt
        if let jwt = jwt {
            do {
                let fetched = try await client.getOutgoingInvitations(jwt: jwt)
                // Filter out shareable link invitations (targetType "share")
                let filtered = fetched.filter { invitation in
                    guard let targetType = invitation.targets?.first?.targetType else { return true }
                    return targetType != "share"
                }
                for invitation in filtered {
                    let item = mapToDisplayItem(invitation)
                    allInvitations.append(item)
                    invitationMap[item.id] = invitation
                }
            } catch {
                // Silently fail - just show internal invitations if any
                #if DEBUG
                print("[VortexSDK] Failed to fetch outgoing invitations: \(error)")
                #endif
                // Only show error if we have no internal invitations
                if allInvitations.isEmpty {
                    self.error = block.settings?.customizations?["mobile.errorMessage"]?.textContent ?? "Failed to load invitations"
                }
            }
        }
        
        invitations = allInvitations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        vortexInvitationMap = invitationMap
        isLoading = false
    }
    
    private func mapToDisplayItem(_ invitation: OutgoingInvitation) -> OutgoingInvitationItem {
        // Get recipient from first target (e.g., SMS phone number or email)
        let target = invitation.targets?.first
        let targetName = target?.targetName
        let targetValue = target?.targetValue
        
        // Use targetName as display name if available, otherwise fall back to targetValue
        let unknownFallback = block.settings?.customizations?["mobile.unknownName"]?.textContent ?? "Unknown"
        let name = targetName ?? targetValue ?? invitation.senderIdentifier ?? unknownFallback
        // Show the phone number / email / identifier as subtitle
        let subtitle = targetValue ?? invitation.senderIdentifier
        
        return OutgoingInvitationItem(
            id: invitation.id,
            name: name,
            subtitle: subtitle,
            avatarUrl: target?.targetAvatarUrl,
            isVortexInvitation: true,
            metadata: nil
        )
    }
    
    private func cancelInvitation(_ item: OutgoingInvitationItem) async {
        actionInProgress = item.id

        // Track the cancel/delete button click
        viewModel.trackOutboundInvitationDelete(invitationId: item.id, inviteeName: item.name)

        // Check if this is an internal (non-Vortex) invitation
        if !item.isVortexInvitation {
            // For internal invitations, call the callback and let the app handle it
            if let onCancel = config?.onCancel {
                let shouldRemove = await onCancel(item)
                if shouldRemove {
                    withAnimation(.easeOut(duration: 0.2)) {
                        invitations.removeAll { $0.id == item.id }
                    }
                }
            }
            actionInProgress = nil
            return
        }

        // For Vortex invitations, call the API
        guard let jwt = jwt else {
            actionInProgress = nil
            return
        }

        // If callback is provided, let it decide whether to proceed
        if let onCancel = config?.onCancel {
            let shouldProceed = await onCancel(item)
            if !shouldProceed {
                actionInProgress = nil
                return
            }
        }

        do {
            try await client.revokeInvitation(jwt: jwt, invitationId: item.id)
        } catch {
            actionInProgress = nil
            return
        }
        
        // Remove from list with animation
        withAnimation(.easeOut(duration: 0.2)) {
            invitations.removeAll { $0.id == item.id }
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
        if let hex = getBlockThemeValue("--vrtx-outgoing-invitations-title-color") {
            return Color(hex: hex) ?? foregroundColor
        }
        return foregroundColor
    }
    
    private var titleFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-outgoing-invitations-title-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 16
    }
    
    private var titleFontWeight: Font.Weight {
        if let weight = getBlockThemeValue("--vrtx-outgoing-invitations-title-font-weight") {
            return fontWeight(from: weight)
        }
        return .semibold
    }
    
    // Name styles
    private var nameColor: Color {
        if let hex = getBlockThemeValue("--vrtx-outgoing-invitations-name-color") {
            return Color(hex: hex) ?? foregroundColor
        }
        return foregroundColor
    }
    
    private var nameFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-outgoing-invitations-name-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 16
    }
    
    private var nameFontWeight: Font.Weight {
        if let weight = getBlockThemeValue("--vrtx-outgoing-invitations-name-font-weight") {
            return fontWeight(from: weight)
        }
        return .medium
    }
    
    // Subtitle styles
    private var subtitleColor: Color {
        if let hex = getBlockThemeValue("--vrtx-outgoing-invitations-subtitle-color") {
            return Color(hex: hex) ?? secondaryForeground
        }
        return secondaryForeground
    }
    
    private var subtitleFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-outgoing-invitations-subtitle-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 13
    }
    
    // Avatar styles
    private var avatarBackground: Color {
        if let hex = getBlockThemeValue("--vrtx-outgoing-invitations-avatar-background") {
            return Color(hex: hex) ?? primaryBackground
        }
        return primaryBackground
    }
    
    private var avatarTextColor: Color {
        if let hex = getBlockThemeValue("--vrtx-outgoing-invitations-avatar-color") {
            return Color(hex: hex) ?? primaryForeground
        }
        return primaryForeground
    }
    
    // Cancel button styles
    private var cancelButtonBackground: Color {
        if let hex = getBlockThemeValue("--vrtx-outgoing-invitations-cancel-button-background") {
            return Color(hex: hex) ?? secondaryBackground
        }
        return secondaryBackground
    }
    
    private var cancelButtonTextColor: Color {
        if let hex = getBlockThemeValue("--vrtx-outgoing-invitations-cancel-button-color") {
            return Color(hex: hex) ?? secondaryForeground
        }
        return secondaryForeground
    }
    
    private var cancelButtonBorderRadius: CGFloat {
        if let radiusStr = getBlockThemeValue("--vrtx-outgoing-invitations-cancel-button-border-radius"),
           let radius = Double(radiusStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(radius)
        }
        return 8
    }
    
    private var cancelButtonFontSize: CGFloat {
        if let sizeStr = getBlockThemeValue("--vrtx-outgoing-invitations-cancel-button-font-size"),
           let size = Double(sizeStr.replacingOccurrences(of: "px", with: "")) {
            return CGFloat(size)
        }
        return 14
    }
    
    private var cancelButtonFontWeight: Font.Weight {
        if let weight = getBlockThemeValue("--vrtx-outgoing-invitations-cancel-button-font-weight") {
            return fontWeight(from: weight)
        }
        return .semibold
    }
    
    // Customization texts from block settings
    private var cancelButtonText: String {
        block.settings?.customizations?["cancelButton"]?.textContent ?? "Cancel"
    }
    
    private var cancelConfirmTitle: String {
        block.settings?.customizations?["mobile.cancelConfirmTitle"]?.textContent ?? "Cancel Invitation"
    }
    
    private var cancelConfirmMessage: String {
        block.settings?.customizations?["mobile.cancelConfirmMessage"]?.textContent ?? "Cancel invitation to {name}?"
    }
    
    private var confirmButtonText: String {
        block.settings?.customizations?["mobile.confirmButtonText"]?.textContent ?? "Confirm"
    }
    
    private var dismissButtonText: String {
        block.settings?.customizations?["mobile.dismissButtonText"]?.textContent ?? "Keep"
    }
    
    // Helper to convert font weight string to Font.Weight
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
