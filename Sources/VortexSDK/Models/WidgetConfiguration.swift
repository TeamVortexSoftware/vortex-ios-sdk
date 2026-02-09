import Foundation

// MARK: - Widget Configuration

/// Root configuration object returned from the Vortex API
public struct WidgetConfiguration: Codable, Sendable {
    public let id: String
    public let name: String?
    public let slug: String?
    public let version: String?
    public let configuration: WidgetConfigurationConfiguration
    public let createdAt: String?
    public let updatedAt: String?
    public let createdBy: String?
    public let status: String?
    
    // Optional fields that may or may not be present
    public let projectId: String?
    public let widgetId: String?
    public let deploymentId: String?
    public let widgetType: String?
}

/// Configuration container with metadata and props
public struct WidgetConfigurationConfiguration: Codable, Sendable {
    public let meta: WidgetConfigurationMeta
    public let props: [String: ConfigurationProperty]
    /// Localized strings for SDK-side UI text translation.
    /// Contains English-key → translated-value pairs for the requested locale.
    /// Used for hardcoded UI strings that can't be translated server-side via the element tree.
    /// Only present when a non-default locale is requested and translations exist.
    public let localizedStrings: [String: String]?
}

/// Metadata about the widget configuration
public struct WidgetConfigurationMeta: Codable, Sendable {
    public let configuration: ConfigurationInfo
    
    public struct ConfigurationInfo: Codable, Sendable {
        public let version: String
        public let componentType: String?
        public let businessType: String?
    }
}

/// A configuration property with value and type information
public struct ConfigurationProperty: Codable, Sendable {
    public let value: ConfigurationValue
    public let valueType: String
    
    enum CodingKeys: String, CodingKey {
        case value
        case valueType
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.valueType = try container.decode(String.self, forKey: .valueType)
        // Decode value from the "value" key using superDecoder
        self.value = try container.decode(ConfigurationValue.self, forKey: .value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(valueType, forKey: .valueType)
        try container.encode(value, forKey: .value)
    }
}

/// Dynamic value that can be string, number, bool, array, or complex object
public enum ConfigurationValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([ConfigurationValue])
    case object([String: ConfigurationValue])
    case pageData(PageData)
    case theme(Theme)
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([ConfigurationValue].self) {
            self = .array(array)
        } else if let pageData = try? container.decode(PageData.self) {
            self = .pageData(pageData)
        } else if let theme = try? container.decode(Theme.self) {
            self = .theme(theme)
        } else if let object = try? container.decode([String: ConfigurationValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode ConfigurationValue"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .pageData(let value): try container.encode(value)
        case .theme(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Page Data & Element Nodes

/// Page structure containing a root element node
public struct PageData: Codable, Sendable {
    public let root: ElementNode
}

/// Hierarchical UI element node (similar to React Native's configuration)
public struct ElementNode: Codable, Sendable {
    public let id: String
    public let schemaVersion: Int?
    public let type: String
    public let subtype: String?
    public let tagName: String?
    public let textContent: String?
    public let iconKey: String?
    public let attributes: [String: AttributeValue]?
    public let style: [String: String]?
    public let theme: Theme?
    public let settings: ElementSettings?
    public let children: [ElementNode]?
    public let hidden: Bool?
    public let vortex: VortexMetadata?
    public let meta: ElementMeta?
}

/// Metadata for element nodes (source group info, etc.)
public struct ElementMeta: Codable, Sendable {
    public let source: ElementSource?
}

/// Source information for element nodes
public struct ElementSource: Codable, Sendable {
    public let group: ElementGroup?
}

/// Group information for element nodes
public struct ElementGroup: Codable, Sendable {
    public let name: String?
}

/// Element settings (size, layout, actions, etc.)
public struct ElementSettings: Codable, Sendable {
    public let direction: String?
    public let divider: String?
    public let action: NodeAction?
    public let size: SizeConfig?
    public let layout: [SizeConfig]?
    public let options: [ElementOption]?
    public let overrideTagName: String?
    public let customizations: [String: ButtonCustomization]?
}

/// Customization options for buttons (supports custom labels from widget configuration)
public struct ButtonCustomization: Codable, Sendable {
    public let textContent: String?
}

/// Size configuration for responsive layouts
public struct SizeConfig: Codable, Sendable {
    public let xs: Int?
    public let sm: Int?
    public let md: Int?
    public let lg: Int?
    public let xl: Int?
}

/// Action configuration for interactive elements
public struct NodeAction: Codable, Sendable {
    public let type: String
    public let target: String?
    public let value: String?
}

/// Option for select/radio/checkbox elements
public struct ElementOption: Codable, Sendable {
    public let id: String
    public let label: String?
    public let value: String?
    public let action: NodeAction?
    public let textContent: String?
    public let iconKey: String?
}

/// Vortex-specific metadata for special components
public struct VortexMetadata: Codable, Sendable {
    public let role: String?
}

/// Dynamic attribute value (can be string, bool, or array of strings)
public enum AttributeValue: Codable, Sendable {
    case string(String)
    case bool(Bool)
    case stringArray([String])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([String].self) {
            self = .stringArray(array)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AttributeValue"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .stringArray(let value): try container.encode(value)
        }
    }
}

// MARK: - Theme

/// Theme configuration for styling
public struct Theme: Codable, Sendable {
    public let name: String?
    public let colors: ThemeColors?
    public let options: [ThemeOption]?
}

/// Color palette for theme
public struct ThemeColors: Codable, Sendable {
    public let primary: String?
    public let secondary: String?
    public let background: String?
    public let surface: String?
    public let error: String?
    public let onPrimary: String?
    public let onSecondary: String?
    public let onBackground: String?
    public let onSurface: String?
    public let onError: String?
}

/// Theme option/variant
public struct ThemeOption: Codable, Sendable {
    public let key: String
    public let value: String
}
