# Vortex iOS SDK

Configuration-driven invitation forms for native iOS apps.

## Overview

The Vortex iOS SDK provides a SwiftUI component for rendering customizable invitation forms in your iOS applications. The SDK fetches configuration from your Vortex backend and dynamically renders the appropriate UI.

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 14.0+

> **Note:** Google Contacts integration requires iOS 15.0+. On iOS 14, all features except Google Contacts are available.

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

### With Scope Context

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
                onDismiss: {
                    showInviteForm = false
                },
                scope: team.id,
                scopeType: "team"
            )
        }
    }
}
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
            InviteContactsContact(name: "Alice Johnson", phoneNumber: "+1 (555) 123-4567"),
            InviteContactsContact(name: "Bob Smith", phoneNumber: "+1 (555) 234-5678"),
            InviteContactsContact(name: "Carol Davis", phoneNumber: "+1 (555) 345-6789")
        ]
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

**InviteContactsContact Properties:**

```swift
// Simple usage - just name and phone number (ID is auto-generated)
InviteContactsContact(
    name: String,            // Display name
    phoneNumber: String,     // Phone number for SMS
    avatarUrl: String?,      // Optional avatar image URL
    metadata: [String: Any]? // Optional custom metadata
)

// Full usage - with custom ID
InviteContactsContact(
    id: String,              // Custom unique identifier
    name: String,            // Display name
    phoneNumber: String,     // Phone number for SMS
    avatarUrl: String?,      // Optional avatar image URL
    metadata: [String: Any]? // Optional custom metadata
)
```

**InviteContactsConfig Properties:**

```swift
InviteContactsConfig(
    contacts: [InviteContactsContact]  // List of contacts to display
)
```

### Find Friends

The Find Friends component displays a list of contacts provided by your app. Each contact has a "Connect" button that creates an invitation with `targetType: internalId`.

**Basic Usage:**

```swift
import VortexSDK

VortexInviteView(
    componentId: "your-component-id",
    jwt: jwt,
    findFriendsConfig: FindFriendsConfig(
        contacts: [
            FindFriendsContact(internalId: "user-123", name: "Alice Johnson", subtitle: "@alice"),
            FindFriendsContact(internalId: "user-456", name: "Bob Smith", subtitle: "@bob")
        ],
        onInvitationCreated: { contact in
            // Called after an invitation is successfully created
            // Use this to trigger in-app notifications
            print("Invitation created for \(contact.name)")
        }
    ),
    onDismiss: { /* ... */ }
)
```

**How It Works:**

1. Your app provides a list of contacts with internal IDs (users already in your platform)
2. The component displays them with a "Connect" button (text configurable via widget config)
3. When the user taps "Connect", the SDK creates an invitation via the Vortex API with `targetType: internalId`
4. The `onInvitationCreated` callback is called after a successful invitation
5. The section is hidden when there are no contacts to display

**FindFriendsContact Properties:**

```swift
FindFriendsContact(
    internalId: String,          // Required: ID in your platform
    name: String,                // Required: Display name
    subtitle: String?,           // Optional: Secondary text (e.g., username)
    avatarUrl: String?,          // Optional: Avatar image URL
    metadata: [String: Any]?     // Optional: Custom metadata
)
```

**FindFriendsConfig Properties:**

```swift
FindFriendsConfig(
    contacts: [FindFriendsContact],                        // Required: List of contacts to display
    onInvitationCreated: ((FindFriendsContact) -> Void)?   // Optional: Called after successful invitation
)
```

### Invitation Suggestions

The Invitation Suggestions component displays a list of suggested contacts provided by your app. Each contact has an "Invite" button and a dismiss (X) button. When the user taps "Invite", an invitation with `targetType: internalId` is created. The dismiss button removes the suggestion from the list.

**Basic Usage:**

```swift
import VortexSDK

VortexInviteView(
    componentId: "your-component-id",
    jwt: jwt,
    invitationSuggestionsConfig: InvitationSuggestionsConfig(
        contacts: [
            InvitationSuggestionContact(
                internalId: "user-123",
                name: "Alice Johnson",
                subtitle: "@alice",
                avatarUrl: "https://example.com/alice-avatar.jpg"
            ),
            InvitationSuggestionContact(
                internalId: "user-456",
                name: "Bob Smith",
                subtitle: "@bob"
            )
        ],
        onDismiss: { contact in
            // Called when user taps the X button
            print("Dismissed suggestion for \(contact.name)")
        },
        onInvitationCreated: { contact in
            print("Invitation created for \(contact.name)")
        },
        onInvitationFailed: { contact, error in
            print("Failed to invite \(contact.name): \(error)")
        }
    ),
    onDismiss: { /* ... */ }
)
```

**How It Works:**

1. Your app provides a list of suggested contacts with internal IDs
2. The component displays them with an "Invite" button and a dismiss (X) button
3. When the user taps "Invite", the SDK creates an invitation via the Vortex API with `targetType: internalId`
4. The `onInvitationCreated` or `onInvitationFailed` callback is called based on the result
5. When the user taps the X button, the `onDismiss` callback is called and the contact is removed from the list

**InvitationSuggestionContact Properties:**

