import SwiftUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @State private var showSettings = false
    @State private var showOfflineReward = false

    var body: some View {
        ZStack {
            GameTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ResourceHeader(onGear: { showSettings = true })
                    .padding(.bottom, 4)

                Group {
                    switch store.selectedTab {
                    case .mine: MineView()
                    case .upgrades: UpgradeView()
                    case .tnt: TNTView()
                    case .research: ResearchView()
                    case .chests: ChestView()
                    case .forge: ForgeView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomGameBar()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .alert("Offline-Ertrag", isPresented: $showOfflineReward) {
            Button("Einsammeln", role: .cancel) { store.offlineReward = 0 }
        } message: {
            Text("Deine Miner haben während deiner Abwesenheit \(store.offlineReward.compactGameNumber) Coins verdient.")
        }
        .onAppear {
            if store.offlineReward > 0 {
                showOfflineReward = true
            }
        }
    }
}
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Game") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Boss", value: "#\(store.state.bossIndex)")
                    LabeledContent("Besiegte Bosse", value: "\(store.state.totalBossesDefeated)")
                    LabeledContent("Taps", value: "\(store.state.totalTaps)")
                }

                Section("Sideload") {
                    Text("Die App benötigt keine Anmeldung, Cloud-Verbindung oder speziellen iOS-Entitlements und ist deshalb für AltStore Classic als normale IPA geeignet.")
                        .font(.footnote)
                }

                Section {
                    Button("Spielstand zurücksetzen", role: .destructive) {
                        showReset = true
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
            }
            .alert("Spielstand löschen?", isPresented: $showReset) {
                Button("Abbrechen", role: .cancel) { }
                Button("Zurücksetzen", role: .destructive) {
                    store.resetProgress()
                    dismiss()
                }
            } message: {
                Text("Alle lokalen Fortschritte werden gelöscht.")
            }
        }
    }
}
import SwiftUI

struct BackpackView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GameTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        inventory("Coins", store.state.coins.compactGameNumber, "circle.fill", GameTheme.gold)
                        inventory("Blue Crystals", store.state.blueCrystals.compactGameNumber, "diamond.fill", GameTheme.cyan)
                        inventory("Green Gems", store.state.greenGems.compactGameNumber, "diamond.fill", GameTheme.lime)
                        inventory("Purple Shards", store.state.purpleShards.compactGameNumber, "diamond.fill", GameTheme.purple)
                        inventory("TNT", "x\(store.state.tntCount)", "shippingbox.fill", GameTheme.orange)
                        inventory("Chests", "x\(store.state.chestCount)", "shippingbox.fill", GameTheme.gold)
                        inventory("Research Points", "\(store.state.researchPoints)", "book.closed.fill", GameTheme.purple)
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Backpack")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
            }
        }
    }

    private func inventory(_ name: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(12)
        .gamePanel(accent: color)
    }
}
import SwiftUI

struct QuestView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GameTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        quest("Boss Hunter", current: store.state.totalBossesDefeated, target: 10, reward: "1 Chest")
                        quest("Tap Master", current: store.state.totalTaps, target: 500, reward: "5 TNT")
                        quest("Deep Miner", current: store.state.bossIndex, target: 20, reward: "120 RP")
                        quest("Forge Legend", current: store.state.forgeTier, target: 5, reward: "Epic Materials")

                        Button {
                            _ = store.claimDailyGift()
                        } label: {
                            Text(store.canClaimDailyGift ? "DAILY GIFT EINSAMMELN" : "DAILY GIFT SPÄTER")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(RoundedRectangle(cornerRadius: 14).fill(store.canClaimDailyGift ? GameTheme.orange : Color.gray.opacity(0.55)))
                        }
                        .disabled(!store.canClaimDailyGift)
                        .buttonStyle(PressScaleButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Quests")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
            }
        }
    }

    private func quest(_ title: String, current: Int, target: Int, reward: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Spacer()
                Text(reward)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.gold)
            }
            GameProgressBar(
                value: min(1, Double(current) / Double(target)),
                tint: current >= target ? GameTheme.lime : GameTheme.cyan,
                label: "\(min(current, target)) / \(target)",
                height: 22
            )
        }
        .padding(12)
        .gamePanel(accent: current >= target ? GameTheme.lime : GameTheme.cyan)
    }
}
import SwiftUI
import UIKit

