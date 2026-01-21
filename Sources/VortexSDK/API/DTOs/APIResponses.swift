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
    public let groupId: String?
    public let metadata: [String: AnyCodable]?
}

/// Response from fingerprint matching endpoint
public struct MatchFingerprintResponse: Codable, Sendable {
    public let matched: Bool
    public let confidence: Double?
    public let context: DeferredLinkContext?
    public let error: String?
}

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
