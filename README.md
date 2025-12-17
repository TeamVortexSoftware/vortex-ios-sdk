# Vortex iOS SDK

Configuration-driven invitation forms for native iOS apps.

## Overview

The Vortex iOS SDK provides a SwiftUI component for rendering customizable invitation forms in your iOS applications. The SDK fetches configuration from your Vortex backend and dynamically renders the appropriate UI.

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 14.0+

## Installation

### Swift Package Manager (Recommended)

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/teamvortexsoftware/vortex-ios-sdk.git", from: "1.0.0")
]
```

Or in Xcode:
1. **File → Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/teamvortexsoftware/vortex-ios-sdk.git`
3. Select version: `1.0.0` or higher
4. Add to your target

## Quick Start

### Basic Usage

```swift
import SwiftUI
import VortexSDK

struct ContentView: View {
    @State private var showInviteForm = false
    
    var body: some View {
        Button("Send Invitation") {
            showInviteForm = true
        }
        .sheet(isPresented: $showInviteForm) {
            VortexInviteView(
                componentId: "your-component-id",
                jwt: "your-jwt-token",
                onDismiss: {
                    showInviteForm = false
                }
            )
        }
    }
}
```

### With Group Context

```swift
import SwiftUI
import VortexSDK

struct TeamView: View {
    let team: Team
    @State private var showInviteForm = false
    
    var body: some View {
        Button("Invite to Team") {
            showInviteForm = true
        }
        .sheet(isPresented: $showInviteForm) {
            VortexInviteView(
                componentId: "your-component-id",
                jwt: authToken,
                group: GroupDTO(
                    id: team.id,
                    groupId: team.id,
                    type: "team",
                    name: team.name
                ),
                onDismiss: {
                    showInviteForm = false
                }
            )
        }
    }
}
```

### Custom API Base URL (Development)

```swift
VortexInviteView(
    componentId: "your-component-id",
    jwt: devToken,
    apiBaseURL: URL(string: "http://localhost:3002")!,
    onDismiss: { /* ... */ }
)
```

## Authentication

The SDK requires a JWT token for authentication. You should obtain this token from your backend server:

```swift
// Example: Fetch JWT from your backend
func fetchVortexToken() async throws -> String {
    let response = try await URLSession.shared.data(
        from: URL(string: "https://your-api.com/vortex/token")!
    )
    let token = try JSONDecoder().decode(TokenResponse.self, from: response.0)
    return token.jwt
}

// Usage
Task {
    let jwt = try await fetchVortexToken()
    // Pass jwt to VortexInviteView
}
```

## API Reference

### VortexInviteView

The main SwiftUI component for rendering invitation forms.

**Initializer:**

```swift
VortexInviteView(
    componentId: String,
    jwt: String?,
    apiBaseURL: URL = URL(string: "https://client-api.vortexsoftware.com")!,
    group: GroupDTO? = nil,
    onDismiss: (() -> Void)? = nil
)
```

**Parameters:**
- `componentId`: Your widget/component ID from the Vortex dashboard
- `jwt`: JWT authentication token (required)
- `apiBaseURL`: Base URL of the Vortex API (defaults to production)
- `group`: Optional group context for scoped invitations
- `onDismiss`: Callback invoked when the view is dismissed

### VortexClient

Low-level API client for direct backend communication.

```swift
let client = VortexClient(
    baseURL: URL(string: "https://client-api.vortexsoftware.com")!
)

// Fetch configuration
let config = try await client.getWidgetConfiguration(
    componentId: "component-id",
    jwt: "jwt-token"
)

// Create invitation
let response = try await client.createInvitation(
    jwt: "jwt-token",
    widgetConfigurationId: config.id,
    payload: ["invitee_email": ["value": "user@example.com", "type": "email"]],
    groups: [GroupDTO(id: nil, groupId: "team-123", type: "team", name: "Engineering")]
)

// Get shareable link
let linkResponse = try await client.getShareableLink(
    jwt: "jwt-token",
    widgetConfigurationId: config.id,
    groups: [GroupDTO(id: nil, groupId: "team-123", type: "team", name: "Engineering")]
)
```

### GroupDTO

```swift
struct GroupDTO {
    let id: String?
    let groupId: String?
    let type: String
    let name: String
}
```

## Current Status

**✅ MVP Features Implemented:**
- Widget configuration fetching
- Basic invitation form UI
- Email invitation sending
- Error handling and loading states
- JWT authentication
- Group context support

**⚠️ TODO (See TODO.md for details):**
- Dynamic form rendering from configuration
- Platform integrations (contacts, sharing, etc.)
- Advanced UI components (role selection, bulk invites, etc.)
- QR code generation
- Google Contacts integration
- Native share sheet integration

This is a **Minimal Viable Product (MVP)**. The SDK currently provides a basic email invitation form. For the full feature set matching the React Native SDK, see `TODO.md`.

## Examples

See the [demo app](../vortex-ios-demo) for complete integration examples.

## Configuration

The SDK automatically fetches and caches widget configuration from your Vortex backend. The configuration determines:
- Available invitation methods
- Form fields and validation
- UI theme and styling
- Enabled features

## Error Handling

The SDK provides structured error types:

```swift
enum VortexError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case encodingError(Error)
    case missingConfiguration
    case missingJWT
}
```

Handle errors in your UI:

```swift
.task {
    do {
        let jwt = try await fetchVortexToken()
        // Use jwt...
    } catch let error as VortexError {
        // Handle specific Vortex errors
        print("Vortex error: \(error.localizedDescription)")
    } catch {
        // Handle other errors
        print("Unknown error: \(error)")
    }
}
```

## License

Apache-2.0

## Support

For questions or issues:
- Documentation: https://docs.vortexsoftware.com
- Email: support@vortexsoftware.com
- GitHub Issues: https://github.com/teamvortexsoftware/vortex-ios-sdk/issues

## Related Projects

- [Vortex React Native SDK](https://github.com/teamvortexsoftware/vortex/tree/main/packages/vortex-react-native)
- [Vortex React SDK](https://github.com/teamvortexsoftware/vortex/tree/main/packages/vortex-react)
