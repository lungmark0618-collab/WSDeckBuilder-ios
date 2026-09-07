import Foundation

/// AI 問答的後端接口——目前後端還沒定案（可能自架服務、也可能使用者自己貼
/// API Key），先用這個 protocol 把「怎麼問」跟「怎麼答」隔開，UI／資料組裝
/// 邏輯可以先做，之後接真的服務只要換掉 MockAIAssistantService
protocol AIAssistantService {
    /// history 不含這次的新問題；cardContext／rulesContext 都是可選的背景資訊
    func ask(question: String,
             history: [AIChatMessage],
             cardContext: AICardContext?,
             rulesContext: String?) async throws -> String
}

/// 開發階段先用假回覆讓聊天流程（輸入、送出、載入中、氣泡顯示）能先做出來，
/// 之後決定好後端接法再換掉這個實作
struct MockAIAssistantService: AIAssistantService {
    func ask(question: String,
             history: [AIChatMessage],
             cardContext: AICardContext?,
             rulesContext: String?) async throws -> String {
        try await Task.sleep(nanoseconds: 600_000_000)
        var reply = "（測試回覆，還沒接上真的 AI）你問的是：「\(question)」"
        if let card = cardContext?.card {
            reply += "\n\n目前情境卡片：\(card.nameZH)"
        }
        if rulesContext != nil {
            reply += "\n（已帶入規則資料）"
        }
        return reply
    }
}
