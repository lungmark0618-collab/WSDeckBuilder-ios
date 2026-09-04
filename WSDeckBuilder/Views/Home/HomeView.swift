import SwiftData
import SwiftUI

/// App 開啟後第一眼看到的畫面：官網公告（新商品、卡表更新、大會、規則異動），
/// 取代原本開場就是圖鑑的安排——這是使用者主動要求的首頁。
struct HomeView: View {
    @Environment(WSNewsService.self) private var news
    @Environment(CardDatabase.self) private var database
    @Environment(PinnedDecksStore.self) private var pinnedDecks
    @Query private var allDecks: [Deck]
    // 點公告先看我們整理過的重點，不是直接跳出 App 到瀏覽器——
    // 有興趣看完整內容的人，詳情頁裡還有官網連結
    @State private var selectedItem: WSNewsItem?
    /// 點常用牌組直接用 sheet 開詳情，不用切去「牌組」分頁再找一次——
    /// 這正是「釘選到首頁」要省下來的那一步
    @State private var selectedDeck: Deck?

    var body: some View {
        NavigationStack {
            Group {
                if news.items.isEmpty, news.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if news.items.isEmpty {
                    ContentUnavailableView("還沒有公告", systemImage: "newspaper",
                                           description: Text("下拉重新整理試試看。"))
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.s16) {
                            if !pinnedDecksOrdered.isEmpty {
                                PinnedDecksRow(decks: pinnedDecksOrdered, database: database) {
                                    selectedDeck = $0
                                }
                                .padding(.top, Spacing.s8)
                            }
                            if !heroItems.isEmpty {
                                HeroCarousel(items: heroItems, categoryColor: categoryColor(_:)) {
                                    selectedItem = $0
                                }
                                .padding(.top, pinnedDecksOrdered.isEmpty ? Spacing.s8 : 0)
                                .onboardingAnchor(.homeIntro)
                            }
                            LazyVStack(spacing: Spacing.s12) {
                                if let errorMessage = news.errorMessage {
                                    Text(errorMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.orange)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, Spacing.s4)
                                }
                                ForEach(news.items) { item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        row(item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Spacing.s16)
                        }
                        .padding(.bottom, 140)
                    }
                    .scrollContentBackground(.hidden)
                    .background {
                        ZStack {
                            AppSurface.background
                            meshBackground
                        }
                        .ignoresSafeArea()
                    }
                }
            }
            .navigationTitle("首頁")
            .refreshable { await news.refresh() }
            .task {
                if news.items.isEmpty { await news.refresh() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBellButton()
                }
            }
            .sheet(item: $selectedItem) { item in
                NewsDetailSheet(item: item)
            }
            .sheet(item: $selectedDeck) { deck in
                NavigationStack {
                    DeckDetailView(deck: deck)
                }
            }
        }
    }

    /// 依釘選順序排出實際存在的牌組——牌組被刪掉但清理沒跑到的殘影
    /// （理論上不會發生，PinnedDecksStore.remove 已經在刪牌組時呼叫，
    /// 這裡只是多一層防呆）就自然濾掉，不會顯示空卡片
    private var pinnedDecksOrdered: [Deck] {
        let byUUID = Dictionary(uniqueKeysWithValues: allDecks.map { ($0.uuid.uuidString, $0) })
        return pinnedDecks.uuids.compactMap { byUUID[$0] }
    }

    /// 輪播只挑有配圖、跟商品/卡表有關的公告——參考官網首頁「最新商品」跑馬燈的做法，
    /// 規則更新、賽事這類沒有視覺重點的公告不適合放大圖展示
    private var heroItems: [WSNewsItem] {
        news.items
            .filter { $0.imageURL != nil && $0.categories.contains(where: { $0 == "商品情報" || $0 == "カードリスト" }) }
            .prefix(6)
            .map { $0 }
    }

    /// 首頁背景的全息光暈——呼應集換式卡牌本身的「卡背」質感，
    /// 淡淡三團色暈疊在近黑底色上，不搶內容但讓畫面不死板
    private var meshBackground: some View {
        ZStack {
            RadialGradient(colors: [.purple.opacity(0.20), .clear],
                           center: .init(x: 0.88, y: -0.06), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [.orange.opacity(0.10), .clear],
                           center: .init(x: -0.1, y: 0.18), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [Color(red: 0.85, green: 0.35, blue: 0.60).opacity(0.14), .clear],
                           center: .init(x: 0.5, y: 1.2), startRadius: 0, endRadius: 420)
        }
    }

    private func row(_ item: WSNewsItem) -> some View {
        let color = item.categories.first.map(categoryColor) ?? .secondary
        return VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(spacing: Spacing.s8) {
                ForEach(item.categories, id: \.self) { category in
                    HStack(spacing: Spacing.s4) {
                        // 小菱形「寶石」取代原本的色塊膠囊，呼應卡牌稀有度標記
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(categoryColor(category))
                            .frame(width: 6, height: 6)
                            .rotationEffect(.degrees(45))
                            .shadow(color: categoryColor(category).opacity(0.7), radius: 4)
                        Text(category)
                            .font(.caption2.weight(.heavy))
                            .tracking(0.4)
                    }
                    .foregroundStyle(categoryTint(category))
                }
                Spacer(minLength: Spacing.s8)
                Text(item.date.replacingOccurrences(of: "-", with: "."))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.42))
            }
            Text(item.displayTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(white: 0.96))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(Spacing.s16)
        .background {
            ZStack {
                LinearGradient(colors: [Color(red: 0.078, green: 0.082, blue: 0.122),
                                        Color(red: 0.047, green: 0.051, blue: 0.078)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                // 卡角的全息燙金色塊——這就是「B·全息卡背」跟其他方向的核心差異
                GeometryReader { proxy in
                    color.opacity(0.16)
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(45))
                        .position(x: proxy.size.width, y: 0)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.mid + 2, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.mid + 2, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    /// 卡角燙金色塊、寶石標記共用的飽和色
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "商品情報": .blue
        case "カードリスト": .green
        case "大会", "イベント": .orange
        case "ルール": .purple
        case "デッキレシピ": .pink
        default: .secondary
        }
    }

    /// 分類文字用的淺色調，飽和色直接當文字色在深底上太刺眼
    private func categoryTint(_ category: String) -> Color {
        switch category {
        case "商品情報": Color(red: 0.43, green: 0.72, blue: 1.0)
        case "カードリスト": Color(red: 0.48, green: 0.87, blue: 0.62)
        case "大会", "イベント": Color(red: 1.0, green: 0.74, blue: 0.42)
        case "ルール": Color(red: 0.85, green: 0.64, blue: 1.0)
        case "デッキレシピ": Color(red: 1.0, green: 0.56, blue: 0.67)
        default: .secondary
        }
    }
}

/// 常用牌組快速列——使用者在「牌組」分頁左滑釘選，最想順手開的幾副牌組
/// 就不用再多切一次分頁、多找一次。放在輪播上面，因為這是「我自己的東西」，
/// 每次開 App 大概都想先看一眼，比官網公告更優先。
private struct PinnedDecksRow: View {
    let decks: [Deck]
    let database: CardDatabase
    let onSelect: (Deck) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text("常用牌組")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, Spacing.s16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s12) {
                    ForEach(decks) { deck in
                        Button { onSelect(deck) } label: {
                            PinnedDeckCard(deck: deck, database: database)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.s16)
            }
        }
    }
}

