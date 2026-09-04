import Observation
import Foundation

/// 使用者手動釘選到首頁的常用牌組，不是依開牌次數自動排序——「順手」是
/// 使用者自己說了算，程式不用猜。存的是 Deck.uuid 的字串，保留釘選順序
/// （後釘選的排後面），跟 FavoriteTitlesStore 存 titleCode 是同一套模式。
@Observable
@MainActor
final class PinnedDecksStore {
    private static let key = "pinnedDeckUUIDs"

    private(set) var uuids: [String]

    init() {
        uuids = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func isPinned(_ uuid: UUID) -> Bool { uuids.contains(uuid.uuidString) }

    func toggle(_ uuid: UUID) {
        let value = uuid.uuidString
        if let index = uuids.firstIndex(of: value) {
            uuids.remove(at: index)
        } else {
            uuids.append(value)
        }
        persist()
    }

    /// 牌組被刪除時一併清掉，不然首頁會留著指向不存在牌組的殘影
    func remove(_ uuid: UUID) {
        uuids.removeAll { $0 == uuid.uuidString }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(uuids, forKey: Self.key)
    }
}
