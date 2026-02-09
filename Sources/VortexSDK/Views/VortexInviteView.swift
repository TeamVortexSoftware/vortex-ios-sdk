import SwiftUI
import UIKit
import Contacts
import GoogleSignIn

/// Main invitation form view component
/// This is the primary entry point for integrating Vortex invitations into your iOS app
///
/// ## Prefetch Support
/// The view automatically uses cached configurations from `VortexConfigurationCache`.
/// For instant rendering without loading spinners:
///
/// 1. **Automatic caching**: After the first load, configurations are cached automatically.
///    Subsequent opens will show the form instantly while refreshing in the background.
///
/// 2. **Manual prefetch**: Use `VortexConfigurationPrefetcher` to fetch configurations early:
///    ```swift
///    let prefetcher = VortexConfigurationPrefetcher(componentId: "your-id")
///    await prefetcher.prefetch(jwt: jwt)
///    // Later, VortexInviteView will use the cached configuration automatically
///    ```
public struct VortexInviteView: View {
    @StateObject private var viewModel: VortexInviteViewModel
    
    /// Initialize the VortexInviteView
    /// - Parameters:
    ///   - componentId: The widget/component ID from your Vortex dashboard
    ///   - jwt: JWT authentication token (required for API access)
    ///   - apiBaseURL: Base URL of the Vortex API (default: production)
    ///   - analyticsBaseURL: Base URL of the analytics collector (default: production collector).
    ///     Only override this for development/staging environments.
    ///   - group: Optional group information for scoping invitations
    ///   - googleIosClientId: Google iOS Client ID for Google Contacts integration (optional)
    ///   - onEvent: Callback for analytics events (optional)
    ///   - onDismiss: Callback when the view is dismissed
    ///   - findFriendsConfig: Optional configuration for the Find Friends feature.
    ///     When provided, enables the Find Friends component to display contacts with
    ///     Connect/Invite buttons based on their membership status.
    ///   - invitationSuggestionsConfig: Optional configuration for the Invitation Suggestions feature.
    ///     When provided, enables the Invitation Suggestions component to display suggested
    ///     contacts with Invite and Dismiss buttons.
    ///   - inviteContactsConfig: Optional configuration for the Invite Contacts feature.
    ///     When provided, enables the Invite Contacts component to display a list of
    ///     contacts that can be invited via SMS.
    ///   - incomingInvitationsConfig: Optional configuration for the Incoming Invitations feature.
    ///     When provided, enables the Incoming Invitations component to display invitations
    ///     the user has received with Accept/Delete actions.
    ///   - locale: Optional BCP 47 language code for internationalization (e.g., "pt-BR", "en-US").
    ///     When provided, the widget configuration will be fetched in the specified locale.
    ///   - scope: Scope identifier for scoping invitations (e.g., team ID, project ID).
    ///     Used together with `scopeType` to create group context for API calls.
    ///   - scopeType: Type of the scope (e.g., "team", "project").
    ///     Used together with `scope` to create group context for API calls.
    ///   - unfurlConfig: Optional configuration for Open Graph unfurl metadata when sharing links.
    ///     Customizes the preview card shown on social platforms (iMessage, Facebook, Twitter, etc.).
    public init(
        componentId: String,
        jwt: String?,
        apiBaseURL: URL = URL(string: "https://client-api.vortexsoftware.com")!,
        analyticsBaseURL: URL? = nil,
        googleIosClientId: String? = nil,
        onEvent: ((VortexAnalyticsEvent) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        findFriendsConfig: FindFriendsConfig? = nil,
        invitationSuggestionsConfig: InvitationSuggestionsConfig? = nil,
        inviteContactsConfig: InviteContactsConfig? = nil,
        incomingInvitationsConfig: IncomingInvitationsConfig? = nil,
        outgoingInvitationsConfig: OutgoingInvitationsConfig? = nil,
        locale: String? = nil,
        scope: String? = nil,
        scopeType: String? = nil,
        unfurlConfig: UnfurlConfig? = nil
    ) {
        // Convert scope/scopeType to GroupDTO for API calls
        let effectiveGroup: GroupDTO? = {
            if let scope = scope, let scopeType = scopeType {
                return GroupDTO(id: nil, groupId: scope, type: scopeType, name: scope)
            }
            return nil
        }()
        
        _viewModel = StateObject(wrappedValue: VortexInviteViewModel(
            componentId: componentId,
            jwt: jwt,
            apiBaseURL: apiBaseURL,
            analyticsBaseURL: analyticsBaseURL,
            group: effectiveGroup,
            googleIosClientId: googleIosClientId,
            onEvent: onEvent,
            onDismiss: onDismiss,
            findFriendsConfig: findFriendsConfig,
            invitationSuggestionsConfig: invitationSuggestionsConfig,
            inviteContactsConfig: inviteContactsConfig,
            outgoingInvitationsConfig: outgoingInvitationsConfig,
            incomingInvitationsConfig: incomingInvitationsConfig,
            locale: locale,
            unfurlConfig: unfurlConfig
        ))
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismiss()
                }
            
            // Main content sheet
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
                            size: 24,
                            color: Color(red: 0x66/255, green: 0x66/255, blue: 0x66/255)
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
                        .onAppear {
                            viewModel.trackWidgetError(error)
                        }
                } else if viewModel.configuration != nil {
                    formView
                        .onAppear {
                            viewModel.trackWidgetRender()
                        }
                }
                
