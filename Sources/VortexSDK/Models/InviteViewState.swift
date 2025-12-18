import Foundation

/// Represents the current view state of the invitation form
public enum InviteViewState: Sendable {
    /// Main invitation form view
    case main
    /// Email entry view for adding email addresses
    case emailEntry
    /// Native iOS contacts picker view
    case contactsPicker
    /// Google contacts picker view
    case googleContactsPicker
    /// QR code display view
    case qrCode
}
