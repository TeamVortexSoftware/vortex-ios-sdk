# Vortex iOS SDK - TODO

This document outlines all remaining features needed to achieve feature parity with the React Native SDK. Each item represents a complete, testable feature that can be implemented in a separate session.

---

## ✅ Completed (MVP - v1.0.0)

- [x] Swift Package Manager structure with Package.swift
- [x] Core data models (WidgetConfiguration, ElementNode, PageData, Theme)
- [x] VortexClient API layer (configuration fetching, invitation creation, shareable links)
- [x] Basic VortexInviteView SwiftUI component with loading/error states
- [x] Simple email invitation form (placeholder UI)
- [x] JWT authentication support
- [x] Group context support for scoped invitations
- [x] Error handling with VortexError enum
- [x] Session attestation handling
- [x] README with installation and usage docs

---

## 🔴 High Priority - Core Features

### 1. Dynamic Form Rendering Engine
**Complexity:** High | **Estimated Effort:** 2-3 sessions

Implement a SwiftUI view builder that dynamically renders forms based on `WidgetConfiguration.props["vortex.mobile.page_data"]`.

**Requirements:**
- Parse `ElementNode` tree structure (root → rows → columns → blocks)
- Map element subtypes to SwiftUI views:
  - `vrtx-heading` → Text with custom styling
  - `vrtx-textbox` → TextField
  - `vrtx-select` → Picker or custom dropdown
  - `vrtx-submit` → Button
  - `vrtx-share-options` → Share buttons grid
  - `vrtx-contacts-import` → Contact picker integration
  - `vrtx-email-invitations` → Email list input
- Apply styles from `ElementNode.style` dictionary
- Apply theme colors from `ElementNode.theme`
- Handle responsive layouts based on `ElementSettings.layout`

**Testing:**
- Unit tests for ElementNode parsing
- UI tests for each component type rendering
- Integration test with sample configuration from backend

**Files to create/modify:**
- `Sources/VortexSDK/Views/FormRenderer.swift`
- `Sources/VortexSDK/Views/Components/VrtxHeading.swift`
- `Sources/VortexSDK/Views/Components/VrtxTextbox.swift`
- `Sources/VortexSDK/Views/Components/VrtxSelect.swift`
- `Sources/VortexSDK/Views/Components/VrtxSubmit.swift`
- Update `VortexInviteView.swift` to use FormRenderer

---

### 2. Theme and Styling System
**Complexity:** Medium | **Estimated Effort:** 1 session

Apply dynamic theming based on widget configuration.

**Requirements:**
- Extract theme colors from `configuration.props["vortex.theme"]`
- Parse CSS-style strings from `ElementNode.style` to SwiftUI modifiers
- Support common CSS properties:
  - `backgroundColor`, `color`, `fontSize`, `fontWeight`
  - `padding`, `margin`, `borderRadius`, `borderWidth`, `borderColor`
- Create SwiftUI ViewModifiers for theme application
- Handle light/dark mode variants if specified in theme

**Testing:**
- Test theme extraction from various configurations
- Visual regression tests for styled components
- Dark mode compatibility tests

**Files to create/modify:**
- `Sources/VortexSDK/Theme/ThemeManager.swift`
- `Sources/VortexSDK/Theme/StyleParser.swift`
- `Sources/VortexSDK/Theme/ThemeModifiers.swift`

---

### 3. Role Selection Component
**Complexity:** Medium | **Estimated Effort:** 1 session

Implement role picker for invitations (member, admin, etc.).

**Requirements:**
- Parse role options from `vrtx-select` element with `vortex.role` metadata
- Render as native iOS picker or custom styled buttons
- Support single and multi-select modes
- Include role in invitation payload as `role: { value: "admin", type: "string" }`

**Testing:**
- Test with various role configurations
- Verify payload contains correct role value
- UI tests for picker interaction

**Files to create/modify:**
- `Sources/VortexSDK/Views/Components/VrtxRoleSelect.swift`
- Update `VortexInviteViewModel` to handle role state

