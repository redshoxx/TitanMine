import SwiftUI

enum GameTheme {
    static let navy = Color(red: 0.02, green: 0.10, blue: 0.18)
    static let deepBlue = Color(red: 0.01, green: 0.22, blue: 0.42)
    static let panel = Color(red: 0.04, green: 0.12, blue: 0.20)
    static let panel2 = Color(red: 0.06, green: 0.18, blue: 0.29)
    static let gold = Color(red: 1.00, green: 0.68, blue: 0.05)
    static let orange = Color(red: 1.00, green: 0.38, blue: 0.03)
    static let lime = Color(red: 0.35, green: 0.92, blue: 0.08)
    static let cyan = Color(red: 0.05, green: 0.72, blue: 1.00)
    static let purple = Color(red: 0.67, green: 0.22, blue: 1.00)
    static let red = Color(red: 0.92, green: 0.08, blue: 0.08)

    static let background = LinearGradient(
        colors: [Color(red: 0.01, green: 0.35, blue: 0.62), navy, Color.black],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct GamePanelModifier: ViewModifier {
    var accent: Color = GameTheme.gold

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GameTheme.panel.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(accent.opacity(0.75), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.42), radius: 4, y: 3)
            )
    }
}

extension View {
    func gamePanel(accent: Color = GameTheme.gold) -> some View {
        modifier(GamePanelModifier(accent: accent))
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
