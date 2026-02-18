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
    public let shortLink: String?
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

// MARK: - Deferred Deep Link (Fingerprint Matching)

/// Device fingerprint data for deferred deep link matching
public struct DeviceFingerprint: Codable, Sendable {
    public let platform: String?
    public let osVersion: String?
    public let deviceModel: String?
    public let deviceBrand: String?
    public let timezone: String?
    public let language: String?
    public let screenWidth: Int?
    public let screenHeight: Int?
    public let carrierName: String?
    public let totalMemory: Int?
    
    public init(
        platform: String? = nil,
        osVersion: String? = nil,
        deviceModel: String? = nil,
        deviceBrand: String? = nil,
        timezone: String? = nil,
        language: String? = nil,
        screenWidth: Int? = nil,
        screenHeight: Int? = nil,
        carrierName: String? = nil,
        totalMemory: Int? = nil
    ) {
        self.platform = platform
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.deviceBrand = deviceBrand
        self.timezone = timezone
        self.language = language
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.carrierName = carrierName
        self.totalMemory = totalMemory
    }
}

/// Request body for fingerprint matching endpoint
public struct MatchFingerprintRequest: Codable, Sendable {
    public let fingerprint: DeviceFingerprint
    
    public init(fingerprint: DeviceFingerprint) {
        self.fingerprint = fingerprint
    }
}

/// Invitation context returned when a fingerprint match is found
public struct DeferredLinkContext: Codable, Sendable {
    public let invitationId: String
    public let inviterId: String?
    public let metadata: [String: AnyCodable]?
    
    /// Scope identifier from the invitation (e.g., team ID, project ID)
    public var scope: String? { groupId }
    
    /// Type of the scope (e.g., "team", "project")
    public var scopeType: String? { groupType }
    
    // Internal: maps from API's "groupId" and "groupType" fields
    private let groupId: String?
    private let groupType: String?
    
    private enum CodingKeys: String, CodingKey {
        case invitationId, inviterId, groupId, groupType, metadata
    }
}

/// Response from fingerprint matching endpoint
public struct MatchFingerprintResponse: Codable, Sendable {
    public let matched: Bool
    public let confidence: Double?
    public let context: DeferredLinkContext?
    public let error: String?
}

// MARK: - Outgoing Invitations

/// Response from GET /api/v1/invitations endpoint
public struct OutgoingInvitationsResponse: Codable, Sendable {
    public let data: OutgoingInvitationsData
}

/// Data wrapper for outgoing invitations response
public struct OutgoingInvitationsData: Codable, Sendable {
    public let invitations: [OutgoingInvitation]
}

/// Target of an invitation (e.g., email or SMS recipient)
///
/// Handles both field-name formats returned by the API:
/// - Full detail endpoint: `type`, `value`, `name`, `avatarUrl`
/// - List endpoints: `targetType`, `targetValue`, `targetName`, `targetAvatarUrl`
public struct InvitationTarget: Codable, Sendable {
    public let targetType: String
    public let targetValue: String
    public let targetName: String?
    public let targetAvatarUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case targetType, targetValue, targetName, targetAvatarUrl
        // Alternative keys used by the full detail endpoint
        case type, value, name, avatarUrl
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.targetType = try (try? container.decode(String.self, forKey: .targetType))
            ?? container.decode(String.self, forKey: .type)
        self.targetValue = try (try? container.decode(String.self, forKey: .targetValue))
            ?? container.decode(String.self, forKey: .value)
        self.targetName = (try? container.decodeIfPresent(String.self, forKey: .targetName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .name))
        self.targetAvatarUrl = (try? container.decodeIfPresent(String.self, forKey: .targetAvatarUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .avatarUrl))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetType, forKey: .targetType)
        try container.encode(targetValue, forKey: .targetValue)
        try container.encodeIfPresent(targetName, forKey: .targetName)
        try container.encodeIfPresent(targetAvatarUrl, forKey: .targetAvatarUrl)
    }
}

/// Individual outgoing invitation from the API
public struct OutgoingInvitation: Codable, Sendable {
    public let id: String
    public let targets: [InvitationTarget]?
    public let senderIdentifier: String?
    public let senderIdentifierType: String?
    public let avatarUrl: String?
    public let status: String?
    public let createdAt: String?
    public let metadata: [String: AnyCodable]?
}

// MARK: - Incoming Invitations

/// Response from GET /api/v1/invitations endpoint (open/incoming invitations)
public struct IncomingInvitationsResponse: Codable, Sendable {
    public let data: IncomingInvitationsData
}

/// Data wrapper for incoming invitations response
public struct IncomingInvitationsData: Codable, Sendable {
    public let invitations: [IncomingInvitation]
    public let nextCursor: String?
    public let hasMore: Bool?
    public let count: Int?
}

/// Individual incoming invitation from the API
public struct IncomingInvitation: Codable, Sendable {
    public let id: String
    public let targets: [InvitationTarget]?
    public let senderIdentifier: String?
    public let senderIdentifierType: String?
    public let avatarUrl: String?
    public let status: String?
    public let createdAt: String?
    public let source: String?
    public let deliveryType: String?
    // Creator fields (the person who sent the invitation)
    public let creatorName: String?
    public let creatorAvatarUrl: String?
    public let creatorId: String?
    public let metadata: [String: AnyCodable]?
}

// MARK: - Invitation (full detail)

/// Group associated with an invitation
public struct InvitationGroup: Codable, Sendable {
    public let id: String
    public let groupId: String
    public let type: String
    public let name: String?
}

/// Acceptance record for an invitation
public struct InvitationAcceptance: Codable, Sendable {
    public let id: String
    public let accountId: String
    public let projectId: String
    public let acceptedAt: String
    public let targetType: String
    public let targetValue: String
    public let identifiers: [String: AnyCodable]?
}

/// A full invitation as returned by the Vortex API (GET /api/v1/invitations/:id)
public struct Invitation: Codable, Sendable {
    public let id: String
    public let accountId: String?
    public let projectId: String?
    public let deploymentId: String?
    public let widgetConfigurationId: String?
    public let status: String?
    public let invitationType: String?
    public let deliveryTypes: [String]?
    public let source: String?
    public let subtype: String?
    public let foreignCreatorId: String?
    public let creatorName: String?
    public let creatorAvatarUrl: String?
    public let createdAt: String?
    public let modifiedAt: String?
    public let deactivated: Bool?
    public let deliveryCount: Int?
    public let views: Int?
    public let clickThroughs: Int?
    public let configurationAttributes: [String: AnyCodable]?
    public let attributes: [String: AnyCodable]?
    public let metadata: [String: AnyCodable]?
    public let passThrough: String?
    public let target: [InvitationTarget]?
    public let groups: [InvitationGroup]?
    public let accepts: [InvitationAcceptance]?
    public let scope: String?
    public let scopeType: String?
    public let expired: Bool?
    public let expires: String?
}

// MARK: - AnyCodable

/// Type-erased Codable wrapper for handling dynamic JSON values
public struct AnyCodable: Codable, Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unable to encode value"))
        }
    }
}
