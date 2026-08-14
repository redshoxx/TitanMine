import SwiftUI

@main
struct TitanMineApp: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            GameRootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
