import SwiftUI

/// 圖鑑的第一層：先選作品，再看卡。
///
/// 3400 多張卡一次全攤開沒人找得到東西，而使用者心裡的第一個問題幾乎都是
/// 「我要看哪部作品」。搜尋列仍在最上面，但這裡打字是在篩「作品」清單本身
/// （含容錯），不會直接跳去卡片結果——選作品跟找卡片刻意分成兩段搜尋。
struct TitleGalleryView: View {
    let sets: [BrowsableSet]
    let totalCount: Int
    /// 目前是否正在用關鍵字篩選作品；篩完是空的時候才顯示「沒有符合的作品」
    var isFiltering: Bool = false

    @Environment(FavoriteTitlesStore.self) private var favorites

    /// 卡多的作品排前面——會反覆翻的就是那幾部，照代號排等於隨機順序
    private var ordered: [BrowsableSet] {
        sets.sorted { $0.cardCount > $1.cardCount }
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
                grid(otherSets)
            }
            allCardsRow
                .padding(.horizontal, Spacing.s16)
                .padding(.top, Spacing.s12)
                // 加在內容最後一項底下——這是真的內容高度，不是縮小 ScrollView
                // 視窗；之前加在 ScrollView 外層會讓可捲動範圍算錯，直接卡死
                .padding(.bottom, 140)
        }
        .padding(.top, Spacing.s8)
        .scrollContentBackground(.hidden)
        .background(AppSurface.background)
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
            HStack(alignment: .top) {
                Text(set.displayNameZH)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: Spacing.s4)
                Button {
                    favorites.toggle(set.id)
                } label: {
                    Image(systemName: favorites.isFavorite(set.id) ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(favorites.isFavorite(set.id) ? .yellow : .white.opacity(0.7))
                        // 觸控範圍撐大到 44pt，不然一顆小星星在色塊右上角很難點準
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: Spacing.s8, y: -Spacing.s8)
            }
            Text(set.titleNameJP)
                .font(.caption2)
                .lineLimit(1)
                .opacity(0.85)
            Spacer(minLength: Spacing.s4 + 2)
            HStack(alignment: .firstTextBaseline) {
                Text(set.productCode ?? set.titleCode)
                    .font(.caption2.monospaced())
                    .opacity(0.8)
                Spacer(minLength: Spacing.s4)
                Text("\(set.cardCount)")
                    .font(.caption.bold().monospacedDigit())
            }
        }
        .foregroundStyle(.white)
        // 卡片內距至少 16px——原本 12px 在小螢幕上文字幾乎貼著邊
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 108, alignment: .topLeading)
        .background {
            ZStack {
                LinearGradient(colors: [color.opacity(0.96), color.opacity(0.62)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(colors: [.white.opacity(0.10), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        // 讓色塊像「疊在背景上的卡片」而不是畫在背景裡的色塊
        .comfortShadow(.card)
    }

    /// 不分作品瀏覽仍留一條路，只是不擺在最上面搶走「先選作品」的主線
    private var allCardsRow: some View {
        NavigationLink(value: CatalogRoute.allCards) {
            HStack {
                Image(systemName: "square.stack.3d.up")
                Text("不分作品瀏覽全部卡片")
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
            .background(AppSurface.panel,
                        in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                    .strokeBorder(AppSurface.hairline, lineWidth: 1)
            }
            .comfortShadow(.card)
        }
        .buttonStyle(.plain)
    }
}
