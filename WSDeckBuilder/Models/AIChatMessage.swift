import Foundation

/// 一句對話，使用者問的或 AI 答的（§ AI 問答功能）
struct AIChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    var text: String
    var isLoading: Bool = false
}

/// 這次提問要帶給 AI 的背景資訊——從卡片詳情頁開啟時自動帶入這張卡的資料，
/// 使用者不用自己打字描述是哪張卡
struct AICardContext: Equatable {
    let card: Card

    /// 組成餵給 AI 的卡片描述文字：中日文卡名、效果全文、數值、特徵
    var summary: String {
        var lines: [String] = []
        lines.append("卡名：\(card.nameZH)（\(card.nameJP)）")
        lines.append("卡號：\(card.id)")
        lines.append("類型：\(card.cardType.label)")
        if let color = card.color { lines.append("顏色：\(color.label)") }
        if let level = card.level { lines.append("等級：\(level)") }
        if let cost = card.cost { lines.append("花費：\(cost)") }
        if let power = card.power { lines.append("力量：\(power)") }
        if let soul = card.soul { lines.append("魂傷：\(soul)") }
        if let trigger = card.trigger { lines.append("觸發符號：\(trigger.label)") }
        if !card.traitsJP.isEmpty { lines.append("特徵：\(card.traitsJP.joined(separator: "／"))") }
        if !card.textZH.isEmpty {
            lines.append("效果文字（中文翻譯）：\n\(card.textZH)")
        }
        if !card.textJP.isEmpty {
            lines.append("效果文字（日文原文）：\n\(card.textJP)")
        }
        return lines.joined(separator: "\n")
    }
}
