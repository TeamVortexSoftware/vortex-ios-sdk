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

### Prefetch for Instant Rendering

The SDK supports prefetching widget configurations to eliminate loading delays when opening the invite form. This uses a **stale-while-revalidate** pattern: cached configurations are shown immediately while fresh data is fetched in the background.

**Automatic Caching (Zero Code Changes)**

After the first load, configurations are automatically cached. Subsequent opens of `VortexInviteView` with the same `componentId` will render instantly:

```swift
// First open: shows loading spinner, fetches config, caches it
// Second open: renders instantly from cache, refreshes in background
VortexInviteView(
    componentId: "your-component-id",
    jwt: jwt,
    onDismiss: { /* ... */ }
)
```

**Manual Prefetch (For Optimal UX)**

Use `VortexConfigurationPrefetcher` to fetch configurations early, such as when the user logs in or when JWT becomes available:

```swift
import VortexSDK

class AppViewModel: ObservableObject {
    private var prefetcher: VortexConfigurationPrefetcher?
    
    func onUserLoggedIn(jwt: String) {
        // Start prefetching immediately
        prefetcher = VortexConfigurationPrefetcher(componentId: "your-component-id")
        Task {
            await prefetcher?.prefetch(jwt: jwt)
        }
    }
}

// Later, VortexInviteView uses the cached configuration automatically
VortexInviteView(
    componentId: "your-component-id",
    jwt: jwt,
    onDismiss: { /* ... */ }
)
```

**Pass Configuration Directly**

If you have a configuration from another source, pass it directly:

```swift
VortexInviteView(
    componentId: "your-component-id",
    jwt: jwt,
    widgetConfiguration: prefetchedConfig,
    onDismiss: { /* ... */ }
)
```

### Invite Contacts

The Invite Contacts component displays a list of contacts that can be invited via SMS. Unlike the Contact Import feature (which fetches contacts from the device), Invite Contacts receives a pre-populated list of contacts from your app.

**Basic Usage:**

```swift
import VortexSDK

VortexInviteView(
    componentId: "your-component-id",
    jwt: jwt,
    inviteContactsConfig: InviteContactsConfig(
        contacts: [
            InviteContactsContact(id: "1", name: "Alice Johnson", phoneNumber: "+1 (555) 123-4567"),
            InviteContactsContact(id: "2", name: "Bob Smith", phoneNumber: "+1 (555) 234-5678"),
            InviteContactsContact(id: "3", name: "Carol Davis", phoneNumber: "+1 (555) 345-6789")
        ],
        onInvitationSent: { contact, shortLink in
            print("SMS sent to \(contact.name) with link: \(shortLink)")
        }
    ),
    onDismiss: { /* ... */ }
)
```

**How It Works:**

1. The component shows an "Invite your contacts" entry with a contact count
2. Tapping it navigates to a searchable list of contacts
3. Each contact has an "Invite" button that:
   - Creates an SMS invitation via the Vortex API
   - Opens the in-app SMS composer (on supported devices)
   - Pre-fills the message with the invitation link
4. The `onInvitationSent` callback is called when the SMS is actually sent

**Callback Behavior:**

The `onInvitationSent` callback has different behavior depending on the environment:

| Environment | Behavior |
|-------------|----------|
| Real device with SMS | Called only when user taps "Send" in the SMS composer |
| Real device without SMS | Called optimistically when Messages app opens (fallback) |
| iOS Simulator | Called when user taps "Send" in the simulated composer |

**InviteContactsContact Properties:**

```swift
InviteContactsContact(
    id: String,              // Unique identifier
    name: String,            // Display name
    phoneNumber: String,     // Phone number for SMS
    avatarUrl: String?,      // Optional avatar image URL
    metadata: [String: Any]? // Optional custom metadata
)
```

**InviteContactsConfig Properties:**

```swift
InviteContactsConfig(
    contacts: [InviteContactsContact],  // List of contacts to display
    onInvitationSent: ((contact, shortLink) -> Void)?,  // Called when SMS is sent
    onNavigateToContacts: (() -> Void)?,  // Analytics: user opened contacts list
    onNavigateBack: (() -> Void)?         // Analytics: user went back
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

## Deferred Deep Linking

Deferred deep linking allows your app to retrieve invitation context even when a user installs the app after clicking an invitation link. When a user clicks an invitation link but doesn't have the app installed, they're redirected to the App Store. After installation, the SDK can match the device fingerprint to retrieve the original invitation context.

### Basic Usage

Call `VortexDeferredLinks.retrieveDeferredDeepLink` when the user signs in or when the app session is restored:

```swift
import VortexSDK

class AuthManager: ObservableObject {
    func onUserSignedIn(vortexJwt: String) async {
        do {
            let result = try await VortexDeferredLinks.retrieveDeferredDeepLink(jwt: vortexJwt)
            
            if result.matched, let context = result.context {
                print("Found pending invitation!")
                print("Invitation ID: \(context.invitationId)")
                print("Inviter ID: \(context.inviterId ?? "N/A")")
                print("Group ID: \(context.groupId ?? "N/A")")
                // Handle the invitation (e.g., show UI, auto-join group, etc.)
            }
        } catch {
            print("Deferred link check failed: \(error)")
        }
    }
}
```

### Response Types

**MatchFingerprintResponse:**
```swift
struct MatchFingerprintResponse {
    let matched: Bool           // Whether a matching invitation was found
    let confidence: Double?     // Match confidence score (0.0 - 1.0)
    let context: DeferredLinkContext?  // Invitation context if matched
    let error: String?          // Error message if any
}
```

**DeferredLinkContext:**
```swift
struct DeferredLinkContext {
    let invitationId: String    // The original invitation ID
    let inviterId: String?      // ID of the user who sent the invitation
    let groupId: String?        // Group/team ID if applicable
    let metadata: [String: AnyCodable]?  // Additional metadata
}
```

### Best Practices

1. **Call on authentication**: Check for deferred deep links immediately after user sign-in or session restore
2. **Use Vortex JWT**: The endpoint requires a Vortex JWT token (not your app's auth token)
3. **Handle once**: Clear or mark the invitation as handled after processing to avoid showing it repeatedly
4. **Graceful degradation**: The check may fail (network issues, no match found) - handle errors gracefully

### Example Integration

```swift
import SwiftUI
import VortexSDK

@MainActor
class AppViewModel: ObservableObject {
    @Published var pendingInvitation: DeferredLinkContext?
    
    func checkForPendingInvitations(vortexJwt: String) async {
        do {
            let result = try await VortexDeferredLinks.retrieveDeferredDeepLink(jwt: vortexJwt)
            
            if result.matched {
                pendingInvitation = result.context
            }
        } catch {
            // Log error but don't block the user
            print("Deferred deep link check failed: \(error)")
        }
    }
    
    func dismissPendingInvitation() {
        pendingInvitation = nil
    }
}
```

## Features

**Invitation Methods:**
- Email invitations with validation
- Copy shareable link to clipboard
- Native iOS share sheet integration
- SMS sharing
- QR code generation
- LINE messaging integration

**Contact Import:**
- iOS Contacts integration
- Google Contacts integration (requires GoogleSignIn SDK)

**Invite Contacts:**
- Display a list of contacts for SMS invitation
- In-app SMS composer on supported devices
- Callback when SMS is actually sent (not just opened)

**Core Capabilities:**
- Dynamic form rendering from server configuration
- JWT authentication
- Group/team context support
- Real-time loading states and error handling
- Customizable UI based on widget configuration
- Deferred deep linking via fingerprint matching

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
