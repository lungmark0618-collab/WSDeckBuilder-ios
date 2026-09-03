import SwiftUI

/// App 開啟後第一眼看到的畫面：官網公告（新商品、卡表更新、大會、規則異動），
/// 取代原本開場就是圖鑑的安排——這是使用者主動要求的首頁。
struct HomeView: View {
    @Environment(WSNewsService.self) private var news

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
                        LazyVStack(spacing: Spacing.s12) {
                            if let errorMessage = news.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, Spacing.s4)
                            }
                            ForEach(news.items) { item in
                                Link(destination: URL(string: item.url) ?? URL(string: "https://ws-tcg.com")!) {
                                    row(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.s16)
                        .padding(.top, Spacing.s8)
                        .padding(.bottom, 140)
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppSurface.background)
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
        }
    }

    private func row(_ item: WSNewsItem) -> some View {
        let accent = item.categories.first.map(categoryColor) ?? .secondary
        return HStack(spacing: 0) {
            // 左側色條標出這則公告的分類，掃視列表時比純文字色塊更容易一眼區分
            accent.opacity(0.85)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: Spacing.s8) {
                HStack(spacing: Spacing.s8) {
                    ForEach(item.categories, id: \.self) { category in
                        Text(category)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, Spacing.s8)
                            .padding(.vertical, 3)
                            .background(categoryColor(category).opacity(0.16), in: Capsule())
                            .foregroundStyle(categoryColor(category))
                    }
                    Spacer(minLength: Spacing.s8)
                    Text(item.date)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(item.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Spacing.s12)
            .padding(.leading, Spacing.s12)
            Spacer(minLength: Spacing.s8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.trailing, Spacing.s12)
        }
        .background(AppSurface.panel)
        .clipShape(RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                .strokeBorder(AppSurface.hairline, lineWidth: 1)
        }
        .comfortShadow(.card)
    }

    /// 純粹視覺分類，跟官網分類文字用簡單對照，沒對到的一律灰色
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
}