```swift
InvitationSuggestionContact(
    internalId: String,          // Required: ID in your platform
    name: String,                // Required: Display name
    subtitle: String?,           // Optional: Secondary text (e.g., username)
    avatarUrl: String?,          // Optional: Avatar image URL (rendered instead of initials if provided)
    metadata: [String: Any]?     // Optional: Custom metadata
)
```

**InvitationSuggestionsConfig Properties:**

```swift
InvitationSuggestionsConfig(
    contacts: [InvitationSuggestionContact],                      // Required: List of contacts to display
    onDismiss: (InvitationSuggestionContact) -> Void,             // Required: Called when user dismisses a suggestion
    onInvitationCreated: ((InvitationSuggestionContact) -> Void)?,  // Called after successful invitation
    onInvitationFailed: ((InvitationSuggestionContact, Error) -> Void)?  // Called on failure
)
```

### Incoming Invitations

The Incoming Invitations component displays invitations the user has received, with Accept and Delete actions.

**Basic Usage:**

```swift
import VortexSDK

VortexInviteView(
    componentId: "your-component-id",
    jwt: jwt,
    incomingInvitationsConfig: IncomingInvitationsConfig(
        onAccept: { invitation in
            // Handle acceptance (return true to proceed with API call)
            await myAPI.acceptInvitation(invitation.id)
            return true
        },
        onDelete: { invitation in
            // Handle deletion (return true to proceed with API call)
            return true
        }
    ),
    onDismiss: { /* ... */ }
)
```

**With Internal Invitations:**

You can merge your app's invitations with Vortex API invitations:

```swift
IncomingInvitationsConfig(
    internalInvitations: [
        IncomingInvitationItem(
            id: "internal-1",
            name: "Alice Johnson",
            subtitle: "alice@example.com",
            avatarUrl: "https://example.com/avatar.jpg"
        )
    ],
    onAccept: { invitation in
        if invitation.isVortexInvitation {
            // Vortex invitation: return true to let SDK call the Vortex API
            return true
        } else {
            // Internal/app invitation: handle it yourself, return false (no API call needed)
            await myAPI.acceptInvitation(invitation.id)
            return true  // Return true to remove from list
        }
    },
    onDelete: { invitation in
        if invitation.isVortexInvitation {
            return true  // Let SDK handle the API call
        } else {
            await myAPI.deleteInvitation(invitation.id)
            return true  // Return true to remove from list
        }
    }
)
```

**Identifying Invitation Source:**

Use the `isVortexInvitation` property to determine where an invitation came from:
- `true`: Fetched from the Vortex API — the SDK will handle accept/delete API calls
- `false`: Provided by your app via `internalInvitations` — your app must handle the action

**IncomingInvitationsConfig Properties:**

```swift
IncomingInvitationsConfig(
    internalInvitations: [IncomingInvitationItem]?,  // App-provided invitations (isVortexInvitation = false)
    onAccept: ((IncomingInvitationItem) async -> Bool)?,  // Called when user accepts
    onDelete: ((IncomingInvitationItem) async -> Bool)?   // Called when user deletes
)
```

**Callback Return Values:**

| Invitation Source | Return `true` | Return `false` |
|-------------------|---------------|----------------|
| Vortex (`isVortexInvitation == true`) | SDK calls Vortex API, removes from list | Cancels the action |
| Internal (`isVortexInvitation == false`) | Removes from list (no API call) | Keeps in list |

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
    googleIosClientId: String? = nil,
    onEvent: ((VortexAnalyticsEvent) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil,
    findFriendsConfig: FindFriendsConfig? = nil,
    invitationSuggestionsConfig: InvitationSuggestionsConfig? = nil,
    inviteContactsConfig: InviteContactsConfig? = nil,
    incomingInvitationsConfig: IncomingInvitationsConfig? = nil,
    locale: String? = nil,
    scope: String? = nil,
    scopeType: String? = nil
)
```

**Parameters:**
- `componentId`: Your widget/component ID from the Vortex dashboard
- `jwt`: JWT authentication token (required for API access)
- `googleIosClientId`: Google iOS Client ID for Google Contacts integration (optional)
- `onEvent`: Callback for analytics events (optional)
- `onDismiss`: Callback invoked when the view is dismissed
- `findFriendsConfig`: Optional configuration for the Find Friends feature (see [Find Friends](#find-friends))
- `invitationSuggestionsConfig`: Optional configuration for the Invitation Suggestions feature (see [Invitation Suggestions](#invitation-suggestions))
- `inviteContactsConfig`: Optional configuration for the Invite Contacts feature (see [Invite Contacts](#invite-contacts))
- `incomingInvitationsConfig`: Optional configuration for the Incoming Invitations feature (see [Incoming Invitations](#incoming-invitations))
- `locale`: Optional BCP 47 language code for internationalization (e.g., "pt-BR", "en-US")
- `scope`: Scope identifier for scoping invitations (e.g., team ID, project ID). Used with `scopeType`.
- `scopeType`: Type of the scope (e.g., "team", "project"). Used with `scope`.

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
                print("Scope: \(context.scope ?? "N/A")")
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
    var scope: String?          // Scope identifier (e.g., team ID, project ID)
    var scopeType: String?      // Type of the scope (e.g., "team", "project")
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
