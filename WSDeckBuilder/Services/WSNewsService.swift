import Foundation
import Observation

/// 官網公告一則：新商品、卡表更新、大會、規則異動——見
/// WSDeckBuilder-data/tools/fetch_ws_news.py 產生的 ws_news.json
struct WSNewsItem: Codable, Identifiable, Hashable {
    let date: String          // "2026-09-01"
    let categories: [String]
    let titleJP: String
    let titleZH: String?
    let url: String
    let source: String        // "official" | "manual"
    /// 商品公告才有的規格重點（發售日、售價、卡片種類數），從官網商品頁的
    /// 規格表抓來的事實資訊，不是公告全文的翻譯——見 WSDeckBuilder-data
    /// 的 tools/enrich_ws_news.py。沒有值就代表這則公告沒有結構化規格可抓
    /// （規則更新、賽事公告等），詳情頁只會顯示標題跟官網連結
    let highlightsZH: [String]
    /// 首頁輪播用的縮圖，不是每則都有——沒配圖的公告就不會出現在輪播裡
    let imageURL: String?
    /// 商品頁自己的大圖（包裝盒圖），比列表縮圖更清楚——只有商品類公告
    /// 才有，詳情頁優先用這張，沒有的話退回用列表縮圖
    let detailImageURL: String?

    var id: String { "\(date)-\(titleJP)-\(url)" }
    /// 有中文說明就顯示中文，沒有就顯示官方日文原文——不擅自翻譯，只顯示有把握的內容
    var displayTitle: String { titleZH ?? titleJP }
    /// 詳情頁該顯示的圖：優先用商品頁大圖，沒有就退回列表縮圖
    var bestImageURL: String? { detailImageURL ?? imageURL }

    enum CodingKeys: String, CodingKey {
        case date, categories, url, source
        case titleJP = "title_jp"
        case titleZH = "title_zh"
        case highlightsZH = "highlights_zh"
        case imageURL = "image_url"
        case detailImageURL = "detail_image_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        categories = try c.decode([String].self, forKey: .categories)
        titleJP = try c.decode(String.self, forKey: .titleJP)
        titleZH = try c.decodeIfPresent(String.self, forKey: .titleZH)
        url = try c.decode(String.self, forKey: .url)
        source = try c.decode(String.self, forKey: .source)
        highlightsZH = try c.decodeIfPresent([String].self, forKey: .highlightsZH) ?? []
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        detailImageURL = try c.decodeIfPresent(String.self, forKey: .detailImageURL)
    }

    init(date: String, categories: [String], titleJP: String, titleZH: String?,
         url: String, source: String, highlightsZH: [String] = [], imageURL: String? = nil,
         detailImageURL: String? = nil) {
        self.date = date
        self.categories = categories
        self.titleJP = titleJP
        self.titleZH = titleZH
        self.url = url
        self.source = source
        self.highlightsZH = highlightsZH
        self.imageURL = imageURL
        self.detailImageURL = detailImageURL
    }
}

/// 抓 WSDeckBuilder-data 發布的 ws_news.json，對應 iOS 端 DataUpdater／
/// AnnouncementCenter 同一套「線上抓、本機快取、離線也能看上次結果」的作法
@Observable
@MainActor
final class WSNewsService {
    private(set) var items: [WSNewsItem] = []
    private(set) var isLoading = false
    private(set) var lastCheckedAt: Date?
    private(set) var errorMessage: String?

    private static let url = URL(string:
        "https://raw.githubusercontent.com/lungmark0618-collab/WSDeckBuilder-data/main/ws_news.json")!
    private static var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ws_news_cache.json")
    }

    init() {
        loadCache()
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheFile),
              let decoded = try? JSONDecoder().decode([WSNewsItem].self, from: data) else { return }
        items = decoded
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: Self.url)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Feed.self, from: data)
            items = decoded.items
            errorMessage = nil
            lastCheckedAt = .now
            try? JSONEncoder().encode(decoded.items).write(to: Self.cacheFile)
        } catch {
            // 抓不到就沿用快取，不拿錯誤訊息打斷使用者——首頁的公告不是關鍵功能
            errorMessage = "抓不到最新公告，顯示的是上次快取的內容。"
        }
    }

    private struct Feed: Decodable {
        let items: [WSNewsItem]
    }
}
