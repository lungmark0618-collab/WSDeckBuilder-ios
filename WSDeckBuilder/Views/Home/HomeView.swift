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
                        VStack(spacing: Spacing.s16) {
                            if !heroItems.isEmpty {
                                HeroCarousel(items: heroItems, categoryColor: categoryColor(_:)) {
                                    selectedItem = $0
                                }
                                .padding(.top, Spacing.s8)
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
        }
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
                HeroImage(urlString: item.imageURL)
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

/// 輪播用的滿版圖片，跟卡圖一樣受「省流量」網路政策約束，行動網路下
/// 預設不自動下載、點一下佔位圖才強制載入
private struct HeroImage: View {
    let urlString: String?
    @State private var forceLoad = false

    var body: some View {
        GeometryReader { proxy in
            if let urlString, let url = URL(string: urlString),
               NetworkPolicy.shared.allowsAutomaticDownload || forceLoad {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            } else {
                Button { forceLoad = true } label: {
                    ZStack {
                        placeholder
                        VStack(spacing: Spacing.s4) {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            Text("省流量，點一下載入圖片")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var placeholder: some View {
        Rectangle().fill(AppSurface.panel)
    }
}
