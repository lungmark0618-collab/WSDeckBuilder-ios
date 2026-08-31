import Foundation
import Observation

/// 開發者想跟使用者說的一則話：這次更新了什麼、有什麼要分享的
struct Announcement: Codable, Identifiable, Equatable {
    let id: String
    let date: String
    let title: String
    let body: String
}

private struct AnnouncementFeed: Decodable {
    let schemaVersion: Int
    let items: [Announcement]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case items
    }
}

/// 鈴鐺右上角要顯示數字還是紅點，使用者自己在設定裡選
enum NotificationBadgeStyle: String, CaseIterable, Identifiable {
    case dot, count
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dot: "紅點"
        case .count: "數字"
        }
    }
}

/// 通知中心：讀取開發者發佈的通知、記錄已讀狀態、算未讀數。
///
/// 內容跟卡表走同一條線——同一個資料 repo 裡多一份 `announcements.json`，
/// 開發者要發通知就編輯那個檔案 push，不用重新上架 App（§4.4.8 的姊妹機制）。
@Observable
@MainActor
final class AnnouncementCenter {
    static let supportedSchemaVersion = 1

    /// 跟卡表 manifest 同一個 repo，理由一樣：raw 走 CDN、約快取 5 分鐘。
    static let feedURL = URL(string: "https://raw.githubusercontent.com"
        + "/lungmark0618-collab/WSDeckBuilder-data/main/announcements.json")!

    /// 伺服器發的（開發者手動寫的公告）
    private(set) var serverItems: [Announcement] = []
    /// 本機自己產生的（偵測到卡表更新／新作品時合成的通知，見 noteDataUpdates）
    private(set) var localItems: [Announcement] = []

    /// 兩邊合併、按日期排序、濾掉使用者刪過的，畫面只認這個，不分來源
    var items: [Announcement] {
        (serverItems + localItems)
            .filter { !deletedIDs.contains($0.id) }
            .sorted { $0.date > $1.date }
    }

    var badgeStyle: NotificationBadgeStyle {
        didSet { UserDefaults.standard.set(badgeStyle.rawValue, forKey: Self.badgeStyleKey) }
    }

    private var readIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(readIDs), forKey: Self.readIDsKey) }
    }

    /// 使用者手動刪除過的通知——不管伺服器端或本機合成的通知，刪掉就是
    /// 從列表消失，就算之後重新查一次公告 feed 也不會再冒出來
    private var deletedIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(deletedIDs), forKey: Self.deletedIDsKey) }
    }

    var lastCheckedAt: Date? {
        didSet {
            UserDefaults.standard.set(lastCheckedAt?.timeIntervalSince1970,
                                      forKey: Self.checkedKey)
        }
    }

    var unreadCount: Int { items.filter { !readIDs.contains($0.id) }.count }

    private static let readIDsKey = "announcement.readIDs"
    private static let deletedIDsKey = "announcement.deletedIDs"
    private static let badgeStyleKey = "announcement.badgeStyle"
    private static let checkedKey = "announcement.lastCheckedAt"
    private static let cacheKey = "announcement.cachedItems"
    private static let localItemsKey = "announcement.localItems"

    init() {
        let defaults = UserDefaults.standard
        readIDs = Set(defaults.stringArray(forKey: Self.readIDsKey) ?? [])
        deletedIDs = Set(defaults.stringArray(forKey: Self.deletedIDsKey) ?? [])
        badgeStyle = NotificationBadgeStyle(rawValue: defaults.string(forKey: Self.badgeStyleKey) ?? "")
            ?? .dot
        let stamp = defaults.double(forKey: Self.checkedKey)
        lastCheckedAt = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        // 開場先用上次抓到的內容墊著，查更新是背景的事，不該讓鈴鐺先空著再彈出來
        if let cached = defaults.data(forKey: Self.cacheKey),
           let decoded = try? JSONDecoder().decode([Announcement].self, from: cached) {
            serverItems = decoded
        }
        if let cached = defaults.data(forKey: Self.localItemsKey),
           let decoded = try? JSONDecoder().decode([Announcement].self, from: cached) {
            localItems = decoded
        }
    }

    func isUnread(_ item: Announcement) -> Bool { !readIDs.contains(item.id) }

    func markAllRead() {
        readIDs.formUnion(items.map(\.id))
    }

    /// 看完想清掉就刪，不用留著——刪除是永久的，之後同一則（同 id）不會再出現
    func delete(_ item: Announcement) {
        deletedIDs.insert(item.id)
    }

    func delete(ids: some Sequence<String>) {
        deletedIDs.formUnion(ids)
    }

    /// 左上角「全部刪除」，一次清光目前看得到的所有通知
    func deleteAll() {
        deletedIDs.formUnion(items.map(\.id))
    }

    // MARK: - 查詢

    /// 啟動時靜默呼叫，一天查一次，查不到就沿用快取（跟 DataUpdater.checkSilently 同款）
    func checkSilently() async {
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < 86_400 { return }
        guard NetworkPolicy.shared.allowsAutomaticDownload else { return }
        await check()
    }

    func check() async {
        do {
            var request = URLRequest(url: Self.feedURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return
            }
            let feed = try JSONDecoder().decode(AnnouncementFeed.self, from: data)
            guard feed.schemaVersion <= Self.supportedSchemaVersion else { return }
            serverItems = feed.items.sorted { $0.date > $1.date }
            lastCheckedAt = Date()
            if let encoded = try? JSONEncoder().encode(serverItems) {
                UserDefaults.standard.set(encoded, forKey: Self.cacheKey)
            }
        } catch {
            // 靜默失敗，沿用快取內容——通知不值得為了查不到而跳錯誤打擾使用者
        }
    }

    // MARK: - 卡表更新／新作品通知

    /// 查完卡表更新後呼叫，把「有更新可裝」轉成通知列表裡的一則。
    /// 同一部作品同一個版本只會生一次通知——id 帶版本號，version 沒變就不重複，
    /// 版本真的往上跳了才會是新的一則、重新變成未讀。
    func noteDataUpdates(_ pending: [DataUpdater.Pending]) {
        var didAdd = false
        for item in pending {
            let id = "data-update-\(item.titleCode)-\(item.toVersion)"
            guard !localItems.contains(where: { $0.id == id }) else { continue }
            let isNewTitle = item.fromVersion == 0
            localItems.append(Announcement(
                id: id,
                date: Self.dateFormatter.string(from: .now),
                title: isNewTitle ? "新增了「\(item.titleName)」" : "「\(item.titleName)」卡表已更新",
                body: isNewTitle
                    ? "可以在圖鑑分頁看到這部新收錄的作品。"
                    : "有新的翻譯或卡片內容，到設定頁按「檢查更新」即可下載。"
            ))
            didAdd = true
        }
        guard didAdd else { return }
        localItems.sort { $0.date > $1.date }
        if let encoded = try? JSONEncoder().encode(localItems) {
            UserDefaults.standard.set(encoded, forKey: Self.localItemsKey)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
