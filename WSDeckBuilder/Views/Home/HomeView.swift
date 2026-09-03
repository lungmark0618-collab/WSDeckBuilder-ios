import SwiftUI

/// App 開啟後第一眼看到的畫面：官網公告（新商品、卡表更新、大會、規則異動），
/// 取代原本開場就是圖鑑的安排——這是使用者主動要求的首頁。
struct HomeView: View {
    @Environment(WSNewsService.self) private var news
    // 點公告先看我們整理過的重點，不是直接跳出 App 到瀏覽器——
    // 有興趣看完整內容的人，詳情頁裡還有官網連結
    @State private var selectedItem: WSNewsItem?

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
                                Button {
                                    selectedItem = item
                                } label: {
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
        }
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
