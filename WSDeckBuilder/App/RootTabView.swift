import SwiftUI

struct RootTabView: View {
    enum Tab { case catalog, deck, settings }

    @Environment(CardDatabase.self) private var database
    @Environment(OnboardingCoordinator.self) private var onboarding
    @Environment(DeckImportCoordinator.self) private var deckImport
    @State private var selectedTab: Tab = .catalog

    private let tabs: [GlassTabBarItem<Tab>] = [
        .init(id: .catalog, title: "圖鑑", systemImage: "magnifyingglass"),
        .init(id: .deck, title: "牌組", systemImage: "books.vertical.fill"),
        .init(id: .settings, title: "設定", systemImage: "gearshape.fill")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .catalog:
                    CardBrowserView()
                case .deck:
                    DeckListView()
                case .settings:
                    SettingsView()
                }
            }
            GlassTabBar(items: tabs, selection: $selectedTab)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .overlay {
            if let error = database.loadError {
                ContentUnavailableView("資料載入失敗",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(error))
                .background(.background)
            } else if database.isLoading {
                // 蓋住空的分頁，不然開啟後會先看到一片空白才跳出卡片
                loadingScreen
            }
        }
        .overlayPreferenceValue(OnboardingAnchorKey.self) { anchors in
            GeometryReader { proxy in
                OnboardingOverlay(coordinator: onboarding) { step in
                    anchors[step].map { proxy[$0] }
                }
            }
        }
        // 每一步該在哪個分頁，教學自己切過去——不然從「設定」按幫助重新開始教學，
        // 第一步「搜尋卡片」會卡在設定頁，找不到搜尋列
        .onChange(of: onboarding.currentStep, initial: true) { _, step in
            if let tab = step?.tab {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    selectedTab = tab
                }
            }
        }
        // 朋友用系統相機掃分享出去的牌組 QR 時，App 靠 wsdeck:// 連結被喚起，
        // 不管當下停在哪個分頁都要能跳出預覽，所以掛在根層而不是牌組分頁裡
        .sheet(isPresented: Binding(
            get: { deckImport.pending != nil },
            set: { if !$0 { deckImport.pending = nil } })) {
            if let parsed = deckImport.pending {
                DeckImportPreviewSheet(parsed: parsed) { deckImport.pending = nil }
            }
        }
        .alert("無法辨識連結", isPresented: Binding(
            get: { deckImport.errorMessage != nil },
            set: { if !$0 { deckImport.errorMessage = nil } })) {
            Button("好") {}
        } message: {
            Text(deckImport.errorMessage ?? "")
        }
    }

    private var loadingScreen: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("載入卡片資料…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
