import SwiftData
import SwiftUI

/// App 開啟後第一眼看到的畫面：官網公告（新商品、卡表更新、大會、規則異動），
/// 取代原本開場就是圖鑑的安排——這是使用者主動要求的首頁。
struct HomeView: View {
    @Environment(\.appSurface) private var surface
    @Environment(WSNewsService.self) private var news
    @Environment(CardDatabase.self) private var database
    @Environment(PinnedDecksStore.self) private var pinnedDecks
    @Environment(NewsCategoryFilterStore.self) private var categoryFilter
    @Query private var allDecks: [Deck]
    // 點公告先看我們整理過的重點，不是直接跳出 App 到瀏覽器——
    // 有興趣看完整內容的人，詳情頁裡還有官網連結
    @State private var selectedItem: WSNewsItem?
    /// 點常用牌組直接用 sheet 開詳情，不用切去「牌組」分頁再找一次——
    /// 這正是「釘選到首頁」要省下來的那一步
    @State private var selectedDeck: Deck?
    @State private var showingCategoryFilter = false
    /// 搜尋「最新動態」用的關鍵字——比對標題（中日文）跟商品規格重點
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s32) {
                    // 搜尋中就只顯示比對結果，把常用牌組收起來——
                    // 這一區跟關鍵字無關，留著只會讓人分心找不到搜尋結果在哪
                    if !isSearching {
                        if !pinnedDecksOrdered.isEmpty {
                            PinnedDecksRow(decks: pinnedDecksOrdered, database: database) {
                                selectedDeck = $0
                            }
                        }
                        if !heroItems.isEmpty {
                            HeroCarousel(items: heroItems, isEnabled: selectedItem == nil && selectedDeck == nil && !showingCategoryFilter) { selectedItem = $0 }
                        }
                    }
                    VStack(alignment: .leading, spacing: Spacing.s12) {
                        sectionHeading(isSearching ? "搜尋結果" : "最新動態", subtitle: nil)
                            .onboardingAnchor(.homeIntro)
                        if news.isLoading, news.items.isEmpty {
                            ProgressView("正在取得最新消息…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.s32)
                        } else if filteredItems.isEmpty {
                            ContentUnavailableView {
                                Label(isSearching ? "沒有符合的消息"
                                      : (news.items.isEmpty ? "暫時沒有消息" : "沒有符合的公告"),
                                      systemImage: isSearching ? "magnifyingglass" : "newspaper")
                            } description: {
                                Text(isSearching ? "換個關鍵字試試，或確認分類篩選有沒有把它藏起來。"
                                     : (news.errorMessage ?? (news.items.isEmpty
                                        ? "下拉重新整理，稍後再來看看。"
                                        : "目前的分類已隱藏所有公告，可以調整篩選。")))
                            } actions: {
                                if isSearching {
                                    EmptyView()
                                } else if !news.items.isEmpty {
                                    Button("調整分類") { showingCategoryFilter = true }
                                        .buttonStyle(.tonal)
                                } else {
                                    Button("重新載入") { Task { await news.refresh() } }
                                        .buttonStyle(.tonal)
                                }
                            }
                        } else {
                            LazyVStack(spacing: 0) {
                                if let errorMessage = news.errorMessage {
                                    Label(errorMessage, systemImage: "wifi.exclamationmark")
                                        .font(.footnote)
                                        .foregroundStyle(.orange)
                                }
                                ForEach(filteredItems) { item in
                                    Button { selectedItem = item } label: { row(item) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Spacing.s16)
                        }
                    }
                }
                .padding(.top, Spacing.s16)
                .padding(.bottom, 140)
            }
            .background(surface.background.ignoresSafeArea())
            .navigationTitle("首頁")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜尋最新動態")
            .refreshable { await news.refresh() }
            .task {
                await news.refresh(force: false)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SidebarMenuButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.s4) {
                        Button {
                            showingCategoryFilter = true
                        } label: {
                            Image(systemName: categoryFilter.hidden.isEmpty
                                  ? "line.3.horizontal.decrease.circle"
                                  : "line.3.horizontal.decrease.circle.fill")
                        }
                        NotificationBellButton()
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                NewsDetailSheet(item: item)
            }
            .sheet(item: $selectedDeck) { deck in
                NavigationStack {
                    DeckDetailView(deck: deck)
                }
                .swipeToGoBack()
            }
            .sheet(isPresented: $showingCategoryFilter) {
                NewsCategoryFilterSheet(store: categoryFilter)
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 套用使用者的分類篩選，再疊上關鍵字搜尋，
    /// 比對標題（中日文）跟商品規格重點，不比對分類標籤本身
    private var filteredItems: [WSNewsItem] {
        let categoryFiltered = news.items.filter { categoryFilter.isVisible($0) }
        guard isSearching else { return categoryFiltered }
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        return categoryFiltered.filter { item in
            item.titleZH?.localizedCaseInsensitiveContains(keyword) == true
                || item.titleJP.localizedCaseInsensitiveContains(keyword)
                || item.highlightsZH.contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
    }

    /// 依釘選順序排出實際存在的牌組——牌組被刪掉但清理沒跑到的殘影
    /// （理論上不會發生，PinnedDecksStore.remove 已經在刪牌組時呼叫，
    /// 這裡只是多一層防呆）就自然濾掉，不會顯示空卡片
    private var pinnedDecksOrdered: [Deck] {
        let byUUID = Dictionary(uniqueKeysWithValues: allDecks.map { ($0.uuid.uuidString, $0) })
        return pinnedDecks.uuids.compactMap { byUUID[$0] }
    }

    private var heroItems: [WSNewsItem] {
        filteredItems
            .filter { $0.imageURL != nil && $0.categories.contains("商品情報") }
            .prefix(6)
            .map { $0 }
    }

    private func sectionHeading(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            if let subtitle {
                Text(subtitle).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            }
            Text(title).font(subtitle == nil ? .title2.bold() : .largeTitle.bold())
                .tracking(-0.6)
        }
        .padding(.horizontal, Spacing.s24)
    }

    private func row(_ item: WSNewsItem) -> some View {
        HStack(spacing: Spacing.s16) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Text(item.categories.map(NewsCategory.labelZH).joined(separator: " · "))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(item.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.94))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.date.replacingOccurrences(of: "-", with: "."))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.s8)
        .padding(.vertical, Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(surface.hairline).frame(height: 0.5)
                .padding(.horizontal, Spacing.s8)
        }
    }

}

