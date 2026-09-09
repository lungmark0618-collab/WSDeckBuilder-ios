import SwiftUI

/// 篩選條件（§4.4.1：條件間 AND、同條件內 OR）
///
/// 滿版半透明疊層取代原本的系統 sheet——原本用 Form + 橫向捲動 chip 列，
/// 選項一多（尤其特徵）大半都藏在畫面外側滑才看得到，改成 FlowLayout
/// 自動換行、疊層佔滿整個螢幕，一次能攤開的空間也更大。
struct FilterSheet: View {
    @Environment(\.appSurface) private var surface
    @Binding var query: SearchQuery
    /// 畫面已經鎖定某部作品時藏起這一區——在這裡換作品，
    /// 標題和內容就會對不上
    var lockedTitle = false
    @Environment(CardDatabase.self) private var database
    @Environment(\.dismiss) private var dismiss

    /// 判定標誌、收錄來源用得比較少，預設摺起來，翻開的第一眼先讓
    /// 作品／等級／顏色／種類這些常用條件占滿版面
    @State private var showMoreFilters = false
    /// 只搜作品名稱，跟上層圖鑑那個搜卡號/卡名/能力文字的搜尋列是兩回事
    @State private var titleSearch = ""

    private var filteredSets: [BrowsableSet] {
        guard !titleSearch.isEmpty else { return database.browsableSets }
        return database.browsableSets.filter {
            $0.titleNameZH.localizedCaseInsensitiveContains(titleSearch) ||
            $0.titleNameJP.localizedCaseInsensitiveContains(titleSearch)
        }
    }

    /// 只有鎖定某部作品/商品（不論是畫面本來就鎖定，還是使用者在上面「作品」
    /// 區塊選了一個）才會列出來，且只列這個範圍出現過的特徵——全部特徵動輒
    /// 上百個，沒有範圍當限制乾脆整區不顯示，見 body 裡 `if query.titleCode != nil`
    private var availableTraits: [String] {
        guard let scope = query.titleCode else { return [] }
        return database.traits(inScope: scope)
    }

