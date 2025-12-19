# Vortex iOS SDK - Development Guidelines

## What is Vortex?

Vortex is an **invitations-as-a-service** platform. We provide SDKs that render dynamic invitation forms configured via a backend API. The forms support multiple invitation methods (email, SMS, shareable links, QR codes, social sharing) and can import contacts from device or Google.

The SDK fetches a `WidgetConfiguration` from the Vortex API, which contains a tree of `ElementNode` objects that define the UI structure. The SDK renders this configuration dynamically using SwiftUI.

## Related Projects

| Project | Path                                                            | Description |
|---------|-----------------------------------------------------------------|-------------|
| **iOS SDK** | `.` (this repo)                                                 | This repository - Swift/SwiftUI SDK |
| **iOS Demo App** | (separate repo: `../vortex-ios-demo`)                           | Demo app called "Acme Tasks" |
| **React Native SDK** | (separate repo: `../vortex-suite/packages/vortex-react-native`) | RN SDK (reference implementation) |
| **React Native Demo** | (separate repo: `../vortex-suite/standalone/demo-react-native`) | RN demo app |
| **Shared UI Code** | (separate repo: `../vortex-suite/packages/vortex-shared-ui`)    | Shared UI components used by RN SDK |

**Important:** The React Native SDK is the reference implementation. When implementing features or fixing bugs, check how the RN SDK handles it for consistency.

## iOS SDK Code Organization

```
Sources/VortexSDK/
├── API/
│   ├── DTOs/
│   │   └── APIResponses.swift      # Response DTOs (WidgetConfigurationResponse, CreateInvitationResponse, etc.)
│   ├── VortexClient.swift          # Main API client for backend communication
│   └── VortexError.swift           # Error types (VortexError enum)
├── Extensions/
│   └── View+Extensions.swift       # SwiftUI view extensions (RoundedCorner, AttributeValue helpers)
├── Models/
│   ├── InviteViewState.swift       # View state enum (main, emailEntry, contactsPicker, etc.)
│   ├── VortexContact.swift         # Contact model for device/Google contacts
│   └── WidgetConfiguration.swift   # Configuration models (ElementNode, Theme, etc.)
├── ViewModels/
│   └── VortexInviteViewModel.swift # Main ViewModel (~900 lines) - handles all business logic
├── Views/
│   ├── Components/
│   │   ├── ContactComponents.swift # ContactsImportView, ContactsPickerView, GoogleContactsPickerView
│   │   ├── FormComponents.swift    # Form elements (Textbox, Select, Radio, Checkbox, etc.)
│   │   └── ShareComponents.swift   # ShareOptionsView, ShareButton, EmailPillView
│   ├── FontAwesomeLoader.swift     # Loads bundled FontAwesome 6 fonts
│   ├── VortexIcon.swift            # Icon component using FontAwesome with SF Symbol fallbacks
│   └── VortexInviteView.swift      # Main entry point view (~686 lines)
├── Resources/
│   ├── fa-brands-400.ttf           # FontAwesome brand icons (Google, WhatsApp, etc.)
│   ├── fa-regular-400.ttf          # FontAwesome regular icons
│   └── fa-solid-900.ttf            # FontAwesome solid icons
└── VortexSDK.swift                 # SDK version info and namespace
```

## Key Architectural Patterns

### Dynamic Form Rendering
The SDK uses a recursive rendering approach:
- `VortexInviteView.formView` → `renderRow()` → `renderColumn()` → `renderBlock()`
- `renderBlock()` uses a switch on `block.subtype` to render the appropriate component
- Uses `AnyView` for type erasure (known limitation - could be improved with `@ViewBuilder`)

### State Management
- `VortexInviteViewModel` is the single source of truth
- Uses `@Published` properties for reactive UI updates
- `@MainActor` ensures UI updates happen on main thread

### Configuration-Driven UI
- All UI is driven by `WidgetConfiguration` fetched from API
- `ElementNode` tree structure mirrors the RN SDK's approach
- Feature flags (e.g., `isCopyLinkEnabled`, `isSmsEnabled`) are derived from configuration

## Dependencies

- **GoogleSignIn-iOS** (v7.0.0+): For Google Contacts integration
- **FontAwesome 6 Free**: Bundled TTF fonts for icons

## Important Notes for Future Sessions

1. **No debug prints in production**: All `print("[VortexSDK]...")` statements were removed. Use OSLog if logging is needed.

2. **Test file is placeholder**: `VortexSDKTests.swift` contains only a placeholder test. Real tests should be added.

3. **AnyView usage**: The `renderBlock()` function uses `AnyView` which impacts SwiftUI performance. This is a known trade-off for handling 20+ element types.

4. **Google Sign-In setup**: Requires `googleIosClientId` parameter and proper URL scheme configuration in the host app.

5. **Minimum iOS version**: iOS 15.0+ (set in Package.swift)

6. **Build command**: Use Xcode or `xcodebuild -scheme VortexSDK -destination 'platform=iOS Simulator,name=iPhone 16' build`

## API Endpoints Used

- `GET /api/v1/widgets/{componentId}` - Fetch widget configuration
- `POST /api/v1/invitations` - Create invitation
- `POST /api/v1/invitations/generate-shareable-link-invite` - Get shareable link

## Common Tasks

### Adding a new element type
1. Add case to `renderBlock()` in `VortexInviteView.swift`
2. Create component in appropriate file under `Views/Components/`
3. Check RN SDK for reference implementation

### Adding a new share method
1. Add feature flag computed property in `VortexInviteViewModel`
2. Add action method in ViewModel
3. Add button in `ShareOptionsView`
4. Add icon to `VortexIconName` enum if needed
