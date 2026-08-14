import Foundation
import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case mine = "Mining"
    case upgrades = "Upgrades"
    case tnt = "TNT"
    case research = "Research"
    case chests = "Chests"
    case forge = "Forge"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mine: return "hammer.fill"
        case .upgrades: return "arrow.up.square.fill"
        case .tnt: return "shippingbox.fill"
        case .research: return "flask.fill"
        case .chests: return "shippingbox.and.arrow.backward.fill"
        case .forge: return "wrench.and.screwdriver.fill"
        }
    }
}

enum UpgradeType: String, CaseIterable, Identifiable {
    case tapPower
    case autoMining
    case critDamage
    case chestLuck
    case beamPower

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tapPower: return "Mining Speed"
        case .autoMining: return "Auto-Mining"
        case .critDamage: return "Crit Damage"
        case .chestLuck: return "Chest Luck"
        case .beamPower: return "Beam Power"
        }
    }

    var subtitle: String {
        switch self {
        case .tapPower: return "Mehr Schaden pro Tap"
        case .autoMining: return "Mehr Schaden pro Sekunde"
        case .critDamage: return "Kritische Treffer werden stärker"
        case .chestLuck: return "Bessere Chancen auf seltene Truhen"
        case .beamPower: return "Verstärkt Spezial- und TNT-Schaden"
        }
    }

    var icon: String {
        switch self {
        case .tapPower: return "hammer.fill"
        case .autoMining: return "gearshape.2.fill"
        case .critDamage: return "burst.fill"
        case .chestLuck: return "sparkles"
        case .beamPower: return "bolt.fill"
        }
    }
}

enum ResearchType: String, CaseIterable, Identifiable {
    case strongerTools
    case deepMining
    case crystalHarvest
    case energyFlow
    case treasureHunter
    case goldRush

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strongerTools: return "Stronger Tools"
        case .deepMining: return "Deep Mining"
        case .crystalHarvest: return "Crystal Harvest"
        case .energyFlow: return "Energy Flow"
        case .treasureHunter: return "Treasure Hunter"
        case .goldRush: return "Gold Rush"
        }
    }

    var icon: String {
        switch self {
        case .strongerTools: return "hammer.circle.fill"
        case .deepMining: return "arrow.down.circle.fill"
        case .crystalHarvest: return "diamond.fill"
        case .energyFlow: return "bolt.circle.fill"
        case .treasureHunter: return "shippingbox.circle.fill"
        case .goldRush: return "dollarsign.circle.fill"
        }
    }
}

struct HitResult: Identifiable {
    let id = UUID()
    let damage: Double
    let critical: Bool
}

struct ChestReward: Identifiable {
    let id = UUID()
    let coins: Double
    let blueCrystals: Int
    let greenGems: Int
    let purpleShards: Int
    let researchPoints: Int
    let rarity: String
}

struct WorldZone: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let requiredBoss: Int
    let systemImage: String
}

struct PlayerState: Codable {
    var coins: Double = 12_800_000
    var blueCrystals: Int = 16_540
    var greenGems: Int = 9_230
    var purpleShards: Int = 2_840

    var level: Int = 1
    var xp: Double = 0
    var bossIndex: Int = 1
    var bossCurrentHP: Double = 25_000

    var tapLevel: Int = 1
    var autoLevel: Int = 1
    var critLevel: Int = 1
    var chestLuckLevel: Int = 1
    var beamLevel: Int = 1

    var researchStrongerTools: Int = 0
    var researchDeepMining: Int = 0
    var researchCrystalHarvest: Int = 0
    var researchEnergyFlow: Int = 0
    var researchTreasureHunter: Int = 0
    var researchGoldRush: Int = 0

    var researchPoints: Int = 430
    var tntCount: Int = 24
    var chestCount: Int = 3
    var forgeTier: Int = 1
    var heroLevel: Int = 1
    var heroPower: Double = 0
    var boostSecondsRemaining: Int = 0
    var totalBossesDefeated: Int = 0
    var totalTaps: Int = 0
    var lastSeen: Date = Date()
    var lastDailyGift: Date? = nil
}

extension Double {
    var compactGameNumber: String {
        let value = abs(self)
        let sign = self < 0 ? "-" : ""
        switch value {
        case 1_000_000_000_000...:
            return String(format: "%@%.2fT", sign, value / 1_000_000_000_000)
        case 1_000_000_000...:
            return String(format: "%@%.2fB", sign, value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%@%.2fM", sign, value / 1_000_000)
        case 1_000...:
            return String(format: "%@%.1fK", sign, value / 1_000)
        default:
            return String(format: "%@%.0f", sign, value)
        }
    }
}

extension Int {
    var compactGameNumber: String {
        Double(self).compactGameNumber
    }
}
import Foundation
import SwiftUI
import Combine

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var state: PlayerState
    @Published var selectedTab: MainTab = .mine
    @Published var lastReward: ChestReward?
    @Published var offlineReward: Double = 0

