import Observation
import Foundation

/// 使用者收藏／持續關注的作品，對應圖鑑作品選單卡片右上角的星星。
/// 純粹是一組 titleCode，跟卡表資料本身無關——收藏的是「我對這部作品有興趣」，
/// 不是卡片持有狀態（那是 CollectionStore 的事）。
@Observable
@MainActor
final class FavoriteTitlesStore {
    private static let key = "favoriteTitleCodes"

    private(set) var titleCodes: Set<String>

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        titleCodes = Set(saved)
    }

    func isFavorite(_ titleCode: String) -> Bool {
        titleCodes.contains(titleCode)
    }

    func toggle(_ titleCode: String) {
        if titleCodes.contains(titleCode) {
            titleCodes.remove(titleCode)
        } else {
            titleCodes.insert(titleCode)
        }
        UserDefaults.standard.set(Array(titleCodes), forKey: Self.key)
    }

    /// 系列拆彈後，把「收藏了整個系列」展開成「底下每個商品都收藏」，
    /// 不然舊資料格式（純 titleCode）在拆彈後會對不到任何 BrowsableSet.id，
    /// 使用者原本收藏的東西就憑空消失了。
    ///
    /// 用商品代碼本身當有沒有跑過遷移的依據：遷移完 titleCodes 裡不會再留
    /// 下已經拆彈的裸 titleCode，天然冪等，不用另外開關記錄跑過沒。
    func migrate(using database: CardDatabase) {
        var updated = titleCodes
        var changed = false
        for code in titleCodes {
            let matches = database.browsableSets.filter { $0.titleCode == code }
            // 沒拆彈的作品只有 1 筆、id 就是 code 本身，不用動
            guard matches.count > 1 else { continue }
            updated.remove(code)
            updated.formUnion(matches.map(\.id))
            changed = true
        }
        guard changed else { return }
        titleCodes = updated
        UserDefaults.standard.set(Array(titleCodes), forKey: Self.key)
    }
}
