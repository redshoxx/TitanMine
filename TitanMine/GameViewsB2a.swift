import SwiftUI
import UIKit

struct ResearchView: View {
    @EnvironmentObject var store: GameStore

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("RESEARCH")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(GameTheme.purple)
                        Text("Permanente Forschung für Mining, Loot und Automation")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(GameTheme.purple)
                        Text("\(store.state.researchPoints)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .gamePanel(accent: GameTheme.purple)
                }
                .padding(.horizontal, 10)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ResearchType.allCases) { type in
                        researchNode(type)
                    }
                }
                .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("FORSCHUNGSBONI")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.gold)
                    bonus("Mining Power", "+\(store.state.researchStrongerTools * 8)%")
                    bonus("Auto Energy", "+\(store.state.researchEnergyFlow * 10)%")
                    bonus("Gold Bonus", "+\(store.state.researchGoldRush * 10)%")
                    bonus("Treasure Luck", "+\(store.state.researchTreasureHunter * 3)%")
                }
                .padding(14)
                .gamePanel(accent: GameTheme.gold)
                .padding(.horizontal, 10)
            }
            .padding(.vertical, 10)
        }
    }

    private func researchNode(_ type: ResearchType) -> some View {
        let level = store.researchLevel(type)
        let cost = store.researchCost(type)
        let canBuy = store.state.researchPoints >= cost

        return Button {
            if store.buyResearch(type) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(level > 0 ? GameTheme.cyan : GameTheme.purple)
                    .shadow(color: GameTheme.purple.opacity(0.6), radius: 7)

                Text(type.title.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text("Lv. \(level)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.gold)

                Text("\(cost) RP")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(canBuy ? GameTheme.lime : .gray)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .gamePanel(accent: level > 0 ? GameTheme.cyan : GameTheme.purple)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func bonus(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.lime)
        }
    }
}
import SwiftUI
import UIKit

struct ChestView: View {
    @EnvironmentObject var store: GameStore
    @State private var opening = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            Text("EPIC CHESTS")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.gold)

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        RadialGradient(colors: [GameTheme.purple.opacity(0.75), GameTheme.panel], center: .center, startRadius: 20, endRadius: 150)
                    )
                    .frame(height: 250)
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(GameTheme.gold, lineWidth: 2))

                VStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 92, weight: .black))
                        .foregroundStyle(GameTheme.gold)
                        .shadow(color: GameTheme.purple, radius: opening ? 26 : 12)
                        .scaleEffect(opening ? 1.12 : 1)
                    Text("\(store.state.chestCount) CHESTS READY")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                }
            }
            .padding(.horizontal, 18)

            Button {
                guard store.state.chestCount > 0 else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { opening = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    _ = store.openChest()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation { opening = false }
                }
            } label: {
                Text(store.state.chestCount > 0 ? "TRUHE ÖFFNEN" : "KEINE TRUHE")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [GameTheme.purple, GameTheme.orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .disabled(store.state.chestCount <= 0 || opening)
            .buttonStyle(PressScaleButtonStyle())
            .padding(.horizontal, 18)

            if let reward = store.lastReward {
                rewardCard(reward)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("Mögliche Beute: Coins, Kristalle, Gems, Research Points und seltene Materialien.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func rewardCard(_ reward: ChestReward) -> some View {
        VStack(spacing: 10) {
            Text(reward.rarity)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(reward.rarity == "LEGENDARY" ? GameTheme.gold : GameTheme.purple)
            HStack(spacing: 8) {
                rewardItem("Coins", reward.coins.compactGameNumber, "circle.fill", GameTheme.gold)
                rewardItem("Blue", reward.blueCrystals.compactGameNumber, "diamond.fill", GameTheme.cyan)
                rewardItem("Green", reward.greenGems.compactGameNumber, "diamond.fill", GameTheme.lime)
                rewardItem("Purple", reward.purpleShards.compactGameNumber, "diamond.fill", GameTheme.purple)
            }
            Text("+\(reward.researchPoints) Research Points")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(14)
        .gamePanel(accent: GameTheme.gold)
        .padding(.horizontal, 18)
    }

    private func rewardItem(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .rounded))
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}