                Spacer(minLength: 0)
            }
            .frame(height: UIScreen.main.bounds.height * 0.8)
            .frame(maxWidth: .infinity)
            .background(viewModel.surfaceBackgroundColor ?? Color(UIColor.systemBackground))
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea()
        .onAppear {
            Task {
                await viewModel.loadConfiguration()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(viewModel.localizedString("Loading..."))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: VortexError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text(viewModel.localizedString("Error"))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await viewModel.loadConfiguration()
                }
            }) {
                Text(viewModel.localizedString("Retry"))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var formView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Show different content based on currentView
                switch viewModel.currentView {
                case .main:
                    // Dynamic form rendering based on configuration
                    // Exclude grp-email-invitations group in main view (matching RN SDK behavior)
                    if let formRoot = viewModel.formStructure {
                        ForEach(formRoot.children ?? [], id: \.id) { row in
                            renderRow(row, excludeGroups: ["grp-email-invitations"])
                        }
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
    private func renderRow(_ row: ElementNode, excludeGroups: [String] = []) -> some View {
        // Skip hidden rows or rows with no children (matching RN SDK behavior)
        if row.hidden != true, let children = row.children, !children.isEmpty {
            // Check if this row should be excluded based on its group
            let rowGroup = row.meta?.source?.group?.name
            if let group = rowGroup, excludeGroups.contains(group) {
                EmptyView()
            } else {
                // Check if any column has visible content
                let hasVisibleContent = children.contains { column in
                    guard column.hidden != true else { return false }
                    guard let columnChildren = column.children, !columnChildren.isEmpty else { return false }
                    // Check if column group is excluded
                    if let colGroup = column.meta?.source?.group?.name, excludeGroups.contains(colGroup) {
                        return false
                    }
                    // Check if any block in the column is visible
                    return columnChildren.contains { block in
                        guard block.hidden != true else { return false }
                        if let blockGroup = block.meta?.source?.group?.name, excludeGroups.contains(blockGroup) {
                            return false
                        }
                        return true
                    }
                }
                
                if hasVisibleContent {
                    VStack(spacing: 12) {
                        ForEach(children, id: \.id) { column in
                            renderColumn(column, excludeGroups: excludeGroups)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderColumn(_ column: ElementNode, excludeGroups: [String] = []) -> some View {
        if column.hidden != true {
            // Check if this column should be excluded based on its group
            let columnGroup = column.meta?.source?.group?.name
            if let group = columnGroup, excludeGroups.contains(group) {
                EmptyView()
            } else {
                VStack(spacing: 12) {
                    ForEach(column.children ?? [], id: \.id) { block in
                        renderBlock(block, excludeGroups: excludeGroups)
                    }
                }
            }
        }
    }
    
    /// Renders a block element based on its subtype
    /// Uses AnyView to avoid Swift's @ViewBuilder limitation with many switch cases
    private func renderBlock(_ block: ElementNode, excludeGroups: [String] = []) -> AnyView {
        guard block.hidden != true else {
            return AnyView(EmptyView())
        }
        
        // Check if this block should be excluded based on its group
        if let blockGroup = block.meta?.source?.group?.name, excludeGroups.contains(blockGroup) {
            return AnyView(EmptyView())
        }
        
        switch block.subtype {
        // MARK: - Vortex Components (fully supported)
        case "vrtx-share-options":
            return AnyView(ShareOptionsView(
                block: block,
                viewModel: viewModel
            ))
        case "vrtx-contacts-import":
            return AnyView(ContactsImportView(
                block: block,
                viewModel: viewModel
            ))
        case "vrtx-email-invitations":
            // The vrtx-email-invitations block defines the email input UI for the email entry view.
            // The "Add by Email" button is rendered by ContactsImportView (vrtx-contacts-import)
            // when isEmailInvitationsEnabled is true, matching the RN SDK behavior where
            // VrtxEmailInvitations returns null when not in email view.
            return AnyView(EmptyView())
        case "vrtx-find-friends":
            return AnyView(FindFriendsView(block: block, viewModel: viewModel))
        case "vrtx-invitation-suggestions":
            return AnyView(InvitationSuggestionsView(block: block, viewModel: viewModel))
        case "vrtx-invite-contacts":
            return AnyView(InviteContactsView(block: block, viewModel: viewModel))
        case "vrtx-outgoing-invitations":
            return AnyView(OutgoingInvitationsView(
                block: block,
                theme: block.theme,
                client: viewModel.client,
                jwt: viewModel.jwt,
                config: viewModel.outgoingInvitationsConfig,
                viewModel: viewModel
            ))
        case "vrtx-incoming-invitations":
            return AnyView(IncomingInvitationsView(
                block: block,
                theme: block.theme,
                config: viewModel.incomingInvitationsConfig,
                client: viewModel.client,
                jwt: viewModel.jwt,
                viewModel: viewModel
            ))
        
        // MARK: - Content Elements (fully supported)
        case "vrtx-heading":
            return AnyView(HeadingView(block: block, textColor: viewModel.surfaceForegroundColor))
        case "vrtx-text":
            return AnyView(TextView(block: block))
        case "vrtx-form-label":
            return AnyView(FormLabelView(block: block))
        case "vrtx-image":
            return AnyView(ImageView(block: block))
        case "vrtx-link":
            return AnyView(LinkView(block: block))
        case "vrtx-button":
            return AnyView(ButtonView(block: block))
        case "vrtx-divider":
            return AnyView(DividerView(block: block))
        case "vrtx-menu":
            return AnyView(MenuView(block: block))
        
        // MARK: - Layout Elements (supported)
        case "vrtx-root":
            // Root container - render children
            return AnyView(RootView(block: block, renderBlock: { renderBlock($0, excludeGroups: excludeGroups) }))
        case "row_layout":
            // Row layout - render children horizontally
            return AnyView(RowLayoutView(block: block, renderBlock: { renderBlock($0, excludeGroups: excludeGroups) }))
        case "vrtx-column":
            // Column - render children vertically
            return AnyView(ColumnView(block: block, renderBlock: { renderBlock($0, excludeGroups: excludeGroups) }))
        case "vrtx-row":
            // Row - render children horizontally
            return AnyView(RowView(block: block, renderBlock: { renderBlock($0, excludeGroups: excludeGroups) }))
        
        // MARK: - Form Elements (supported)
        case "vrtx-textbox":
            return AnyView(TextboxView(block: block, viewModel: viewModel))
        case "vrtx-textarea":
            return AnyView(TextareaView(block: block, viewModel: viewModel))
        case "vrtx-select":
            // The vrtx-select block is not rendered in the main view, matching RN SDK behavior
            // where renderBlock returns null for vrtx-select
            return AnyView(EmptyView())
        case "vrtx-radio":
            return AnyView(RadioView(block: block, viewModel: viewModel))
        case "vrtx-checkbox":
            return AnyView(CheckboxView(block: block, viewModel: viewModel))
        case "vrtx-submit":
            // The vrtx-submit block only renders in email view, matching RN SDK's VrtxSubmit
            // which returns null when view !== 'email'
            if viewModel.currentView == .emailEntry {
                return AnyView(SubmitButtonView(block: block, viewModel: viewModel))
            }
            return AnyView(EmptyView())
        
        // MARK: - Autojoin Elements (warning - specialized admin features)
        case "vrtx-admin-autojoin":
            return AnyView(UnsupportedElementView(block: block, reason: "Admin autojoin is not yet supported in iOS SDK"))
        case "vrtx-autojoin":
            return AnyView(AutojoinView(block: block))
        
        default:
            // Log warning for unknown element types
            return AnyView(UnsupportedElementView(block: block, reason: "Unknown element type"))
        }
    }
    
    // MARK: - Email Entry View
    
    /// Get the background style for email pills from the email invitations block
    private var emailPillBackgroundStyle: BackgroundStyle? {
        guard let block = viewModel.emailInvitationsBlock,
              let backgroundValue = block.style?["background"] else {
            return nil
        }
        return BackgroundStyle.parse(backgroundValue)
    }
    
    private var emailEntryView: some View {
        VStack(spacing: 16) {
            // Email pills for added emails
            if !viewModel.emails.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.emails, id: \.self) { email in
                            EmailPillView(email: email, backgroundStyle: emailPillBackgroundStyle) {
                                viewModel.removeEmail(email)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Email input
            VStack(alignment: .leading, spacing: 8) {
                EmailInputField(
                    text: $viewModel.emailInput,
                    placeholder: viewModel.localizedString("Enter email addresses"),
                    onCommit: { viewModel.addEmailFromInput() }
                )
                
                Text(viewModel.localizedString("Press return to add each email"))
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
                        Text(viewModel.emails.count > 1 || (viewModel.emails.count == 1 && !viewModel.hasValidEmailInput)
                            ? viewModel.localizedString("Send Invitations")
                            : viewModel.localizedString("Send Invitation"))
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
            Text(viewModel.localizedString("Add from Contacts"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(UIColor.label))
                .padding(.top, 16)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(viewModel.localizedString("Search contacts..."), text: $viewModel.contactsSearchQuery)
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
                    Text(viewModel.localizedString("Loading contacts..."))
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
                    
                    Text(viewModel.localizedString("Unable to Access Contacts"))
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
                                Text(viewModel.localizedString("Open Settings"))
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                Task { await viewModel.retryFetchContacts() }
                            }) {
                                Text(viewModel.localizedString("Retry"))
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
                            Text(viewModel.localizedString("Try Again"))
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
                         ? viewModel.localizedString("No contacts with email addresses found") 
                         : viewModel.localizedString("No contacts match your search"))
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
                                },
                                localizedString: viewModel.localizedString
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
            Text(viewModel.localizedString("Add from Google Contacts"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(UIColor.label))
                .padding(.top, 16)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(viewModel.localizedString("Search contacts..."), text: $viewModel.googleContactsSearchQuery)
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
                    Text(viewModel.localizedString("Loading Google contacts..."))
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
                    
                    Text(viewModel.localizedString("Unable to Access Google Contacts"))
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
                        Text(viewModel.localizedString("Try Again"))
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
                         ? viewModel.localizedString("No contacts with email addresses found") 
                         : viewModel.localizedString("No contacts match your search"))
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
                                },
                                localizedString: viewModel.localizedString
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
            // QR Code container
            VStack(spacing: 20) {
                if viewModel.loadingQrCode {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                    .frame(width: 250, height: 250)
                } else if let link = viewModel.shareableLink, let qrImage = generateQRCode(from: link) {
                    // QR Code image
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                } else {
                    // Error state
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 50))
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
        .onAppear {
            Task {
                // Fetch shareable link when QR code view appears
                await viewModel.fetchShareableLinkForQrCode()
            }
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
            Text(viewModel.localizedString("Invitation sent successfully!"))
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Email Input Field (iOS 14 compatible)

/// A text field for email input that supports onCommit on iOS 14+
private struct EmailInputField: View {
    @Binding var text: String
    var placeholder: String = "Enter email addresses"
    let onCommit: () -> Void
    
    var body: some View {
        TextField(placeholder, text: $text, onCommit: onCommit)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocapitalization(.none)
            .disableAutocorrection(true)
    }
}
