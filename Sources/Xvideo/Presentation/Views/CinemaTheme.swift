import SwiftUI

enum CinemaTheme {
    static let appBackground = Color(red: 0.025, green: 0.026, blue: 0.032)
    static let sidebarBackground = Color(red: 0.04, green: 0.042, blue: 0.052)
    static let panelBackground = Color(red: 0.075, green: 0.076, blue: 0.088)
    static let elevatedBackground = Color(red: 0.112, green: 0.112, blue: 0.128)
    static let softBackground = Color(red: 0.16, green: 0.158, blue: 0.172)
    static let accent = Color(red: 0.86, green: 0.035, blue: 0.075)
    static let accentHot = Color(red: 1.0, green: 0.21, blue: 0.18)
    static let gold = Color(red: 0.95, green: 0.66, blue: 0.24)
    static let blue = Color(red: 0.26, green: 0.48, blue: 0.96)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.64)
    static let textTertiary = Color.white.opacity(0.42)
    static let separator = Color.white.opacity(0.095)

    static let redGradient = LinearGradient(
        colors: [accentHot, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassGradient = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.035)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    func cinemaPanel(cornerRadius: CGFloat = 8) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(CinemaTheme.elevatedBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(CinemaTheme.separator, lineWidth: 1)
                }
        )
    }
}
