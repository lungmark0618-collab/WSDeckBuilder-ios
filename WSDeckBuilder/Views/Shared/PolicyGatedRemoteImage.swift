import SwiftUI

/// 任意遠端圖片（首頁輪播、公告詳情大圖），跟卡圖一樣受「省流量」網路政策
/// 約束，行動網路下預設不自動下載、點一下佔位圖才強制載入。跟 CardImageView
/// 不同的是這裡沒有 Printing 可查磁碟快取，純粹是 AsyncImage + 政策開關。
struct PolicyGatedRemoteImage: View {
    let urlString: String?
    /// .fill 裁切填滿（首頁輪播的官網橫幅圖，本來就接近畫框比例，裁了也自然）；
    /// .fit 完整顯示不裁切（公告詳情頁的商品包裝圖——這些圖官網來源有正方形
    /// 也有長方形，比例不一，裁切填滿常常把包裝上的字或圖案切掉一半，
    /// 使用者反映「圖片位置跑掉」就是這個）
    var contentMode: ContentMode = .fill
    @State private var forceLoad = false

    var body: some View {
        GeometryReader { proxy in
            if let urlString, let url = URL(string: urlString),
               NetworkPolicy.shared.allowsAutomaticDownload || forceLoad {
                ZStack {
                    placeholder
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: contentMode)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
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
