import SwiftUI

/// 官網公告分類——原始值是日文（跟官網 HTML 一致，篩選記錄跟著用這個當 key
/// 才穩定，不會因為顯示文字改版而失效），顯示一律轉繁中。
enum NewsCategory {
    /// 官網公告目前會出現的所有分類，順序即篩選畫面顯示順序
    static let all = ["商品情報", "カードリスト", "ルール", "デッキレシピ", "大会", "イベント", "お知らせ"]

    static func labelZH(_ raw: String) -> String {
        switch raw {
        case "商品情報": "商品資訊"
        case "カードリスト": "卡表"
        case "ルール": "規則"
        case "デッキレシピ": "牌組配方"
        case "大会": "大會"
        case "イベント": "活動"
        case "お知らせ": "公告"
        default: raw
        }
    }

    /// 卡角燙金色塊、寶石標記共用的飽和色
    static func color(_ category: String) -> Color {
        switch category {
        case "商品情報": .blue
        case "カードリスト": .green
        case "大会", "イベント": .orange
        case "ルール": .purple
        case "デッキレシピ": .pink
        default: .secondary
        }
    }

    /// 分類文字用的淺色調，飽和色直接當文字色在深底上太刺眼
    static func tint(_ category: String) -> Color {
        switch category {
        case "商品情報": Color(red: 0.43, green: 0.72, blue: 1.0)
        case "カードリスト": Color(red: 0.48, green: 0.87, blue: 0.62)
        case "大会", "イベント": Color(red: 1.0, green: 0.74, blue: 0.42)
        case "ルール": Color(red: 0.85, green: 0.64, blue: 1.0)
        case "デッキレシピ": Color(red: 1.0, green: 0.56, blue: 0.67)
        default: .secondary
        }
    }
}
