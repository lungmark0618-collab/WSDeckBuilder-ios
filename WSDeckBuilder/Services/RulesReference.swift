import Foundation

/// 規則問答要餵給 AI 的背景資料——使用者之後會提供整理好的規則文件，
/// 屆時把檔案加進 Assets/Resources 資料夾、檔名對上 `resourceName` 即可，
/// 不用再改程式碼。找不到檔案時回傳 nil，規則問答退化成只靠 AI 自己的知識回答
/// （UI 上要提醒使用者這種情況答案不保證準確）。
enum RulesReference {
    private static let resourceName = "WSRules"
    private static let resourceExtension = "md"

    static var text: String? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text
    }

    static var isAvailable: Bool { text != nil }
}
