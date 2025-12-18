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