---

### 4. Bulk Email Invitations
**Complexity:** Medium | **Estimated Effort:** 1 session

Support inviting multiple email addresses at once.

**Requirements:**
- Implement `vrtx-email-invitations` component
- Parse comma/newline-separated email list
- Validate each email address
- Show validation errors inline
- Send multiple invitations in parallel (with rate limiting)
- Show progress indicator during bulk send
- Display success/error status for each email

**Testing:**
- Test with valid and invalid email formats
- Test with 1, 10, 50, 100 emails
- Test error handling for partial failures
- Test rate limiting behavior

**Files to create/modify:**
- `Sources/VortexSDK/Views/Components/VrtxEmailInvitations.swift`
- `Sources/VortexSDK/Utils/EmailValidator.swift`
- Update `VortexClient.swift` with bulk invitation method

---

## 🟡 Medium Priority - Platform Integrations

### 5. iOS Contacts Access
**Complexity:** Medium | **Estimated Effort:** 1 session

Enable importing contacts from iOS Contacts app.

**Requirements:**
- Request Contacts permission using `NSContactsUsageDescription`
- Implement `vrtx-contacts-import` component
- Fetch contacts with email addresses using `CNContactStore`
- Display searchable contact list with sections (A-Z)
- Support multi-select with checkboxes
- Show contact name + email in list
- Handle permission denied gracefully with explanation

**Testing:**
- Test permission request flow
- Test with 0, 10, 1000+ contacts
- Test search/filtering
- Test multi-select behavior
- Test on simulator and real device

**Files to create/modify:**
- `Sources/VortexSDK/Services/ContactsService.swift`
- `Sources/VortexSDK/Views/Components/VrtxContactsImport.swift`
- Add `NSContactsUsageDescription` to demo app Info.plist

---

### 6. Share Sheet Integration
**Complexity:** Low | **Estimated Effort:** 0.5 session

Integrate native iOS share sheet for invitation links.

**Requirements:**
- Implement `vrtx-share-options` component with share button
- Use `UIActivityViewController` to present share sheet
- Support sharing via:
  - Messages (SMS/iMessage)
  - Mail
  - WhatsApp
  - Twitter/X
  - Any installed sharing extension
- Pre-fill message text with invitation link
- Track share completion (if possible)

**Testing:**
- Test share sheet presentation
- Test each share target (simulator + device)
- Test with long/short links
- Test cancellation handling

**Files to create/modify:**
- `Sources/VortexSDK/Views/Components/VrtxShareOptions.swift`
- `Sources/VortexSDK/Services/ShareService.swift`

---

### 7. Clipboard Copy with Feedback
**Complexity:** Low | **Estimated Effort:** 0.5 session

Copy shareable link to clipboard with visual confirmation.

**Requirements:**
- Use `UIPasteboard` to copy link
- Show toast notification: "Link copied to clipboard"
- Add haptic feedback on copy
- Auto-dismiss toast after 2 seconds
- Support both light and dark mode for toast

**Testing:**
- Test copy functionality
- Verify clipboard contents
- Test toast appearance/disappearance
- Test haptic feedback on device

**Files to create/modify:**
- `Sources/VortexSDK/Views/Components/ToastView.swift`
- Update `VortexInviteView` with copy button

---

### 8. Google Contacts Integration
**Complexity:** High | **Estimated Effort:** 2 sessions

Enable importing contacts from Google account.

**Requirements:**
- Integrate Google Sign-In SDK for iOS
- Request OAuth scopes: `contacts.readonly`, `email`, `profile`
- Implement silent sign-in + interactive fallback
- Fetch contacts from Google People API
- Display in same UI as iOS Contacts
- Handle OAuth errors and token refresh
- Support account switching

**Testing:**
- Test Google Sign-In flow
- Test with Google accounts (personal + workspace)
- Test offline/network error handling
- Test token expiration/refresh
- Test with 0, 100, 1000+ contacts

