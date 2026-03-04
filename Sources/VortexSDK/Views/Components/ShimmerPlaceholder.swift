import SwiftUI

/// A shimmer/skeleton loading effect modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.4),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                    ) {
                        phase = 300
                    }
                }
            )
            .clipped()
    }
}

/// A single shimmer row that mimics a contact list item (avatar + two text lines)
struct ShimmerContactRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 40, height: 40)
                .modifier(ShimmerModifier())

            VStack(alignment: .leading, spacing: 6) {
                // Name placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 12)
                    .modifier(ShimmerModifier())

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 80, height: 10)
                    .modifier(ShimmerModifier())
            }

            Spacer()

            // Button placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 28)
                .modifier(ShimmerModifier())
        }
        .padding(.vertical, 8)
    }
}

/// A placeholder view showing multiple shimmer rows for loading state
struct ShimmerPlaceholderList: View {
    var rowCount: Int = 3

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { _ in
                ShimmerContactRow()
            }
        }
    }
}
