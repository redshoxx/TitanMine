import SwiftUI
import UIKit

private enum MineSheet: String, Identifiable {
    case map, quests, heroes, backpack
    var id: String { rawValue }
}

private struct DamagePopup: Identifiable {
    let id = UUID()
    let text: String
    let critical: Bool
    let x: CGFloat
    let y: CGFloat
}

struct MineView: View {
    @EnvironmentObject var store: GameStore
    @State private var activeSheet: MineSheet?
    @State private var popups: [DamagePopup] = []
    @State private var hitScale: CGFloat = 1
    @State private var flashOpacity: Double = 0
    @State private var sceneHitToken = 0
    @State private var sceneCritical = false

    var body: some View {
        VStack(spacing: 7) {
            levelHeader
            bossHeader

            battleArea
                .frame(maxHeight: .infinity)

            incomeStrip
            brandStrip
        }
        .padding(.horizontal, 9)
        .padding(.bottom, 5)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .map:
                WorldMapView().environmentObject(store)
            case .quests:
                QuestView().environmentObject(store)
            case .heroes:
                HeroesView().environmentObject(store)
            case .backpack:
                BackpackView().environmentObject(store)
            }
        }
    }

    private var levelHeader: some View {
        HStack(spacing: 8) {
            Text("LVL \(store.state.level)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(GameTheme.deepBlue))

            GameProgressBar(
                value: store.xpProgress,
                tint: GameTheme.cyan,
                label: "\(store.state.xp.compactGameNumber) / \(store.xpRequired.compactGameNumber)",
                height: 32
            )

            Image(systemName: "star.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(GameTheme.gold)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(GameTheme.panel))
        }
    }

    private var bossHeader: some View {
        VStack(spacing: 5) {
            HStack {
                Image(systemName: "skull.fill")
                Text(store.bossName)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.75)
                Image(systemName: "skull.fill")
            }
            .foregroundStyle(.white)
            .shadow(color: .black, radius: 2, y: 2)

            GameProgressBar(
                value: store.bossProgress,
                tint: GameTheme.red,
                label: "\(store.state.bossCurrentHP.compactGameNumber) / \(store.bossMaxHP.compactGameNumber)",
                height: 31
            )
        }
    }

    private var battleArea: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.2))

                Boss3DScene(hitToken: sceneHitToken, criticalHit: sceneCritical)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(hitScale)
                    .clipped()
                    .overlay(Color.white.opacity(flashOpacity).blendMode(.screen))
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                performTap(at: value.location, size: geo.size)
                            }
                    )

                LinearGradient(
                    colors: [.clear, .clear, Color.black.opacity(0.46)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                sideButtons

                VStack {
                    HStack {
                        boostButton
                        Spacer()
                        chestTimer
                    }
                    Spacer()
                }
                .padding(9)

                ForEach(popups) { popup in
                    Text(popup.text)
                        .font(.system(size: popup.critical ? 24 : 18, weight: .black, design: .rounded))
                        .foregroundStyle(popup.critical ? GameTheme.orange : .white)
                        .shadow(color: .black, radius: 2, x: 1, y: 2)
                        .position(x: popup.x, y: popup.y)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(GameTheme.cyan.opacity(0.55), lineWidth: 2))
        }
    }

    private var sideButtons: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                sideButton("MAP", icon: "map.fill", color: GameTheme.gold) { activeSheet = .map }
                sideButton("QUESTS", icon: "scroll.fill", color: GameTheme.orange) { activeSheet = .quests }
                sideButton("HEROES", icon: "person.crop.square.fill", color: GameTheme.cyan) { activeSheet = .heroes }
                sideButton("BAG", icon: "backpack.fill", color: GameTheme.gold) { activeSheet = .backpack }
                Spacer()
            }
            .padding(.top, 78)
            .padding(.trailing, 7)
        }
    }

    private func sideButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 50)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.72)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(GameTheme.gold.opacity(0.8), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var boostButton: some View {
        Button {
            if store.activateBoost(minutes: 10) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } label: {
            VStack(spacing: 0) {
                Text(store.state.boostSecondsRemaining > 0 ? "BOOST ACTIVE" : "POWER BOOST")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                HStack(spacing: 4) {
                    Image(systemName: "hammer.fill")
                    Text("x2")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                }
                if store.state.boostSecondsRemaining > 0 {
                    Text(timeText(store.state.boostSecondsRemaining))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                } else {
                    Text("50 GEMS")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 58)
            .background(
                LinearGradient(colors: [GameTheme.purple, GameTheme.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var chestTimer: some View {
        Button {
            store.selectedTab = .chests
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(GameTheme.gold)
                Text("EPIC CHEST")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                Text("\(store.state.chestCount) READY")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 76, height: 58)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.72)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(GameTheme.gold, lineWidth: 1.5))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var incomeStrip: some View {
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 0) {
                    Text("AUTO-MINING")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                    Text("\(store.autoDPS.compactGameNumber)/s")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.lime)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 46)
            .gamePanel(accent: GameTheme.cyan)

            income(icon: "circle.fill", value: store.autoDPS * 0.58, color: GameTheme.gold)
            income(icon: "diamond.fill", value: store.autoDPS * 0.12, color: GameTheme.cyan)
            income(icon: "diamond.fill", value: store.autoDPS * 0.05, color: GameTheme.lime)
            income(icon: "diamond.fill", value: store.autoDPS * 0.015, color: GameTheme.purple)
        }
    }

    private var brandStrip: some View {
        HStack(spacing: 7) {
            Text("TITAN")
                .foregroundStyle(GameTheme.cyan)
            Text("MINE")
                .foregroundStyle(GameTheme.gold)
        }
        .font(.system(size: 24, weight: .black, design: .rounded))
        .shadow(color: .black, radius: 2, y: 2)
        .frame(height: 28)
    }

    private func income(icon: String, value: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(color)
            Text("\(value.compactGameNumber)/s")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.72)))
    }

    private func performTap(at point: CGPoint, size: CGSize) {
        let result = store.tapBoss()
        sceneCritical = result.critical
        sceneHitToken &+= 1

        UIImpactFeedbackGenerator(style: result.critical ? .heavy : .light).impactOccurred()
        let popup = DamagePopup(
            text: result.critical ? "CRITICAL! -\(result.damage.compactGameNumber)" : "-\(result.damage.compactGameNumber)",
            critical: result.critical,
            x: min(max(45, point.x), size.width - 45),
            y: min(max(80, point.y - 24), size.height - 55)
        )
        withAnimation(.spring(response: 0.16, dampingFraction: 0.58)) {
            popups.append(popup)
            hitScale = result.critical ? 1.030 : 1.015
            flashOpacity = result.critical ? 0.24 : 0.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.18)) {
                hitScale = 1
                flashOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeOut(duration: 0.20)) {
                popups.removeAll { $0.id == popup.id }
            }
        }
    }

    private func timeText(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
