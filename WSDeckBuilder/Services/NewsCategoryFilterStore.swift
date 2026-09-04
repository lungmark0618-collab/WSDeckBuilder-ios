import Foundation
import Observation

/// 使用者選擇「首頁不想看到哪些分類」——存的是要隱藏的分類（不是要顯示的），
/// 這樣官網以後多出新分類時，預設還是顯示，不會因為沒被列進白名單就悄悄消失。
@Observable
@MainActor
final class NewsCategoryFilterStore {
    private static let key = "hiddenNewsCategories"
    private(set) var hidden: Set<String>

    init() {
        hidden = Set(UserDefaults.standard.stringArray(forKey: Self.key) ?? [])
    }

    func isHidden(_ category: String) -> Bool { hidden.contains(category) }

    func toggle(_ category: String) {
        if hidden.contains(category) {
            hidden.remove(category)
        } else {
            hidden.insert(category)
        }
        UserDefaults.standard.set(Array(hidden), forKey: Self.key)
    }

    /// 一則公告只要還有任一分類沒被隱藏就顯示——公告常常同時掛好幾個分類，
    /// 全部被使用者關掉了才真的濾掉
    func isVisible(_ item: WSNewsItem) -> Bool {
        item.categories.isEmpty || !item.categories.allSatisfy { hidden.contains($0) }
    }
}
