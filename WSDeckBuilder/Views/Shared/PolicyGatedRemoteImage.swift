import SwiftUI

/// 任意遠端圖片（首頁輪播、公告詳情大圖），跟卡圖一樣受「省流量」網路政策
/// 約束，行動網路下預設不自動下載、點一下佔位圖才強制載入。跟 CardImageView
/// 不同的是這裡沒有 Printing 可查磁碟快取，純粹是 AsyncImage + 政策開關。
struct PolicyGatedRemoteImage: View {
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