    private var timer: AnyCancellable?
    private var boostAccumulator: Double = 0
    private let saveKey = "TitanMine.PlayerState.v1"

    let worlds: [WorldZone] = [
        .init(id: 1, title: "Grass Mine", subtitle: "Grüne Insel", requiredBoss: 1, systemImage: "leaf.fill"),
        .init(id: 2, title: "Crystal Reef", subtitle: "Kristallküste", requiredBoss: 5, systemImage: "diamond.fill"),
        .init(id: 3, title: "Lava Depths", subtitle: "Magma-Mine", requiredBoss: 12, systemImage: "flame.fill"),
        .init(id: 4, title: "Ancient Ruins", subtitle: "Alte Tiefen", requiredBoss: 22, systemImage: "building.columns.fill"),
        .init(id: 5, title: "Sky Forge", subtitle: "Himmelsmine", requiredBoss: 35, systemImage: "cloud.fill"),
        .init(id: 6, title: "Void Core", subtitle: "Endgame", requiredBoss: 55, systemImage: "sparkles")
    ]

    private let bossNames = [
        "CRYSTAL TITAN", "STONE COLOSSUS", "GOLD GUARDIAN", "OBSIDIAN GOLEM",
        "FROST GIANT", "ANCIENT WARDEN", "MAGMA TITAN", "VOID SENTINEL"
    ]

    init() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode(PlayerState.self, from: data) {
            state = decoded
        } else {
            state = PlayerState()
        }

