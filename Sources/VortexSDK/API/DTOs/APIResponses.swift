import Foundation

// MARK: - Widget Configuration Response

/// Response from widget configuration endpoint
public struct WidgetConfigurationResponse: Codable, Sendable {
    public let data: WidgetConfigurationData
}

/// Data wrapper containing widget configuration and metadata
public struct WidgetConfigurationData: Codable, Sendable {
    public let widgetConfiguration: WidgetConfiguration
    public let deploymentId: String?
    public let widgetType: String?
    public let environmentRole: String?
    public let environmentName: String?
    public let renderer: RendererInfo?
    public let sessionAttestation: String?
}

/// Renderer information
public struct RendererInfo: Codable, Sendable {
    public let url: String?
}

// MARK: - Create Invitation Response

/// Response from create invitation endpoint
public struct CreateInvitationResponse: Codable, Sendable {
    public let data: CreateInvitationData
}

/// Data wrapper for create invitation response
public struct CreateInvitationData: Codable, Sendable {
    public let invitationEntries: [InvitationEntry]?
}

/// Individual invitation entry in the response
public struct InvitationEntry: Codable, Sendable {
    public let id: String?
    public let status: String?
}

// MARK: - Shareable Link Response

/// Response from shareable link endpoint (matches ShareableLinkResponseDto from RN SDK)
public struct ShareableLinkResponse: Codable, Sendable {
    public let data: ShareableLinkData
}

/// Data wrapper for shareable link response
public struct ShareableLinkData: Codable, Sendable {
    public let invitation: ShareableLinkInvitation
}

/// Invitation details in shareable link response
public struct ShareableLinkInvitation: Codable, Sendable {
    public let id: String
    public let shortLink: String
    public let source: String?
    public let attributes: [String: String]?
}

// MARK: - Group DTO

/// Group information for invitations
public struct GroupDTO: Codable, Sendable {
    public let id: String?
    public let groupId: String?
    public let type: String
    public let name: String
    
    public init(id: String?, groupId: String?, type: String, name: String) {
        self.id = id
        self.groupId = groupId
        self.type = type
        self.name = name
    }
}
