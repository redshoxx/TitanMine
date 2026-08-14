import SwiftUI

struct BottomGameBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 5) {
            ForEach(MainTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.48))
    }

    @ViewBuilder
    private func tabButton(for tab: MainTab) -> some View {
        let isSelected = store.selectedTab == tab
        let currentBadge = badge(for: tab)
        let iconColor = tabColor(tab)
        let background = selectedFill(tab, isSelected: isSelected)
        let borderColor: Color = isSelected ? GameTheme.gold : Color.white.opacity(0.24)
        let borderWidth: CGFloat = isSelected ? 2.2 : 1.0

        Button {
            store.selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 23, weight: .black))
                        .foregroundColor(iconColor)
                        .frame(height: 27)

                    if currentBadge > 0 {
                        Text(String(currentBadge))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(GameTheme.red, in: Circle())
                            .offset(x: 9, y: -6)
                    }
                }

                Text(tab.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(background)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: borderWidth)
                    }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func badge(for tab: MainTab) -> Int {
        switch tab {
        case .tnt:
            return min(store.state.tntCount, 99)
        case .chests:
            return min(store.state.chestCount, 99)
        default:
            return 0
        }
    }

    private func tabColor(_ tab: MainTab) -> Color {
        switch tab {
        case .mine:
            return .white
        case .upgrades:
            return GameTheme.lime
        case .tnt:
            return GameTheme.orange
        case .research:
            return GameTheme.purple
        case .chests:
            return GameTheme.gold
        case .forge:
            return .gray
        }
    }

    private func selectedFill(_ tab: MainTab, isSelected: Bool) -> LinearGradient {
        let colors: [Color]
        if isSelected && tab == .mine {
            colors = [GameTheme.gold, GameTheme.orange]
        } else {
            colors = [GameTheme.panel2, GameTheme.panel]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