/// 常用牌組快速列——使用者在「牌組」分頁左滑釘選，最想順手開的幾副牌組
/// 就不用再多切一次分頁、多找一次。放在最新動態上面，因為這是「我自己的東西」，
/// 每次開 App 大概都想先看一眼，比官網公告更優先。
private struct PinnedDecksRow: View {
    let decks: [Deck]
    let database: CardDatabase
    let onSelect: (Deck) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text("常用牌組")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.primary.opacity(0.7))
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
    @Environment(\.appSurface) private var surface
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
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 44, height: 61)
                        .overlay {
                            Image(systemName: "rectangle.stack")
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(deck.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text("\(deck.totalCount) 張")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.primary.opacity(0.55))
            }
        }
        .padding(Spacing.s12)
        .frame(width: 168, alignment: .leading)
        .background(surface.panel, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

/// 保留商品大圖輪播，輪播上方不再放額外宣傳標題。
private struct HeroCarousel: View {
    @Environment(\.appSurface) private var surface
    let items: [WSNewsItem]
    var isEnabled = true
    let onSelect: (WSNewsItem) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var progress: CGFloat = 0
    @State private var index = 0

    private struct PlaybackKey: Equatable {
        let index: Int
        let active: Bool
        let itemIDs: [String]
    }
    @ScaledMetric(relativeTo: .title3) private var captionHeight = 144

    var body: some View {
        VStack(spacing: Spacing.s12) {
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    HeroSlide(item: item) { onSelect(item) }.tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220 + captionHeight)
            .simultaneousGesture(DragGesture(minimumDistance: 4).updating($isDragging) { _, dragging, _ in
                dragging = true
            })
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        Capsule()
                            .fill(Color.primary.opacity(0.20))
                            .overlay(alignment: .leading) {
                                if i == index {
                                    Rectangle().fill(Color.primary)
                                        .frame(width: 28 * progress)
                                }
                            }
                            .frame(width: i == index ? 28 : 6, height: 6)
                            .clipShape(Capsule())
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("第 \(index + 1) 張，共 \(items.count) 張")
            }
        }
        .onChange(of: items.map(\.id)) { _, _ in index = 0 }
        .task(id: PlaybackKey(index: index,
                              active: isEnabled && scenePhase == .active && !isDragging,
                              itemIDs: items.map(\.id))) {
            progress = 0
            guard isEnabled, scenePhase == .active, !isDragging, items.count > 1 else { return }
            let clock = ContinuousClock()
            let start = clock.now
            do {
                while progress < 1 {
                    try await Task.sleep(for: .milliseconds(30))
                    try Task.checkCancellation()
                    let elapsed = start.duration(to: clock.now).components
                    let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                    progress = min(1, CGFloat(seconds / 6))
                }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    index = (index + 1) % items.count
                }
            } catch { /* 離頁、切到背景或手動滑動時取消，重新進場再計時。 */ }
        }
    }
}

private struct HeroSlide: View {
    @Environment(\.appSurface) private var surface
    let item: WSNewsItem
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PolicyGatedRemoteImage(urlString: item.imageURL, contentMode: .fit)
                .frame(height: 220)
                .onTapGesture(perform: onTap)
                .accessibilityLabel("商品圖片")
            Button(action: onTap) {
                HStack(spacing: Spacing.s16) {
                    VStack(alignment: .leading, spacing: Spacing.s8) {
                        Text("商品資訊")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(item.displayTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .padding(Spacing.s24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(surface.panel)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(surface.hairline, lineWidth: 0.5)
        }
        .padding(.horizontal, Spacing.s24)
    }
}

/// 首頁公告分類篩選——關掉不想看的分類，消息列表會跟著篩選
private struct NewsCategoryFilterSheet: View {
    let store: NewsCategoryFilterStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(NewsCategory.all, id: \.self) { category in
                    Button {
                        store.toggle(category)
                    } label: {
                        HStack {
                            HStack(spacing: Spacing.s8) {
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(NewsCategory.color(category))
                                    .frame(width: 8, height: 8)
                                    .rotationEffect(.degrees(45))
                                Text(NewsCategory.labelZH(category))
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            if !store.isHidden(category) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("篩選首頁公告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 同一顆按鈕：全部隱藏時顯示「全選」，全部顯示時變成「全部清除」
                    Button(store.hidden.count == NewsCategory.all.count ? "全選" : "全部清除") {
                        if store.hidden.count == NewsCategory.all.count {
                            store.showAll()
                        } else {
                            store.hideAll(NewsCategory.all)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .swipeToGoBack()
    }
}
