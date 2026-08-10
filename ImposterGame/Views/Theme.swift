import SwiftUI

/// A soft accent-tinted backdrop used behind the full-screen game views.
/// Adapts to light and dark automatically via `Color(.systemBackground)`.
struct GameBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.22),
                    Color.accentColor.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

/// Consistent "card" container — a rounded material panel with padding.
struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    /// A primary full-width action button look, applied to a `Button`.
    func primaryAction() -> some View {
        self.buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
}
