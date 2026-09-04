import SwiftUI

/// 公告詳情：先讓使用者看重點（規格重點或至少標題／分類／日期），
/// 有興趣才點下面的按鈕去官網看完整內容——不是點一下就直接跳出 App。
struct NewsDetailSheet: View {
    let item: WSNewsItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s24) {
                    if let imageURL = item.bestImageURL {
                        // 商品包裝圖官網來源正方形、長方形都有，用 .fit 完整顯示
                        // 不裁切——裁切填滿常常把包裝上的字或圖案切掉一半
                        PolicyGatedRemoteImage(urlString: imageURL, contentMode: .fit)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                                    .strokeBorder(AppSurface.hairline, lineWidth: 1)
                            }
                    }
                    header
                    if !item.highlightsZH.isEmpty {
                        highlightsCard
                    } else {
                        noHighlightsHint
                    }
                    linkButton
                }
                .padding(Spacing.s16)
            }
            .background(AppSurface.background)
            .navigationTitle("公告詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(spacing: Spacing.s8) {
                ForEach(item.categories, id: \.self) { category in
                    Text(NewsCategory.labelZH(category))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, Spacing.s8)
                        .padding(.vertical, 3)
                        .background(NewsCategory.color(category).opacity(0.16), in: Capsule())
                        .foregroundStyle(NewsCategory.color(category))
                }
                Spacer(minLength: Spacing.s8)
                Text(item.date)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(item.displayTitle)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text("重點整理")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Spacing.s8) {
                ForEach(item.highlightsZH, id: \.self) { line in
                    HStack(alignment: .top, spacing: Spacing.s8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurface.panel, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                .strokeBorder(AppSurface.hairline, lineWidth: 1)
        }
    }

    /// 規則更新、賽事公告這類抓不到規格表的公告，老實說沒有重點可以整理，
    /// 不硬湊內容，直接請使用者去官網看
    private var noHighlightsHint: some View {
        HStack(spacing: Spacing.s8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("這則公告沒有可摘要的規格資訊，詳細內容請至官網查看。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurface.panel, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
    }

    private var linkButton: some View {
        Link(destination: URL(string: item.url) ?? URL(string: "https://ws-tcg.com")!) {
            HStack {
                Image(systemName: "safari")
                Text("前往官網查看完整內容")
                Spacer()
                Image(systemName: "arrow.up.right")
            }
        }
        .buttonStyle(.filled)
    }
}
