import Observation
import Foundation

/// 浮動聊天視窗的狀態：整個 App 共用同一個對話（不分頁面），從卡片詳情頁
/// 點「問 AI」會把該卡的資料帶進來當背景資訊；問題送出後才知道要不要一併
/// 帶規則資料（規則問答跟卡牌問答用同一個輸入框，不用使用者自己切模式）
@Observable
@MainActor
final class AIChatCoordinator {
    var isPresented = false
    var messages: [AIChatMessage] = []
    var draftText = ""
    /// 目前情境卡片；換一張卡再開啟聊天視窗，會提示使用者情境換了
    var cardContext: AICardContext?

    private let service: AIAssistantService

    init(service: AIAssistantService = MockAIAssistantService()) {
        self.service = service
    }

    /// 從卡片詳情頁的「問 AI」按鈕呼叫——換卡要提示一下，不然使用者以為
    /// AI 還記得上一張卡在問什麼
    func open(withCard card: Card) {
        if cardContext?.card.id != card.id {
            cardContext = AICardContext(card: card)
            messages.append(.init(role: .assistant,
                                  text: "已帶入「\(card.nameZH)」的卡片資料，可以直接問這張卡的效果或規則問題。"))
        }
        isPresented = true
    }

    /// 從浮動按鈕呼叫，一般規則問答，不特別綁定某張卡
    func openGeneral() {
        isPresented = true
    }

    func clearCardContext() {
        cardContext = nil
    }

    func send() {
        let question = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        draftText = ""
        messages.append(.init(role: .user, text: question))
        let placeholder = AIChatMessage(role: .assistant, text: "", isLoading: true)
        messages.append(placeholder)
        let history = Array(messages.dropLast(2))
        let context = cardContext
        let rules = RulesReference.text

        Task {
            do {
                let reply = try await service.ask(question: question, history: history,
                                                  cardContext: context, rulesContext: rules)
                update(placeholderID: placeholder.id, text: reply)
            } catch {
                update(placeholderID: placeholder.id, text: "問答失敗，請稍後再試一次。")
            }
        }
    }

    private func update(placeholderID: UUID, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == placeholderID }) else { return }
        messages[index].text = text
        messages[index].isLoading = false
    }
}
