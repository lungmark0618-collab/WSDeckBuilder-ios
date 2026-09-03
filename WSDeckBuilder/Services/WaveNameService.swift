import Foundation
import Observation

/// 拆彈作品每一彈的官方商品名稱標籤（如「Vol.2」「新装版」），對應
/// WSDeckBuilder-data/tools/make_wave_names.py 產生的 wave_names.json：
/// key 是 productCode（如 "SFN/S108"），value 是扣掉系列本名後剩下的部分，
/// 空字串代表「這彈就是官方原名，不用加標籤」。查不到的作品（該系列的
/// 官方名稱資料還不夠乾淨）就完全不會出現在這裡，CardDatabase 端會自動
/// 退回舊的「第一彈/第二彈」數字猜測法。
@Observable
@MainActor
final class WaveNameService {
    private(set) var labels: [String: String] = [:]

    private static let url = URL(string: "https://raw.githubusercontent.com"
        + "/lungmark0618-collab/WSDeckBuilder-data/main/wave_names.json")!
    private static var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wave_names_cache.json")
    }

    init() {
        loadCache()
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheFile),
              let decoded = try? JSONDecoder().decode(Feed.self, from: data) else { return }
        labels = decoded.waves
    }

    /// 回傳 true 代表拿到跟目前不一樣的新資料，呼叫端要重建圖鑑分類才看得到
    @discardableResult
    func refresh() async -> Bool {
        do {
            var request = URLRequest(url: Self.url)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Feed.self, from: data)
            let changed = decoded.waves != labels
            labels = decoded.waves
            try? data.write(to: Self.cacheFile)
            return changed
        } catch {
            // 抓不到就沿用快取／內建的數字猜測法，不用錯誤打斷使用者——
            // 這只是圖鑑分類標題的顯示細節，不是關鍵功能
            return false
        }
    }

    private struct Feed: Decodable {
        let waves: [String: String]
    }
}
