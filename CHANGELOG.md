# Changelog

All notable changes to the Vortex iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-18

### Added
- Initial release of Vortex iOS SDK
- `VortexInviteView` - SwiftUI component for rendering invitation forms
- `VortexClient` - API client for Vortex backend communication
- Dynamic form rendering based on server configuration
- Email invitation support with validation
- Shareable link generation and clipboard copy
- Native iOS share sheet integration
- SMS sharing support
- QR code generation for invitation links
- LINE messaging integration
- iOS Contacts import
- Google Contacts integration (via GoogleSignIn SDK)
- Group/team context support for scoped invitations
- JWT authentication
- Comprehensive error handling with `VortexError` types
- Loading states and success feedback
- iOS 15.0+ support