**Dependencies:**
- Add `GoogleSignIn` Swift Package
- Configure OAuth client ID in Info.plist

**Files to create/modify:**
- `Sources/VortexSDK/Services/GoogleContactsService.swift`
- Update `VrtxContactsImport.swift` to support Google source
- Add `CFBundleURLTypes` to demo app Info.plist for OAuth redirect

---

### 9. QR Code Generation
**Complexity:** Low | **Estimated Effort:** 0.5 session

Generate and display QR codes for shareable invitation links.

**Requirements:**
- Generate QR code using `CoreImage.CIFilter`
- Display in modal/sheet view
- Support adjustable size (based on screen size)
- Add "Save to Photos" button
- Request Photos permission if saving
- Support light/dark background options

**Testing:**
- Test QR code generation with various link lengths
- Test scanning with camera app
- Test save to Photos
- Test on different screen sizes (iPhone, iPad)

**Files to create/modify:**
- `Sources/VortexSDK/Views/Components/VrtxQRCodeView.swift`
- `Sources/VortexSDK/Utils/QRCodeGenerator.swift`

---

## 🟢 Low Priority - Polish & Advanced Features

### 10. Form Validation Framework
**Complexity:** Medium | **Estimated Effort:** 1 session

Implement client-side validation based on `ElementNode.validation` rules.

**Requirements:**
- Parse validation rules from configuration:
  - `required`, `minLength`, `maxLength`, `pattern`, `email`
- Show validation errors inline below fields
- Prevent form submission if invalid
- Support async validation (e.g., check if email already invited)
- Show validation state with icons (✓ or ✗)

**Testing:**
- Test each validation rule type
- Test real-time vs on-blur validation
- Test custom error messages
- Test async validation with delays

**Files to create/modify:**
- `Sources/VortexSDK/Validation/ValidationEngine.swift`
- `Sources/VortexSDK/Validation/ValidationRule.swift`
- Update form components to support validation

---

### 11. Loading States and Animations
**Complexity:** Low | **Estimated Effort:** 0.5 session

Add polished loading states and transitions.

**Requirements:**
- Skeleton loaders for configuration fetch
- Smooth transitions between views
- Pull-to-refresh for configuration reload
- Animated button states (loading spinner in button)
- Success animation after invitation sent
- Error shake animation for invalid inputs

**Testing:**
- Visual regression tests for animations
- Test on slow network (Network Link Conditioner)
- Test animation performance on older devices

**Files to create/modify:**
- `Sources/VortexSDK/Views/Components/SkeletonView.swift`
- `Sources/VortexSDK/Views/Components/AnimatedButton.swift`
- Add SwiftUI animation modifiers throughout

---

### 12. Configuration Caching
**Complexity:** Medium | **Estimated Effort:** 1 session

Cache widget configurations locally for faster loading.

**Requirements:**
- Cache configurations in UserDefaults or file system
- Implement cache invalidation based on `updatedAt` timestamp
- Support stale-while-revalidate pattern (show cached, fetch fresh)
- Add cache size limits and cleanup
- Support manual cache clear

**Testing:**
- Test cache hit/miss scenarios
- Test stale data handling
- Test cache persistence across app launches
- Test cache invalidation

**Files to create/modify:**
- `Sources/VortexSDK/Services/ConfigurationCache.swift`
- Update `VortexClient` to use cache

---

### 13. Analytics and Event Tracking
**Complexity:** Low | **Estimated Effort:** 0.5 session

Add optional analytics hooks for tracking SDK usage.

**Requirements:**
- Define event types: `inviteShown`, `inviteSent`, `shareLinkGenerated`, etc.
- Provide protocol for customer analytics implementation
- No built-in analytics dependency (customer brings their own)
- Include metadata: componentId, platform, SDK version

**Testing:**
- Test events fire at correct times
- Test with mock analytics implementation
- Verify metadata is included

