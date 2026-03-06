import Foundation

// MARK: - Contact Source

/// Represents the source of a Google contact
public enum ContactSource: Sendable {
    case contacts
    case workspace
    case calendar
}

// MARK: - Contact Model

/// Represents a contact with email for invitation
public struct VortexContact: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let email: String
    public let source: ContactSource
    public let imageUrl: String?
    
    public init(id: String, name: String, email: String, source: ContactSource = .contacts, imageUrl: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.source = source
        self.imageUrl = imageUrl
    }
    
    /// Initials derived from the contact's name (up to 2 characters)
    public var initials: String {
        name.split(separator: " ")
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
            .prefix(2)
            .description
    }
}

// MARK: - Contacts Errors

/// Errors that can occur when accessing device contacts
public enum ContactsError: LocalizedError, Sendable {
    case accessDenied
    case fetchFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Contacts access was denied. Please enable Contacts access in your device Settings to import contacts."
        case .fetchFailed(let error):
            return "Failed to fetch contacts: \(error.localizedDescription)"
        }
    }
}

/// Errors that can occur when accessing Google Contacts
public enum GoogleContactsError: LocalizedError, Sendable {
    case missingClientId
    case signInUnavailable
    case signInCancelled
    case signInFailed(Error)
    case noAccessToken
    case noPresentingViewController
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case fetchFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "Google iOS Client ID not configured. Please provide googleIosClientId parameter."
        case .signInUnavailable:
            return "Google Sign-In is not available. Please ensure GoogleSignIn SDK is properly configured."
        case .signInCancelled:
            return "Google Sign-In was cancelled."
        case .signInFailed(let error):
            return "Google Sign-In failed: \(error.localizedDescription)"
        case .noAccessToken:
            return "Failed to get access token from Google Sign-In."
        case .noPresentingViewController:
            return "Unable to present Google Sign-In. No view controller available."
        case .invalidURL:
            return "Invalid Google People API URL."
        case .invalidResponse:
            return "Invalid response from Google People API."
        case .apiError(let statusCode):
            return "Google People API error: HTTP \(statusCode)"
        case .fetchFailed(let error):
            return "Failed to fetch Google contacts: \(error.localizedDescription)"
        }
    }
}
