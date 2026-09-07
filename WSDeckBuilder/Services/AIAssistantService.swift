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

/// 使用者還沒到「設定」頁填代理伺服器網址時的替身，直接回一個引導訊息，
/// 不會真的發網路請求
struct UnconfiguredAIAssistantService: AIAssistantService {
    func ask(question: String,
             history: [AIChatMessage],
             cardContext: AICardContext?,
             rulesContext: String?) async throws -> String {
        "尚未設定 AI 服務。請到「設定 → AI 服務設定」填入代理伺服器的網址與密鑰後再試一次。"
    }
}

/// 呼叫自架的輕量代理伺服器（見 ai-proxy/），伺服器再轉打 OpenAI，
/// App 本身不帶 OpenAI Key，只帶一組共用密鑰擋住隨便打進來的請求
struct RemoteAIAssistantService: AIAssistantService {
    let baseURL: URL
    let sharedSecret: String

    private struct RequestBody: Encodable {
        struct Turn: Encodable { let role: String; let text: String }
        let question: String
        let history: [Turn]
        let cardContext: String?
        let rulesContext: String?
    }

    private struct ResponseBody: Decodable {
        let answer: String?
        let error: String?
    }

    func ask(question: String,
             history: [AIChatMessage],
             cardContext: AICardContext?,
             rulesContext: String?) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("ask"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !sharedSecret.isEmpty {
            request.setValue(sharedSecret, forHTTPHeaderField: "X-App-Secret")
        }
        let turns = history.map { RequestBody.Turn(role: $0.role == .assistant ? "assistant" : "user", text: $0.text) }
        let body = RequestBody(question: question, history: turns,
                               cardContext: cardContext?.summary, rulesContext: rulesContext)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        if let error = decoded.error { throw NSError(domain: "AIProxy", code: 0, userInfo: [NSLocalizedDescriptionKey: error]) }
        return decoded.answer ?? ""
    }
}

/// 內建的代理伺服器預設值——App 出貨就能直接用，不用使用者自己跑去設定頁
/// 填網址／密鑰；設定頁的欄位還在，之後要換伺服器或密鑰再改就好
enum AIProxyDefaults {
    static let url = "https://wsdeck-ai-proxy.marklung0618.workers.dev"

    /// 真正的密鑰不寫進 public repo：這裡故意放假值。本機建置前把下面這行
    /// 換成 `wrangler secret put APP_SHARED_SECRET` 時設定的那組真正的值，
    /// 建置完再改回假值；或者不改這裡，直接在 App「設定 → AI 服務設定」
    /// 手動填入真正的值，一樣會覆蓋掉這裡的預設值
    static let sharedSecret = "REPLACE_WITH_REAL_SECRET_BEFORE_BUILDING"
}

/// 依「設定」頁目前存的代理伺服器網址／密鑰，決定要用真的服務還是引導訊息，
/// 每次問答都重新讀一次，設定改了不用重開 App。使用者還沒打開過設定頁時
/// UserDefaults 裡不會有值，這裡退回內建預設值，而不是引導訊息
enum AIAssistantServiceResolver {
    static func current() -> AIAssistantService {
        let defaults = UserDefaults.standard
        let urlString = defaults.string(forKey: "aiProxyURL") ?? AIProxyDefaults.url
        guard !urlString.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: urlString) else {
            return UnconfiguredAIAssistantService()
        }
        let secret = defaults.string(forKey: "aiProxySharedSecret") ?? AIProxyDefaults.sharedSecret
        return RemoteAIAssistantService(baseURL: url, sharedSecret: secret)
    }
}
