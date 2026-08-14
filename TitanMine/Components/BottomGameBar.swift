import SwiftUI

struct BottomGameBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 5) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    store.selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 23, weight: .black))
                                .foregroundStyle(tabColor(tab))
                                .frame(height: 27)

                            if badge(for: tab) > 0 {
                                Text("\(badge(for: tab))")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Circle().fill(GameTheme.red))
                                    .offset(x: 9, y: -6)
                            }
                        }

                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(store.selectedTab == tab ? selectedFill(tab) : GameTheme.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(store.selectedTab == tab ? GameTheme.gold : Color.white.opacity(0.24), lineWidth: store.selectedTab == tab ? 2.2 : 1)
                            )
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.48))
    }

    private func badge(for tab: MainTab) -> Int {
        switch tab {
        case .tnt: return min(store.state.tntCount, 99)
        case .chests: return min(store.state.chestCount, 99)
        default: return 0
        }
    }

    private func tabColor(_ tab: MainTab) -> Color {
        switch tab {
        case .mine: return .white
        case .upgrades: return GameTheme.lime
        case .tnt: return GameTheme.orange
        case .research: return GameTheme.purple
        case .chests: return GameTheme.gold
        case .forge: return .gray
        }
    }

    private func selectedFill(_ tab: MainTab) -> LinearGradient {
        LinearGradient(
            colors: tab == .mine ? [GameTheme.gold, GameTheme.orange] : [GameTheme.panel2, GameTheme.panel],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