        normalizeLoadedState()
        applyOfflineProgress()
        startLoop()
    }

    deinit {
        timer?.cancel()
    }

    var bossName: String {
        bossNames[(max(1, state.bossIndex) - 1) % bossNames.count]
    }

    var bossMaxHP: Double {
        25_000 * pow(1.30, Double(max(0, state.bossIndex - 1)))
    }

    var bossProgress: Double {
        guard bossMaxHP > 0 else { return 0 }
        return max(0, min(1, state.bossCurrentHP / bossMaxHP))
    }

    var xpRequired: Double {
        1_000 * pow(1.16, Double(max(0, state.level - 1)))
    }

    var xpProgress: Double {
        max(0, min(1, state.xp / xpRequired))
    }

    var boostMultiplier: Double {
        state.boostSecondsRemaining > 0 ? 2.0 : 1.0
    }

    var tapDamage: Double {
        let base = 620 * pow(1.19, Double(max(0, state.tapLevel - 1)))
        let research = 1 + Double(state.researchStrongerTools) * 0.08
        return base * research * boostMultiplier
    }

    var autoDPS: Double {
        let base = 850 * pow(1.18, Double(max(0, state.autoLevel - 1)))
        let energy = 1 + Double(state.researchEnergyFlow) * 0.10
        let hero = 1 + state.heroPower
        return base * energy * hero * boostMultiplier
    }

    var critChance: Double {
        min(0.55, 0.08 + Double(state.critLevel - 1) * 0.012)
    }

    var critMultiplier: Double {
        2.0 + Double(state.critLevel - 1) * 0.12
    }

    var coinMultiplier: Double {
        1 + Double(state.researchGoldRush) * 0.10
    }

    var chestRareChance: Double {
        min(0.70, 0.12 + Double(state.chestLuckLevel - 1) * 0.015 + Double(state.researchTreasureHunter) * 0.025)
    }

    var currentWorld: WorldZone {
        worlds.last(where: { state.bossIndex >= $0.requiredBoss }) ?? worlds[0]
    }

    func tapBoss() -> HitResult {
        state.totalTaps += 1
        let critical = Double.random(in: 0...1) < critChance
        var damage = tapDamage
        if critical { damage *= critMultiplier }
        applyDamage(damage)
        save()
        return HitResult(damage: damage, critical: critical)
    }

    func useTNT() -> HitResult? {
        guard state.tntCount > 0 else { return nil }
        state.tntCount -= 1
        let multiplier = 1 + Double(state.beamLevel - 1) * 0.06
        let damage = max(tapDamage * 18 * multiplier, bossMaxHP * 0.18 * multiplier)
        applyDamage(damage)
        save()
        return HitResult(damage: damage, critical: true)
    }

    @discardableResult
    func activateBoost(minutes: Int = 10) -> Bool {
        guard state.boostSecondsRemaining <= 0, state.greenGems >= 50 else { return false }
        state.greenGems -= 50
        state.boostSecondsRemaining = minutes * 60
        save()
        return true
    }

    func level(for type: UpgradeType) -> Int {
        switch type {
        case .tapPower: return state.tapLevel
        case .autoMining: return state.autoLevel
        case .critDamage: return state.critLevel
        case .chestLuck: return state.chestLuckLevel
        case .beamPower: return state.beamLevel
        }
    }

    func upgradeCost(for type: UpgradeType) -> Double {
        let lvl = level(for: type)
        let base: Double
        switch type {
        case .tapPower: base = 18_000
        case .autoMining: base = 24_000
        case .critDamage: base = 42_000
        case .chestLuck: base = 55_000
        case .beamPower: base = 68_000
        }
        return base * pow(1.38, Double(max(0, lvl - 1)))
    }

    @discardableResult
    func buyUpgrade(_ type: UpgradeType) -> Bool {
        let cost = upgradeCost(for: type)
        guard state.coins >= cost else { return false }
        state.coins -= cost
        switch type {
        case .tapPower: state.tapLevel += 1
        case .autoMining: state.autoLevel += 1
        case .critDamage: state.critLevel += 1
        case .chestLuck: state.chestLuckLevel += 1
        case .beamPower: state.beamLevel += 1
        }
        save()
        return true
    }

    func researchLevel(_ type: ResearchType) -> Int {
        switch type {
        case .strongerTools: return state.researchStrongerTools
        case .deepMining: return state.researchDeepMining
        case .crystalHarvest: return state.researchCrystalHarvest
        case .energyFlow: return state.researchEnergyFlow
        case .treasureHunter: return state.researchTreasureHunter
        case .goldRush: return state.researchGoldRush
        }
    }

    func researchCost(_ type: ResearchType) -> Int {
        35 + researchLevel(type) * 30
    }

    @discardableResult
    func buyResearch(_ type: ResearchType) -> Bool {
        let cost = researchCost(type)
        guard state.researchPoints >= cost else { return false }
        state.researchPoints -= cost
        switch type {
        case .strongerTools: state.researchStrongerTools += 1
        case .deepMining: state.researchDeepMining += 1
        case .crystalHarvest: state.researchCrystalHarvest += 1
        case .energyFlow: state.researchEnergyFlow += 1
        case .treasureHunter: state.researchTreasureHunter += 1
        case .goldRush: state.researchGoldRush += 1
        }
        save()
        return true
    }

    func openChest() -> ChestReward? {
        guard state.chestCount > 0 else { return nil }
        state.chestCount -= 1

        let roll = Double.random(in: 0...1)
        let rarity: String
        let rarityMultiplier: Double
        if roll < max(0.03, chestRareChance * 0.14) {
            rarity = "LEGENDARY"
            rarityMultiplier = 8
        } else if roll < chestRareChance {
            rarity = "EPIC"
            rarityMultiplier = 3.5
        } else {
            rarity = "RARE"
            rarityMultiplier = 1.5
        }

        let reward = ChestReward(
            coins: bossReward * rarityMultiplier,
            blueCrystals: Int(Double.random(in: 55...150) * rarityMultiplier),
            greenGems: Int(Double.random(in: 18...75) * rarityMultiplier),
            purpleShards: Int(Double.random(in: 4...22) * rarityMultiplier),
            researchPoints: Int(Double.random(in: 8...30) * rarityMultiplier),
            rarity: rarity
        )

        state.coins += reward.coins
        state.blueCrystals += reward.blueCrystals
        state.greenGems += reward.greenGems
        state.purpleShards += reward.purpleShards
        state.researchPoints += reward.researchPoints
        lastReward = reward
        save()
        return reward
    }

    var forgeCost: (blue: Int, green: Int, purple: Int) {
        let tier = max(1, state.forgeTier)
        return (blue: 120 * tier, green: 65 * tier, purple: 25 * tier)
    }

    @discardableResult
    func forgeUpgrade() -> Bool {
        let cost = forgeCost
        guard state.blueCrystals >= cost.blue,
              state.greenGems >= cost.green,
              state.purpleShards >= cost.purple else { return false }
        state.blueCrystals -= cost.blue
        state.greenGems -= cost.green
        state.purpleShards -= cost.purple
        state.forgeTier += 1
        state.tapLevel += 2
        state.autoLevel += 2
        save()
        return true
    }

    @discardableResult
    func hireHero() -> Bool {
        let cost = 250_000 * pow(1.6, Double(max(0, state.heroLevel - 1)))
        guard state.coins >= cost else { return false }
        state.coins -= cost
        state.heroLevel += 1
        state.heroPower += 0.08
        save()
        return true
    }

    var heroUpgradeCost: Double {
        250_000 * pow(1.6, Double(max(0, state.heroLevel - 1)))
    }

    var canClaimDailyGift: Bool {
        guard let last = state.lastDailyGift else { return true }
        return Date().timeIntervalSince(last) >= 24 * 60 * 60
    }

    var dailyGiftRemaining: TimeInterval {
        guard let last = state.lastDailyGift else { return 0 }
        return max(0, 24 * 60 * 60 - Date().timeIntervalSince(last))
    }

    @discardableResult
    func claimDailyGift() -> Bool {
        guard canClaimDailyGift else { return false }
        state.coins += bossReward * 4
        state.tntCount += 3
        state.chestCount += 1
        state.researchPoints += 25
        state.lastDailyGift = Date()
        save()
        return true
    }

    func resetProgress() {
        state = PlayerState()
        offlineReward = 0
        lastReward = nil
        save()
    }

    private var bossReward: Double {
        bossMaxHP * 0.72 * coinMultiplier
    }

    private func applyDamage(_ rawDamage: Double) {
        var damage = max(0, rawDamage)
        var safety = 0
        while damage > 0 && safety < 12 {
            safety += 1
            if damage < state.bossCurrentHP {
                state.bossCurrentHP -= damage
                damage = 0
            } else {
                damage -= state.bossCurrentHP
                defeatBoss()
            }
        }
    }

    private func defeatBoss() {
        let reward = bossReward
        state.coins += reward
        state.blueCrystals += max(4, 8 + state.bossIndex * 2 + state.researchCrystalHarvest * 2)
        state.greenGems += max(1, state.bossIndex / 2)
        if state.bossIndex % 3 == 0 { state.purpleShards += 2 + state.bossIndex / 4 }
        if state.bossIndex % 4 == 0 { state.chestCount += 1 }
        if state.bossIndex % 2 == 0 { state.researchPoints += 12 + state.bossIndex }

        state.totalBossesDefeated += 1
        gainXP(320 + Double(state.bossIndex) * 45)
        state.bossIndex += 1
        state.bossCurrentHP = bossMaxHP
    }

    private func gainXP(_ amount: Double) {
        state.xp += amount
        var guardCount = 0
        while state.xp >= xpRequired && guardCount < 20 {
            guardCount += 1
            state.xp -= xpRequired
            state.level += 1
            state.coins += Double(state.level) * 12_500
            if state.level % 3 == 0 { state.tntCount += 1 }
            if state.level % 5 == 0 { state.chestCount += 1 }
        }
    }

    private func startLoop() {
        timer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.tick(delta: 0.25)
            }
    }

    private func tick(delta: Double) {
        applyDamage(autoDPS * delta)
        if state.boostSecondsRemaining > 0 {
            boostAccumulator += delta
            if boostAccumulator >= 1 {
                let elapsedWholeSeconds = Int(boostAccumulator)
                state.boostSecondsRemaining = max(0, state.boostSecondsRemaining - elapsedWholeSeconds)
                boostAccumulator -= Double(elapsedWholeSeconds)
            }
        } else {
            boostAccumulator = 0
        }
        state.lastSeen = Date()

        if Int(Date().timeIntervalSince1970 * 4) % 8 == 0 {
            save()
        }
    }

    private func normalizeLoadedState() {
        if state.bossIndex < 1 { state.bossIndex = 1 }
        let maxHP = bossMaxHP
        if !state.bossCurrentHP.isFinite || state.bossCurrentHP <= 0 || state.bossCurrentHP > maxHP {
            state.bossCurrentHP = maxHP
        }
        state.level = max(1, state.level)
        state.tapLevel = max(1, state.tapLevel)
        state.autoLevel = max(1, state.autoLevel)
        state.critLevel = max(1, state.critLevel)
        state.chestLuckLevel = max(1, state.chestLuckLevel)
        state.beamLevel = max(1, state.beamLevel)
        state.forgeTier = max(1, state.forgeTier)
        state.heroLevel = max(1, state.heroLevel)
    }

    private func applyOfflineProgress() {
        let elapsed = min(max(0, Date().timeIntervalSince(state.lastSeen)), 8 * 60 * 60)
        guard elapsed > 20 else {
            state.lastSeen = Date()
            return
        }
        let reward = autoDPS * elapsed * 0.42
        state.coins += reward
        offlineReward = reward
        state.lastSeen = Date()
        save()
    }

    private func save() {
        state.lastSeen = Date()
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
}
