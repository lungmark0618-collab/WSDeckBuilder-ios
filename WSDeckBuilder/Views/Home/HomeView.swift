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
                    List {
                        if let errorMessage = news.errorMessage {
                            Section {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                        ForEach(news.items) { item in
                            Link(destination: URL(string: item.url) ?? URL(string: "https://ws-tcg.com")!) {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
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
        VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack(spacing: Spacing.s8) {
                ForEach(item.categories, id: \.self) { category in
                    Text(category)
                        .font(.caption2.bold())
                        .padding(.horizontal, Spacing.s8)
                        .padding(.vertical, 2)
                        .background(categoryColor(category).opacity(0.18), in: Capsule())
                        .foregroundStyle(categoryColor(category))
                }
                Spacer()
                Text(item.date)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(item.displayTitle)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, Spacing.s4)
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