**Files to create/modify:**
- `Sources/VortexSDK/Analytics/AnalyticsProtocol.swift`
- `Sources/VortexSDK/Analytics/AnalyticsEvent.swift`
- Update `VortexInviteView` to fire events

---

### 14. Accessibility (a11y) Support
**Complexity:** Medium | **Estimated Effort:** 1 session

Ensure SDK is accessible with VoiceOver and other assistive technologies.

**Requirements:**
- Add accessibility labels to all interactive elements
- Add accessibility hints for non-obvious actions
- Support Dynamic Type for text scaling
- Ensure proper focus order for VoiceOver
- Support Reduce Motion preference
- Test with VoiceOver enabled

**Testing:**
- Run through entire flow with VoiceOver
- Test with Dynamic Type at max size
- Test with Reduce Motion enabled
- Use Accessibility Inspector tool

**Files to modify:**
- All SwiftUI view files (add `.accessibilityLabel()`, etc.)

---

### 15. Localization (i18n) Support
**Complexity:** Medium | **Estimated Effort:** 1 session

Support multiple languages for SDK UI strings.

**Requirements:**
- Extract all hardcoded strings to `Localizable.strings`
- Support language from device settings
- Provide mechanism for custom translations
- RTL layout support for Arabic, Hebrew, etc.
- Include translations for common languages:
  - English, Spanish, French, German, Portuguese

**Testing:**
- Test in each supported language
- Test RTL layouts
- Test custom translation overrides

**Files to create/modify:**
- `Sources/VortexSDK/Resources/en.lproj/Localizable.strings`
- `Sources/VortexSDK/Resources/es.lproj/Localizable.strings`
- etc.
- Update Package.swift to include resources

---

### 16. iPad Optimization
**Complexity:** Low | **Estimated Effort:** 0.5 session

Optimize layouts for iPad screen sizes.

**Requirements:**
- Use adaptive layouts based on size class
- Support landscape orientation
- Optimize modal presentation (use form sheet style)
- Use multi-column layouts on larger screens
- Test on all iPad sizes (9.7", 10.2", 11", 12.9")

**Testing:**
- Test on iPad simulators (all sizes)
- Test portrait and landscape
- Test split-screen multitasking

**Files to modify:**
- Update `VortexInviteView` with adaptive layouts
- Add size class checks in form renderer

---

### 17. Deep Link Handling
**Complexity:** Medium | **Estimated Effort:** 1 session

Support opening invitation links directly in the app.

**Requirements:**
- Register custom URL scheme: `vortex://invite/{token}`
- Parse invitation token from deep link
- Auto-populate form with invitation data
- Support universal links (HTTPS URLs)

**Testing:**
- Test custom URL scheme
- Test universal links
- Test with various token formats
- Test error handling for invalid links

**Files to create/modify:**
- `Sources/VortexSDK/Services/DeepLinkHandler.swift`
- Update demo app to handle URL schemes

---

### 18. Offline Support
**Complexity:** High | **Estimated Effort:** 2 sessions

Queue invitations when offline and send when connection restored.

**Requirements:**
- Detect network connectivity changes
- Store pending invitations locally
- Show offline banner/indicator
- Retry failed invitations automatically
- Show sync status in UI

**Testing:**
- Test with Airplane Mode
- Test with poor network conditions
- Test queue persistence across app restarts
- Test conflict resolution

**Files to create/modify:**
- `Sources/VortexSDK/Services/NetworkMonitor.swift`
- `Sources/VortexSDK/Services/InvitationQueue.swift`
- Add Core Data or SQLite for persistence

---

### 19. Rate Limiting and Retry Logic
**Complexity:** Medium | **Estimated Effort:** 1 session

Handle API rate limits and implement exponential backoff.

**Requirements:**
- Detect 429 Too Many Requests responses
- Implement exponential backoff with jitter
- Show user-friendly rate limit messages
- Queue requests during rate limit period
- Respect Retry-After header

**Testing:**
- Test with rate-limited API responses
- Test retry behavior with various delays
- Test user messaging