struct HeroesView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GameTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        heroCard
                        companion("LUNA", "Crystal Hunter", "Rare", GameTheme.cyan, "+12% Crystal Loot")
                        companion("THORIN", "Heavy Miner", "Epic", GameTheme.gold, "+18% Auto Damage")
                        companion("IONIS", "Beam Engineer", "Legendary", GameTheme.purple, "+15% Crit Power")
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Heroes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.square.fill")
                .font(.system(size: 76, weight: .black))
                .foregroundStyle(GameTheme.gold)
            Text("AURON • MINER HERO")
                .font(.system(size: 20, weight: .black, design: .rounded))
            Text("Level \(store.state.heroLevel) • +\(Int(store.state.heroPower * 100))% Auto-Mining")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Button {
                if store.hireHero() {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            } label: {
                Text("HERO UPGRADE • \(store.heroUpgradeCost.compactGameNumber)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 13).fill(GameTheme.lime))
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(16)
        .gamePanel(accent: GameTheme.gold)
    }

    private func companion(_ name: String, _ role: String, _ rarity: String, _ color: Color, _ effect: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(color)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Text("\(role) • \(rarity)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(effect)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(12)
        .gamePanel(accent: color)
    }
}
import SwiftUI

struct WorldMapView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [GameTheme.deepBlue, GameTheme.navy, .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        Text("WORLD MAP")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .foregroundStyle(GameTheme.gold)

                        ForEach(Array(store.worlds.enumerated()), id: \.element.id) { index, world in
                            worldCard(world, index: index)
                            if index < store.worlds.count - 1 {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(GameTheme.gold.opacity(0.75))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func worldCard(_ world: WorldZone, index: Int) -> some View {
        let unlocked = store.state.bossIndex >= world.requiredBoss
        let current = store.currentWorld.id == world.id

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: unlocked ? [color(index).opacity(0.95), GameTheme.panel2] : [Color.gray.opacity(0.35), GameTheme.panel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: unlocked ? world.systemImage : "lock.fill")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(unlocked ? .white : .gray)
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(world.id). \(world.title.uppercased())")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                Text(world.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                Text(unlocked ? (current ? "AKTUELLE WELT" : "FREIGESCHALTET") : "Boss \(world.requiredBoss) erforderlich")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(unlocked ? GameTheme.lime : GameTheme.orange)
            }

            Spacer()

            if current {
                Image(systemName: "star.fill")
                    .foregroundStyle(GameTheme.gold)
                    .font(.system(size: 24, weight: .black))
            }
        }
        .padding(12)
        .gamePanel(accent: current ? GameTheme.gold : color(index))
    }

    private func color(_ index: Int) -> Color {
        let colors: [Color] = [GameTheme.lime, GameTheme.cyan, GameTheme.orange, GameTheme.gold, .white, GameTheme.purple]
        return colors[index % colors.count]
    }
}
import SwiftUI
import UIKit

struct TNTView: View {
    @EnvironmentObject var store: GameStore
    @State private var lastBlast: HitResult?

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [GameTheme.red, GameTheme.orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 180, height: 180)
                    .shadow(color: GameTheme.orange.opacity(0.7), radius: 24)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 84, weight: .black))
                    .foregroundStyle(.white)
            }

            Text("TNT BLAST")
                .font(.system(size: 30, weight: .black, design: .rounded))

            Text("Ein massiver Spezialangriff gegen den aktuellen Titan. Der Schaden skaliert mit Beam Power und deiner Forge-Stufe.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            HStack(spacing: 12) {
                statCard("VORRAT", "x\(store.state.tntCount)", GameTheme.orange)
                statCard("SCHADEN", blastPreview.compactGameNumber, GameTheme.purple)
            }
            .padding(.horizontal, 16)

            Button {
                if let hit = store.useTNT() {
                    lastBlast = hit
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text(store.state.tntCount > 0 ? "TNT ZÜNDEN" : "KEIN TNT")
                }
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: store.state.tntCount > 0 ? [GameTheme.red, GameTheme.orange] : [Color.gray, Color.gray.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.45), lineWidth: 1.5))
            }
            .disabled(store.state.tntCount <= 0)
            .buttonStyle(PressScaleButtonStyle())
            .padding(.horizontal, 16)

            if let lastBlast {
                Text("Letzter Treffer: -\(lastBlast.damage.compactGameNumber)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.gold)
            }

            Button {
                store.selectedTab = .chests
            } label: {
                Text("Mehr TNT aus Truhen erhalten")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GameTheme.cyan)
            }

            Spacer()
        }
    }

    private var blastPreview: Double {
        max(store.tapDamage * 18, store.bossMaxHP * 0.18) * (1 + Double(store.state.beamLevel - 1) * 0.06)
    }

    private func statCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .gamePanel(accent: color)
    }
}
