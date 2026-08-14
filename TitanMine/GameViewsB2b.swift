import SwiftUI
import UIKit

struct ForgeView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 68, weight: .black))
                        .foregroundStyle(GameTheme.gold)
                        .shadow(color: GameTheme.orange.opacity(0.8), radius: 14)
                    Text("TITAN FORGE")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text("Forge Tier \(store.state.forgeTier)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.purple)
                }
                .padding(.top, 12)

                recipeCard

                VStack(alignment: .leading, spacing: 10) {
                    Text("FORGE BONUS")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.gold)
                    row("Tap-Level", "+2")
                    row("Auto-Mining-Level", "+2")
                    row("Forge Tier", "+1")
                    row("Nächster Craft", "teurer, aber stärker")
                }
                .padding(14)
                .gamePanel(accent: GameTheme.orange)

                Text("Die Forge nutzt ausschließlich erspielte Ressourcen. Es gibt in dieser Build-Version keine Echtgeldkäufe.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(12)
        }
    }

    private var recipeCard: some View {
        let cost = store.forgeCost
        let canCraft = store.state.blueCrystals >= cost.blue && store.state.greenGems >= cost.green && store.state.purpleShards >= cost.purple

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TITANIUM PICKAXE")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.gold)
                    Text("LEGENDARY UPGRADE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.purple)
                }
                Spacer()
                Image(systemName: "hammer.fill")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(GameTheme.cyan)
            }

            HStack(spacing: 8) {
                material("Blue", store.state.blueCrystals, cost.blue, GameTheme.cyan)
                material("Green", store.state.greenGems, cost.green, GameTheme.lime)
                material("Purple", store.state.purpleShards, cost.purple, GameTheme.purple)
            }

            Button {
                if store.forgeUpgrade() {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            } label: {
                Text(canCraft ? "CRAFT" : "MATERIAL FEHLT")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 13).fill(canCraft ? GameTheme.lime : Color.gray.opacity(0.55)))
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(14)
        .gamePanel(accent: GameTheme.gold)
    }

    private func material(_ title: String, _ have: Int, _ need: Int, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "diamond.fill")
                .foregroundStyle(color)
            Text("\(have.compactGameNumber)/\(need.compactGameNumber)")
                .font(.system(size: 10, weight: .black, design: .rounded))
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.lime)
        }
    }
}
import SwiftUI
import UIKit

struct UpgradeView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                titleCard

                ForEach(UpgradeType.allCases) { type in
                    upgradeRow(type)
                }

                statsCard
            }
            .padding(10)
        }
        .overlay(alignment: .top) {
            if let message {
                Text(message)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.86)))
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var titleCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [GameTheme.cyan, GameTheme.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "hammer.fill")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 4) {
                Text("CRYSTAL PICKAXE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.gold)
                Text("LEGENDARY • TIER \(store.state.forgeTier)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.purple)
                Text("Tap: \(store.tapDamage.compactGameNumber)  •  Auto: \(store.autoDPS.compactGameNumber)/s")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            Spacer()
        }
        .padding(14)
        .gamePanel(accent: GameTheme.cyan)
    }

    private func upgradeRow(_ type: UpgradeType) -> some View {
        let cost = store.upgradeCost(for: type)
        let canBuy = store.state.coins >= cost

        return HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(color(for: type))
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.45)))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(type.title.uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                    Spacer()
                    Text("Lv. \(store.level(for: type))")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.cyan)
                }
                Text(type.subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }

            Button {
                if store.buyUpgrade(type) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    show("Upgrade gekauft")
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    show("Nicht genug Coins")
                }
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .black))
                    Text(cost.compactGameNumber)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: 72, height: 50)
                .background(RoundedRectangle(cornerRadius: 11).fill(canBuy ? GameTheme.lime : Color.gray.opacity(0.55)))
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(10)
        .gamePanel(accent: color(for: type))
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("LIVE STATS")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.gold)
            stat("Tap Damage", store.tapDamage.compactGameNumber)
            stat("Auto-Mining", "\(store.autoDPS.compactGameNumber)/s")
            stat("Crit Chance", String(format: "%.0f%%", store.critChance * 100))
            stat("Crit Multiplier", String(format: "%.2fx", store.critMultiplier))
            stat("Chest Rare Chance", String(format: "%.0f%%", store.chestRareChance * 100))
        }
        .padding(14)
        .gamePanel(accent: GameTheme.gold)
    }

    private func stat(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func color(for type: UpgradeType) -> Color {
        switch type {
        case .tapPower: return GameTheme.gold
        case .autoMining: return GameTheme.cyan
        case .critDamage: return GameTheme.purple
        case .chestLuck: return GameTheme.orange
        case .beamPower: return GameTheme.lime
        }
    }

    private func show(_ text: String) {
        withAnimation { message = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation { message = nil }
        }
    }
}
