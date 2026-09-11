import Foundation

/// WS Neo-Standard 建構規則檢查（§4.4.3）。純函式，好測試。
struct DeckValidator {

    struct Result {
        var totalCount: Int
        var climaxCount: Int
        /// 同名超過 4 張的卡名（依 nameJP 分組，跨刷版、跨卡號）
        var overLimitNames: [String]
        /// 混入了不同作品的卡（Neo-Standard 牌組須同一作品）
        var mixedTitles: Bool = false

        var totalOK: Bool { totalCount == 50 }
        var climaxOK: Bool { climaxCount == 8 }
        var namesOK: Bool { overLimitNames.isEmpty }
        var isLegal: Bool { totalOK && climaxOK && namesOK && !mixedTitles }
    }

    /// 展開後的一筆：卡片 + 張數（呼叫端負責把 printingID 解析成 Card）
    struct CountedCard {
        let card: Card
        let count: Int
    }

    static let deckSize = 50
    static let climaxLimit = 8
    static let nameLimit = 4

    /// 組牌限制例外表，由 DeckBuildingRulesService 背景抓回來後更新。
    /// 抓不到／還沒抓回來時是 `.standard`（人人同名 4 張上限），
    /// 這是安全的預設值，不會把原本合法的牌組誤判成違規
    static var activeRules = NameLimitRules.standard

    static func validate(_ items: [CountedCard], rules: NameLimitRules = activeRules) -> Result {
        let total = items.reduce(0) { $0 + $1.count }
        let climax = items.filter { $0.card.cardType == .climax }.reduce(0) { $0 + $1.count }

        // ⚠ 三層概念：刷版不獨立計算；預設依「卡名」分組（因為存在不同基礎
        //   卡號但同名的卡，補充包與預組重複收錄），少數卡有例外規則——
        //   同名上限不是 4（見卡片能力文字），或跟另一個卡名合計算一組
        //   （通常是覺醒/變身關係），都靠 rules.group(for:) 解出正確分組
        var groups: [Set<String>: (limit: Int?, total: Int)] = [:]
        for item in items {
            let group = rules.group(for: item.card.nameJP)
            groups[group.names, default: (group.limit, 0)].total += item.count
        }
        let over = groups.compactMap { names, entry -> String? in
            guard let limit = entry.limit, entry.total > limit else { return nil }
            return names.sorted().joined(separator: "、")
        }.sorted()

        // 作品代號 = 卡號 `/` 前的字母（BRD、NIK、BD…）；同代號視為同作品
        let titlePrefixes = Set(items.map { String($0.card.id.prefix(while: { $0 != "/" })) })

        return Result(totalCount: total, climaxCount: climax,
                      overLimitNames: over,
                      mixedTitles: titlePrefixes.count > 1)
    }

    /// 某一張卡（依卡名跨刷版）目前的張數，跟同名上限一起用來標紅
    static func nameCount(of card: Card, in items: [CountedCard]) -> Int {
        items.filter { $0.card.nameJP == card.nameJP }.reduce(0) { $0 + $1.count }
    }

    /// 這張卡的同名上限（含合併同名分組）；nil = 無上限，可放任意張
    static func nameLimit(for card: Card, rules: NameLimitRules = activeRules) -> Int? {
        rules.group(for: card.nameJP).limit
    }
}
