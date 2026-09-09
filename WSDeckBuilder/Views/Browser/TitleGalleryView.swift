import SwiftUI

/// 圖鑑的第一層：先選作品，再看卡。
///
/// 3400 多張卡一次全攤開沒人找得到東西，而使用者心裡的第一個問題幾乎都是
/// 「我要看哪部作品」。搜尋列仍在最上面，但這裡打字是在篩「作品」清單本身
/// （含容錯），不會直接跳去卡片結果——選作品跟找卡片刻意分成兩段搜尋。
struct TitleGalleryView: View {
    @Environment(\.appSurface) private var surface
    let sets: [BrowsableSet]
    let totalCount: Int
    /// 目前是否正在用關鍵字篩選作品；篩完是空的時候才顯示「沒有符合的作品」
    var isFiltering: Bool = false

    @Environment(FavoriteTitlesStore.self) private var favorites

    /// 卡多的作品排前面——會反覆翻的就是那幾部，照代號排等於隨機順序。
    /// 拆很多彈的作品（如 OVERLORD）另外併一張「不分彈」的卡片：只認得卡面、
    /// 不知道自己要找哪一彈的人，可以一次瀏覽整個系列，不用一彈一彈點進去找
    private var ordered: [BrowsableSet] {
        withCombinedEntries(sets).sorted { $0.cardCount > $1.cardCount }
    }

    private func withCombinedEntries(_ items: [BrowsableSet]) -> [BrowsableSet] {
        let grouped = Dictionary(grouping: items, by: \.titleCode)
        let combined: [BrowsableSet] = grouped.values.compactMap { group in
            guard group.count > 1, let sample = group.first else { return nil }
            return BrowsableSet(id: sample.titleCode, titleCode: sample.titleCode,
                                titleNameZH: sample.titleNameZH, titleNameJP: sample.titleNameJP,
                                cardCount: group.reduce(0) { $0 + $1.cardCount },
                                productCode: nil, waveLabel: "不分彈")
        }
        return items + combined
    }

    /// 收藏的作品獨立成一區釘在最上面；篩選中（在搜作品名）就不特別分區，
    /// 免得使用者在找別的作品時，收藏區塊硬插在結果中間打斷視線
    private var favoriteSets: [BrowsableSet] {
        guard !isFiltering else { return [] }
        return ordered.filter { favorites.isFavorite($0.id) }
    }

    private var otherSets: [BrowsableSet] {
        isFiltering ? ordered : ordered.filter { !favorites.isFavorite($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Text("探索作品")
                    .font(.largeTitle.bold())
                allCardsRow.padding(.top, Spacing.s4)
            }
            .padding(.horizontal, Spacing.s16)
            .padding(.bottom, Spacing.s24)
            if ordered.isEmpty, isFiltering {
                noMatchHint
                    .padding(.horizontal)
                    .padding(.top, Spacing.s32)
            } else {
                if !favoriteSets.isEmpty {
                    sectionHeader("已收藏")
                    grid(favoriteSets)
                        .padding(.bottom, Spacing.s16)
                    if !otherSets.isEmpty {
                        sectionHeader("所有作品")
                    }
                }
                if favoriteSets.isEmpty, !otherSets.isEmpty {
                    sectionHeader(isFiltering ? "符合的作品" : "所有作品")
                }
                grid(otherSets)
            }
            Color.clear.frame(height: 140)
        }
        .padding(.top, Spacing.s8)
        .scrollContentBackground(.hidden)
        .background(surface.background)
    }

    /// 篩不到符合的作品名稱時，還是留一條路到「不分作品瀏覽全部卡片」，
    /// 免得使用者以為卡表裡真的沒有這個東西
    private var noMatchHint: some View {
        VStack(spacing: Spacing.s8) {
            Image(systemName: "questionmark.folder")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("沒有符合的作品")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s24)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.s16)
            .padding(.bottom, Spacing.s8)
    }

    private func grid(_ items: [BrowsableSet]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: Spacing.s12)],
                  spacing: Spacing.s12) {
            ForEach(items) { set in
                NavigationLink(value: CatalogRoute.title(set.id)) {
                    tile(set)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.s16)
    }

    private func tile(_ set: BrowsableSet) -> some View {
        let color = TitlePalette.accent(for: set.titleCode)
        return VStack(alignment: .leading, spacing: Spacing.s4) {
            Text(set.titleNameZH)
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Spacing.s8)
            HStack(spacing: Spacing.s4) {
                Text(set.titleNameJP)
                    .font(.caption2)
                    .lineLimit(1)
                    .opacity(0.85)
                // 拆彈的官方彈次標籤（如「Vol.2」）獨立成小徽章，不跟標題文字
                // 擠在一起——之前直接接在標題後面，長一點的官方名稱會很難掃視
                if let wave = set.waveLabel {
                    Text(wave)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
            }
            Spacer(minLength: Spacing.s4 + 2)
            HStack(spacing: Spacing.s4) {
                Text("\(set.cardCount) 張")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.primary.opacity(0.65))
                Spacer(minLength: 0)
                Button { favorites.toggle(set.id) } label: {
                    Image(systemName: favorites.isFavorite(set.id) ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(favorites.isFavorite(set.id) ? .yellow : Color.primary.opacity(0.55))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(favorites.isFavorite(set.id) ? "取消收藏\(set.titleNameZH)" : "收藏\(set.titleNameZH)")
            }

        }
        .foregroundStyle(Color.primary)
        // 卡片內距至少 16px——原本 12px 在小螢幕上文字幾乎貼著邊
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 140, alignment: .topLeading)
        .background {
            ZStack {
                LinearGradient(colors: [surface.panelElevated, surface.panel],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(colors: [color.opacity(0.08), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        // 讓色塊像「疊在背景上的卡片」而不是畫在背景裡的色塊
        .comfortShadow(.card)
    }

    /// 跨作品搜尋入口放在清單前，不必捲過所有作品。
    private var allCardsRow: some View {
        NavigationLink(value: CatalogRoute.allCards) {
            HStack {
                Image(systemName: "square.stack.3d.up")
                Text("全部卡片")
                Spacer()
                Text("\(totalCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
            .padding(.horizontal, Spacing.s16)
            .padding(.vertical, Spacing.s12)
            .background(surface.panel,
                        in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                    .strokeBorder(surface.hairline, lineWidth: 1)
            }
            .comfortShadow(.card)
        }
        .buttonStyle(.plain)
    }
}