**Files to modify:**
- Update `VortexClient.swift` with retry logic
- Add rate limit error type to `VortexError`

---

### 20. Unit Test Coverage
**Complexity:** Medium | **Estimated Effort:** 2 sessions

Achieve >80% unit test coverage for SDK code.

**Requirements:**
- Unit tests for all models (Codable conformance)
- Unit tests for VortexClient API methods
- Unit tests for validation logic
- Unit tests for utility functions
- Mock network responses for testing
- CI integration (GitHub Actions)

**Testing:**
- Run tests in CI pipeline
- Generate code coverage reports
- Set coverage threshold gates

**Files to create:**
- `Tests/VortexSDKTests/Models/*Tests.swift`
- `Tests/VortexSDKTests/API/VortexClientTests.swift`
- `Tests/VortexSDKTests/Validation/*Tests.swift`
- `.github/workflows/test.yml`

---

### 21. UI Testing Suite
**Complexity:** High | **Estimated Effort:** 2 sessions

Create UI tests for critical user flows.

**Requirements:**
- Test invitation creation flow end-to-end
- Test contact import flow
- Test share link flow
- Test error states
- Test accessibility features
- Record test videos for regression detection

**Testing:**
- Run UI tests on multiple simulators
- Include in CI pipeline
- Visual regression testing

**Files to create:**
- `Tests/VortexSDKUITests/InvitationFlowTests.swift`
- `Tests/VortexSDKUITests/ContactImportTests.swift`
- `Tests/VortexSDKUITests/ShareFlowTests.swift`

---

### 22. Documentation and Code Examples
**Complexity:** Low | **Estimated Effort:** 1 session

Expand documentation with detailed examples.

**Requirements:**
- Add DocC documentation comments to all public APIs
- Create DocC tutorials for common use cases
- Add code examples to README
- Create troubleshooting guide
- Document architecture decisions

**Testing:**
- Build DocC documentation: `swift package generate-documentation`
- Verify examples compile

**Files to create/modify:**
- Add `///` comments to all public APIs
- Create `Sources/VortexSDK/VortexSDK.docc/` directory
- Add tutorials and articles

---

## 📦 Package Publishing Checklist

When ready to publish v1.0.0:

- [ ] All high-priority features implemented
- [ ] Unit tests passing with >80% coverage
- [ ] UI tests passing for critical flows
- [ ] Documentation complete with examples
- [ ] README updated with installation instructions
- [ ] CHANGELOG.md created
- [ ] Semantic versioning adopted
- [ ] GitHub releases configured
- [ ] CI/CD pipeline set up
- [ ] Swift Package Index submission
- [ ] CocoaPods podspec (optional)

---

## Priority Matrix

| Priority | Feature Count | Est. Sessions |
|----------|--------------|---------------|
| 🔴 High  | 4 features   | 5-7 sessions  |
| 🟡 Medium| 5 features   | 5-7 sessions  |
| 🟢 Low   | 13 features  | 11-15 sessions|
| **Total**| **22 features** | **21-29 sessions** |

---

## Session Implementation Order (Recommended)

1. **Dynamic Form Rendering Engine** (blocking all form features)
2. **Theme and Styling System** (visual quality)
3. **Role Selection Component** (common use case)
4. **iOS Contacts Access** (high user value)
5. **Share Sheet Integration** (native feel)
6. **Bulk Email Invitations** (power user feature)
7. **QR Code Generation** (nice to have)
8. **Configuration Caching** (performance)
9. **Clipboard Copy with Feedback** (UX polish)
10. **Google Contacts Integration** (advanced feature)
11. _(Continue with remaining low-priority items as needed)_

---

## Notes

- Each feature is designed to be **independently testable and shippable**
- Features can be implemented in any order (except where dependencies noted)
- MVP (v1.0.0) is functional but intentionally minimal
- Future versions can incrementally add features from this list
- Prioritize based on customer feedback and usage analytics

---

Last Updated: 2025-12-16