    private var traitsCardTitle: String {
        let name = query.titleCode.flatMap { scope in
            database.browsableSets.first(where: { $0.id == scope })?.displayNameZH
        }
        return name.map { "特徵（\($0)）" } ?? "特徵"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s24) {
                if !lockedTitle {
                    card("作品") {
                        VStack(alignment: .leading, spacing: Spacing.s8) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("搜尋作品名稱", text: $titleSearch)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                if !titleSearch.isEmpty {
                                    Button {
                                        titleSearch = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.s12)
                            .padding(.vertical, Spacing.s8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

                            FlowLayout(spacing: Spacing.s8) {
                                if titleSearch.isEmpty {
                                    titleChip(nil, label: "全部")
                                }
                                ForEach(filteredSets) { set in
                                    titleChip(set.id, label: set.displayNameZH)
                                }
                            }
                        }
                    }
                }
                multiSelectCard("等級", items: [0, 1, 2, 3], set: $query.levels) {
                    toggleFlow(items: [0, 1, 2, 3], set: $query.levels) { "Lv\($0)" }
                }
                multiSelectCard("顏色", items: CardColor.allCases, set: $query.colors) {
                    toggleFlow(items: CardColor.allCases, set: $query.colors) { $0.label }
                }
                multiSelectCard("種類", items: CardType.allCases, set: $query.types) {
                    toggleFlow(items: CardType.allCases, set: $query.types) { $0.label }
                }
                // 沒鎖定作品時特徵動輒上百個，乾脆整區不顯示——選了作品才彈出來，
                // 不用先看到一堆跨作品的標籤再等著被縮小範圍
                if query.titleCode != nil {
                    multiSelectCard(traitsCardTitle, items: availableTraits, set: $query.traits) {
                        toggleFlow(items: availableTraits, set: $query.traits) { "《\($0)》" }
                    }
                }
                card("我的收藏") {
                    VStack(alignment: .leading, spacing: Spacing.s8) {
                        Picker("收藏狀態", selection: $query.ownership) {
                            ForEach(OwnershipFilter.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("依「我的收藏」記錄的擁有張數篩選，可用來找還沒收到的卡。")
                            .font(.caption)
                            .foregroundStyle(surface.secondaryText)
                    }
                }

                moreFiltersDisclosure
            }
            .padding(Spacing.s16)
            .padding(.bottom, 140)
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .presentationBackground(.ultraThinMaterial)
    }

    private var topBar: some View {
        HStack {
            Button("全部清除") {
                let keyword = query.keyword
                query = SearchQuery(keyword: keyword)
            }
            .disabled(!query.hasActiveFilters)
            .font(.subheadline)

            Spacer()
            Text("篩選").font(.headline)
            Spacer()

            Button("完成") { dismiss() }
                .font(.subheadline.bold())
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.vertical, Spacing.s12)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var moreFiltersDisclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showMoreFilters.toggle() }
        } label: {
            HStack {
                Text("更多篩選（判定標誌、收錄來源）")
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: showMoreFilters ? "chevron.up" : "chevron.down")
                    .font(.caption.bold())
            }
            .foregroundStyle(.primary)
            .padding(Spacing.s16)
            .background(surface.panel, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                    .strokeBorder(surface.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)

        if showMoreFilters {
            multiSelectCard("判定標誌", items: TriggerIcon.allCases, set: $query.triggers) { triggerFlow }
            card("收錄來源") {
                Picker("來源", selection: $query.sourceOnly) {
                    Text("全部").tag(CardSource?.none)
                    ForEach(CardSource.allCases) { source in
                        Text(source.label).tag(CardSource?.some(source))
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    /// 統一的玻璃感卡片容器，取代原本 Form 的 Section
    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(surface.secondaryText)
            content()
        }
        .padding(Spacing.s16)
        .background(surface.panel, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                .strokeBorder(surface.hairline, lineWidth: 1)
        }
    }

    /// 多選 chip 群組的卡片：標題旁邊多一顆「全選／全部清除」——同一顆按鈕，
    /// 選滿了就變成「全部清除」，不是分開兩顆各自變灰
    private func multiSelectCard<T: Hashable>(_ title: String, items: [T],
                                               set: Binding<Set<T>>,
                                               @ViewBuilder content: () -> some View) -> some View {
        let allSelected = !items.isEmpty && set.wrappedValue.count == items.count
        return VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(surface.secondaryText)
                Spacer()
                Button(allSelected ? "全部清除" : "全選") {
                    set.wrappedValue = allSelected ? [] : Set(items)
                }
                .disabled(items.isEmpty)
            }
            .font(.caption)
            content()
        }
        .padding(Spacing.s16)
        .background(surface.panel, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                .strokeBorder(surface.hairline, lineWidth: 1)
        }
    }

    /// 作品 chip（單選）
    private func titleChip(_ code: String?, label: String) -> some View {
        let isOn = query.titleCode == code
        return Button {
            query.titleCode = code
        } label: {
            Text(label)
                .font(.callout)
                .padding(.horizontal, Spacing.s12)
                .padding(.vertical, 6)
                .background(isOn ? Color.accentColor : surface.panelElevated, in: Capsule())
                .foregroundStyle(isOn ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    /// 判定標誌 chips：顯示官方卡面圖示
    private var triggerFlow: some View {
        FlowLayout(spacing: Spacing.s8) {
            ForEach(TriggerIcon.allCases) { trigger in
                let isOn = query.triggers.contains(trigger)
                Button {
                    if isOn {
                        query.triggers.remove(trigger)
                    } else {
                        query.triggers.insert(trigger)
                    }
                } label: {
                    TriggerIconView(trigger: trigger, size: 20)
                        .padding(.horizontal, Spacing.s12)
                        .padding(.vertical, 6)
                        .background(isOn ? Color.accentColor : surface.panelElevated, in: Capsule())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 換行版多選 chip 列
    private func toggleFlow<T: Hashable>(items: [T],
                                         set: Binding<Set<T>>,
                                         label: @escaping (T) -> String) -> some View {
        FlowLayout(spacing: Spacing.s8) {
            ForEach(items, id: \.self) { item in
                let isOn = set.wrappedValue.contains(item)
                Button {
                    if isOn {
                        set.wrappedValue.remove(item)
                    } else {
                        set.wrappedValue.insert(item)
                    }
                } label: {
                    Text(label(item))
                        .font(.callout)
                        .padding(.horizontal, Spacing.s12)
                        .padding(.vertical, 6)
                        .background(isOn ? Color.accentColor : surface.panelElevated, in: Capsule())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
