import Observation
import Foundation

/// 朋友用系統相機（不是這個 App 內建的掃描功能）掃到分享出去的牌組 QR 時，
/// App 靠自訂 URL scheme 被喚起，這裡先接住待確認的內容，等使用者在預覽
/// 畫面裡按「加入牌組」才真的寫進資料庫——連結是外部觸發的，不該一開起來
/// 就自動建立，使用者應該先看到內容再決定。
@Observable
@MainActor
final class DeckImportCoordinator {
    var pending: DeckImporter.Parsed?
    var errorMessage: String?

    func handle(url: URL) {
        guard let parsed = DeckImageExporter.Payload.decode(url.absoluteString) else {
            errorMessage = "這個連結不是本 App 的牌組分享連結。"
            return
        }
        pending = parsed
    }
}
