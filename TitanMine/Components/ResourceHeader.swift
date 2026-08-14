import SwiftUI

struct ResourceHeader: View {
    @EnvironmentObject var store: GameStore
    var showGear: Bool = true
    var onGear: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 7) {
            if showGear {
                Button {
                    onGear?()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(colors: [GameTheme.gold, GameTheme.orange], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(.black.opacity(0.65), lineWidth: 2))
                }
                .buttonStyle(PressScaleButtonStyle())
            }

            currency(icon: "circle.fill", value: store.state.coins.compactGameNumber, color: GameTheme.gold)
            currency(icon: "diamond.fill", value: store.state.blueCrystals.compactGameNumber, color: GameTheme.cyan)
            currency(icon: "diamond.fill", value: store.state.greenGems.compactGameNumber, color: GameTheme.lime)
            currency(icon: "diamond.fill", value: store.state.purpleShards.compactGameNumber, color: GameTheme.purple)
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    private func currency(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.8), radius: 3)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Image(systemName: "plus.square.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(GameTheme.lime)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.72), lineWidth: 1.5))
        )
    }
}
