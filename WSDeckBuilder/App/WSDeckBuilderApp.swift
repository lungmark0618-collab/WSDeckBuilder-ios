import SwiftData
import SwiftUI

@main
struct WSDeckBuilderApp: App {
    @State private var database = CardDatabase()
    @State private var appearance = AppearanceSettings.shared
    @State private var updater = DataUpdater()
    @State private var announcements = AnnouncementCenter()
    @State private var onboarding = OnboardingCoordinator()
    @State private var favorites = FavoriteTitlesStore()
    // 只有冷啟動才會跑 .task，使用者切去別的 App 再切回來（沒有真的把 App
    // 滑掉重開）並不會重新觸發——這才是「還是要手動按檢查更新」的真正原因，
    // 要另外盯 scenePhase 回到前景才會再查一次
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(database)
                .environment(appearance)
                .environment(updater)
                .environment(announcements)
                .environment(onboarding)
                .environment(favorites)
                .appAppearance(appearance)
                .task {
                    await database.load()
                    favorites.migrate(using: database)
                    // 查更新絕不擋開場：卡表載完、畫面已經能用了才在背景問一次
                    await checkForUpdates()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, !database.isLoading, !database.cards.isEmpty else { return }
                    Task { await checkForUpdates() }
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    Task { await ImageCache.shared.handleMemoryWarning() }
                }
        }
        .modelContainer(for: [Deck.self, DeckEntry.self, CollectionEntry.self])
    }

    private func checkForUpdates() async {
        await updater.checkSilently(against: database)
        if case .updateAvailable(let pending) = updater.state {
            announcements.noteDataUpdates(pending)
        }
        await announcements.checkSilently()
    }
}
