import SwiftUI

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
                    // Header with close button
                    HStack {
                        Text("Send Invitation")
                            .font(.headline)
                        Spacer()
                        Button(action: { viewModel.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
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
            VStack(spacing: 20) {
                // TODO: Implement dynamic form rendering based on configuration
                // This is a placeholder MVP implementation
                
                Text("Invitation Form")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Configuration loaded successfully!")
                    .foregroundColor(.secondary)
                
                if let config = viewModel.configuration {
                    Text("Component ID: \(config.widgetId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Placeholder email input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter email address", text: $viewModel.emailInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding(.horizontal)
                
                // Placeholder invite button
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
                            Text("Send Invitation")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isSending || viewModel.emailInput.isEmpty)
                .padding(.horizontal)
                
                // Success message
                if viewModel.showSuccess {
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
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
}

// MARK: - View Model

@MainActor
class VortexInviteViewModel: ObservableObject {
    @Published var configuration: WidgetConfiguration?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: VortexError?
    @Published var emailInput = ""
    @Published var showSuccess = false
    
    private let componentId: String
    private let jwt: String?
    private let client: VortexClient
    private let group: GroupDTO?
    private let onDismiss: (() -> Void)?
    
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
        } catch let vortexError as VortexError {
            error = vortexError
        } catch {
            error = .decodingError(error)
        }
        
        isLoading = false
    }
    
    func sendInvitation() async {
        guard let jwt = jwt,
              let config = configuration else {
            return
        }
        
        isSending = true
        showSuccess = false
        
        do {
            let payload: [String: Any] = [
                "invitee_email": ["value": emailInput, "type": "email"]
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
            
            showSuccess = true
            emailInput = ""
            
            // Hide success message after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showSuccess = false
            
        } catch let vortexError as VortexError {
            error = vortexError
        } catch {
            error = .encodingError(error)
        }
        
        isSending = false
    }
    
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
