import SwiftUI

// MARK: - View Extensions

// MARK: - Helper Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - AttributeValue Extension

extension AttributeValue {
    /// Get the string value if this is a string attribute
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .bool(let value):
            return String(value)
        }
    }
}

// MARK: - Color Extension for Hex Parsing

extension Color {
    /// Initialize a Color from a hex string (e.g., "#6291d5" or "6291d5")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let length = hexSanitized.count
        
        switch length {
        case 6: // RGB (e.g., "6291d5")
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8: // RGBA (e.g., "6291d5ff")
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }
}

// MARK: - Gradient Parsing

/// Represents a parsed gradient color stop
struct GradientColorStop {
    let color: Color
    let location: CGFloat
}

/// Represents a parsed linear gradient
struct ParsedGradient {
    let angle: Double
    let colorStops: [GradientColorStop]
    
    /// Convert to SwiftUI LinearGradient
    func toLinearGradient() -> LinearGradient {
        let stops = colorStops.map { Gradient.Stop(color: $0.color, location: $0.location) }
        let gradient = Gradient(stops: stops)
        
        // Convert CSS angle to SwiftUI UnitPoint
        // CSS: 0deg = bottom to top, 90deg = left to right
        // SwiftUI: we need to calculate start and end points
        let (startPoint, endPoint) = angleToUnitPoints(angle)
        
        return LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint)
    }
    
    /// Convert CSS angle (in degrees) to SwiftUI UnitPoints
    private func angleToUnitPoints(_ degrees: Double) -> (UnitPoint, UnitPoint) {
        // CSS angles: 0deg = to top, 90deg = to right, 180deg = to bottom, 270deg = to left
        // Convert to radians and calculate direction
        let radians = (degrees - 90) * .pi / 180
        
        let x = cos(radians)
        let y = sin(radians)
        
        // Normalize to unit points (0 to 1 range)
        let startX = 0.5 - x * 0.5
        let startY = 0.5 + y * 0.5
        let endX = 0.5 + x * 0.5
        let endY = 0.5 - y * 0.5
        
        return (UnitPoint(x: startX, y: startY), UnitPoint(x: endX, y: endY))
    }
}

/// Parses a CSS linear-gradient string into a ParsedGradient
/// Example: "linear-gradient(90deg, #6291d5 0%, #bf8ae0 100%)"
func parseLinearGradient(_ cssGradient: String) -> ParsedGradient? {
    // Check if it's a linear-gradient
    guard cssGradient.hasPrefix("linear-gradient(") && cssGradient.hasSuffix(")") else {
        return nil
    }
    
    // Extract content inside parentheses
    let startIndex = cssGradient.index(cssGradient.startIndex, offsetBy: 16) // "linear-gradient(".count
    let endIndex = cssGradient.index(cssGradient.endIndex, offsetBy: -1)
    let content = String(cssGradient[startIndex..<endIndex])
    
    // Split by comma, but be careful with spaces
    let parts = content.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    
    guard parts.count >= 2 else {
        return nil
    }
    
    // Parse angle (first part should be like "90deg")
    var angle: Double = 180 // Default: top to bottom
    var colorStartIndex = 0
    
    if let firstPart = parts.first, firstPart.hasSuffix("deg") {
        let degString = firstPart.replacingOccurrences(of: "deg", with: "")
        if let parsedAngle = Double(degString) {
            angle = parsedAngle
            colorStartIndex = 1
        }
    }
    
    // Parse color stops
    var colorStops: [GradientColorStop] = []
    
    for i in colorStartIndex..<parts.count {
        let part = parts[i]
        // Part format: "#6291d5 0%" or "#bf8ae0 100%"
        let components = part.components(separatedBy: " ").filter { !$0.isEmpty }
        
        guard components.count >= 1 else { continue }
        
        let colorString = components[0]
        var location: CGFloat = CGFloat(i - colorStartIndex) / CGFloat(max(1, parts.count - colorStartIndex - 1))
        
        // Parse percentage if present
        if components.count >= 2 {
            let percentString = components[1].replacingOccurrences(of: "%", with: "")
            if let percent = Double(percentString) {
                location = CGFloat(percent / 100.0)
            }
        }
        
        // Parse color
        if let color = Color(hex: colorString) {
            colorStops.append(GradientColorStop(color: color, location: location))
        }
    }
    
    guard colorStops.count >= 2 else {
        return nil
    }
    
    return ParsedGradient(angle: angle, colorStops: colorStops)
}

/// Represents either a solid color or a gradient background
enum BackgroundStyle {
    case solid(Color)
    case gradient(LinearGradient)
    
    /// Parse a CSS background value (either solid color or gradient)
    static func parse(_ value: String) -> BackgroundStyle? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // Check if it's a gradient
        if trimmed.hasPrefix("linear-gradient(") {
            if let parsed = parseLinearGradient(trimmed) {
                return .gradient(parsed.toLinearGradient())
            }
            return nil
        }
        
        // Try to parse as solid color
        if let color = Color(hex: trimmed) {
            return .solid(color)
        }
        
        return nil
    }
}

// MARK: - View Extension for Background Style

extension View {
    /// Apply a BackgroundStyle (solid color or gradient) to the view
    @ViewBuilder
    func backgroundStyle(_ style: BackgroundStyle?) -> some View {
        if let style = style {
            switch style {
            case .solid(let color):
                self.background(color)
            case .gradient(let gradient):
                self.background(gradient)
            }
        } else {
            self
        }
    }
}

// MARK: - Theme Extension for Button Background

extension Theme {
    /// Get the button background style from theme options
    var buttonBackgroundStyle: BackgroundStyle? {
        guard let options = options else { return nil }
        
        // Look for --vrtx-icon-button-background in theme options
        for option in options {
            if option.key == "--vrtx-icon-button-background" && !option.value.isEmpty {
                return BackgroundStyle.parse(option.value)
            }
        }
        
        return nil
    }
    
    /// Get the button text color from theme options
    var buttonTextColor: Color? {
        guard let options = options else { return nil }
        
        for option in options {
            if option.key == "--vrtx-icon-button-color" && !option.value.isEmpty {
                return Color(hex: option.value)
            }
        }
        
        return nil
    }
}