private struct PinnedDeckCard: View {
    let deck: Deck
    let database: CardDatabase

    var body: some View {
        let cover = deck.coverPrinting(database: database)
        HStack(spacing: Spacing.s12) {
            Group {
                if let cover {
                    CardImageView(printing: cover, cardName: deck.name)
                        .frame(width: 44)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.08))
                        .frame(width: 44, height: 61)
                        .overlay {
                            Image(systemName: "rectangle.stack")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(deck.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(deck.totalCount) 張")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(Spacing.s12)
        .frame(width: 168, alignment: .leading)
        .background(AppSurface.panel, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

/// 首頁最上方的大圖輪播——參考官網首頁「最新商品」跑馬燈：整張商品視覺圖
/// 滿版顯示、左右滑動切換、底部疊標題跟日期，比純文字列表更能一眼抓住
/// 「現在有什麼新東西」
private struct HeroCarousel: View {
    let items: [WSNewsItem]
    let categoryColor: (String) -> Color
    let onSelect: (WSNewsItem) -> Void
    @State private var index = 0

    var body: some View {
        VStack(spacing: Spacing.s12) {
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    HeroSlide(item: item, accent: item.categories.first.map(categoryColor) ?? .white) {
                        onSelect(item)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 224)

            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? .white : .white.opacity(0.28))
                            .frame(width: i == index ? 16 : 6, height: 6)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: index)
            }
        }
    }
}

private struct HeroSlide: View {
    let item: WSNewsItem
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                PolicyGatedRemoteImage(urlString: item.imageURL)
                LinearGradient(colors: [.clear, .clear, .black.opacity(0.55), .black.opacity(0.92)],
                               startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: Spacing.s8) {
                    HStack(spacing: Spacing.s4) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(accent)
                            .frame(width: 6, height: 6)
                            .rotationEffect(.degrees(45))
                            .shadow(color: accent.opacity(0.8), radius: 4)
                        Text(item.categories.first ?? "")
                            .font(.caption2.weight(.heavy))
                            .tracking(0.4)
                        Spacer()
                        Text(item.date.replacingOccurrences(of: "-", with: "."))
                            .font(.caption2.weight(.bold).monospacedDigit())
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    Text(item.displayTitle)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                }
                .padding(Spacing.s16)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
            .padding(.horizontal, Spacing.s16)
        }
        .buttonStyle(.plain)
    }
}
