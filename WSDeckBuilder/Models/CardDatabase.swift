import Foundation
import Observation

/// 圖鑑瀏覽單位：大多數作品跟 CardSetMeta 一對一，但同系列橫跨多個商品代碼
/// （如「葬送的芙莉蓮」有 S108/S128/S136 三波）的作品會拆成好幾個。
/// `id` 是篩選、收藏、導覽共用的識別碼——沒拆彈時就是 titleCode 本身，
/// 拆彈時是各自的 productCode（如 "SFN/S108"），兩者字串上可能重疊，
/// 一律靠 CardDatabase.productCodes 這個集合判斷該用哪種比對方式。
struct BrowsableSet: Identifiable, Hashable {
    let id: String
    let titleCode: String
    let titleNameZH: String
    let titleNameJP: String
    let cardCount: Int
    /// 原始商品代碼（如 "SFN/S108"），拆彈的作品才有值，圖鑑卡片右下角當輔助資訊顯示
    let productCode: String?
    /// nil＝沒拆彈，顯示原本作品名；有值＝顯示「作品名 第X彈」。順序是拿商品代碼
    /// 裡的數字排的，不保證等於官方實際發售順序（見 docs/series_breakdown_report.md
    /// 的提醒），使用者要求先用這個顯示，之後有錯再個別修正
    let waveLabel: String?

    var displayNameZH: String {
        waveLabel.map { "\(titleNameZH) \($0)" } ?? titleNameZH
    }
}

/// 啟動時載入一次 Bundle 內 JSON，全 App 共用（唯讀）
@Observable
final class CardDatabase {
    private(set) var cards: [Card] = []
    /// 已載入的作品（依 Bundle 內 *_cards.json）
    private(set) var sets: [CardSetMeta] = []
    /// 圖鑑實際要列出來的瀏覽單位——同系列多商品代碼的作品已經拆好
    private(set) var browsableSets: [BrowsableSet] = []
    private(set) var loadError: String?
    /// 正在解 JSON、建索引；UI 拿來顯示載入畫面
    private(set) var isLoading = false

    private var cardIndex: [String: Card] = [:]         // 任一刷版卡號 → Card
    private var printingIndex: [String: Printing] = [:] // 刷版卡號 → Printing
    private var titleByCardID: [String: String] = [:]   // 卡片 → title_code
    private var relationIndex: [String: [CardRelation]] = [:]  // 卡片 → 關聯卡片
    /// 拆過彈的作品才會出現在這裡，篩選/收藏用的 id 是不是「商品代碼」靠這個判斷
    private var productCodes: Set<String> = []
    /// 全部特徵（供 FilterSheet 列舉）
    private(set) var allTraits: [String] = []

    /// 解碼與建索引的產物。全部是值型別，可以在背景執行緒算完再整包交給主執行緒。
    private struct Snapshot {
        var cards: [Card] = []
        var sets: [CardSetMeta] = []
        var browsableSets: [BrowsableSet] = []
        var cardIndex: [String: Card] = [:]
        var printingIndex: [String: Printing] = [:]
        var titleByCardID: [String: String] = [:]
        var relationIndex: [String: [CardRelation]] = [:]
        var productCodes: Set<String> = []
        var allTraits: [String] = []
    }

    /// 六百多萬位元組的 JSON 在主執行緒解會卡住畫面數秒，丟到背景做。
    @MainActor
    func load() async {
        guard !isLoading, cards.isEmpty else { return }
        await rebuild()
    }

    /// 線上更新換掉檔案後重讀。牌組只存卡號，不需要搬遷（§4.4.8）
    @MainActor
    func reload() async {
        guard !isLoading else { return }
        await rebuild()
    }

    @MainActor
    private func rebuild() async {
        isLoading = true
        defer { isLoading = false }
        let work = Task.detached(priority: .userInitiated) { Self.buildSnapshot() }
        switch await work.value {
        case .success(let snapshot):
            cards = snapshot.cards
            sets = snapshot.sets
            browsableSets = snapshot.browsableSets
            cardIndex = snapshot.cardIndex
            printingIndex = snapshot.printingIndex
            titleByCardID = snapshot.titleByCardID
            relationIndex = snapshot.relationIndex
            productCodes = snapshot.productCodes
            allTraits = snapshot.allTraits
        case .failure(let message):
            loadError = message
        }
    }

    /// 背景解碼的結果；失敗只需要一句給使用者看的訊息，不必包成 Error
    private enum LoadOutcome {
        case success(Snapshot)
        case failure(String)
    }

    /// 卡表檔的來源。同檔名時下載版蓋過內建版，這樣沒更新過也能離線運作（§4.4.8）
    static func dataFileURLs() -> [URL] {
        var byName: [String: URL] = [:]
        for url in Bundle.main.urls(forResourcesWithExtension: "json",
                                    subdirectory: nil) ?? []
        where url.lastPathComponent.hasSuffix("_cards.json") {
            byName[url.lastPathComponent] = url
        }
        let downloaded = (try? FileManager.default.contentsOfDirectory(
            at: CardDataStore.directory, includingPropertiesForKeys: nil)) ?? []
        for url in downloaded where url.lastPathComponent.hasSuffix("_cards.json") {
            byName[url.lastPathComponent] = url
        }
        return byName.values.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func buildSnapshot() -> LoadOutcome {
        let urls = dataFileURLs()
        guard !urls.isEmpty else {
            return .failure("找不到卡片資料檔（*_cards.json）")
        }
        var snapshot = Snapshot()
        var all: [Card] = []
        for url in urls {
            do {
                let set = try JSONDecoder().decode(CardSet.self,
                                                   from: Data(contentsOf: url))
                snapshot.sets.append(set.meta)
                for card in set.cards {
                    snapshot.titleByCardID[card.id] = set.meta.titleCode
                }
                all.append(contentsOf: set.cards)
            } catch {
                return .failure("\(url.lastPathComponent) 載入失敗："
                                + error.localizedDescription)
            }
        }
        snapshot.sets.sort { $0.titleCode < $1.titleCode }
        snapshot.cards = sortCards(all, titleByCardID: snapshot.titleByCardID)
        for card in snapshot.cards {
            // 基礎卡號也建索引：SP 特典卡（如 -113）沒有同號普卡刷版
            snapshot.cardIndex[card.id] = card
            for printing in card.printings {
                snapshot.cardIndex[printing.id] = card
                snapshot.printingIndex[printing.id] = printing
            }
        }
        snapshot.allTraits = Array(Set(snapshot.cards.flatMap(\.traitsZH))).sorted()
        snapshot.relationIndex = buildRelations(snapshot.cards)
        (snapshot.browsableSets, snapshot.productCodes) = buildBrowsableSets(
            sets: snapshot.sets, cards: snapshot.cards, titleByCardID: snapshot.titleByCardID)
        return .success(snapshot)
    }

    /// 同系列橫跨多個商品代碼（如「葬送的芙莉蓮」S108/S128/S136）的作品拆成
    /// 好幾個瀏覽單位；只有 1 個代碼的作品維持原樣，用 titleCode 當 id
    private static func buildBrowsableSets(
        sets: [CardSetMeta], cards: [Card], titleByCardID: [String: String]
    ) -> ([BrowsableSet], Set<String>) {
        var cardsByTitle: [String: [Card]] = [:]
        for card in cards {
            cardsByTitle[titleByCardID[card.id] ?? "", default: []].append(card)
        }
        var result: [BrowsableSet] = []
        var productCodes: Set<String> = []
        for meta in sets {
            let titleCards = cardsByTitle[meta.titleCode] ?? []
            let codes = Set(titleCards.map(\.productCode))
            if codes.count <= 1 {
                result.append(BrowsableSet(
                    id: meta.titleCode, titleCode: meta.titleCode,
                    titleNameZH: meta.titleNameZH, titleNameJP: meta.titleNameJP,
                    cardCount: titleCards.count, productCode: nil, waveLabel: nil))
            } else {
                // 依商品代碼裡的數字排序（如 S108 < S128 < S136）當作發售順序的推測依據
                let ordered = codes.sorted {
                    (numericSuffix($0), $0) < (numericSuffix($1), $1)
                }
                for (index, code) in ordered.enumerated() {
                    let count = titleCards.lazy.filter { $0.productCode == code }.count
                    result.append(BrowsableSet(
                        id: code, titleCode: meta.titleCode,
                        titleNameZH: meta.titleNameZH, titleNameJP: meta.titleNameJP,
                        cardCount: count, productCode: code,
                        waveLabel: waveLabel(for: index + 1)))
                    productCodes.insert(code)
                }
            }
        }
        return (result, productCodes)
    }

    /// 商品代碼結尾的數字（如 "SFN/S108" → 108），沒有數字結尾就當 0
    private static func numericSuffix(_ code: String) -> Int {
        let digits = code.reversed().prefix(while: \.isNumber)
        return Int(String(digits.reversed())) ?? 0
    }

    private static let chineseOrdinals = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    private static func waveLabel(for index: Int) -> String {
        guard index >= 1, index <= chineseOrdinals.count else { return "第\(index)彈" }
        return "第\(chineseOrdinals[index - 1])彈"
    }

    /// 能力文字中以「」指名的卡片（羈絆對象、CX 連動指定的 CX 等），
    /// 同時建立反向關聯（這張 CX 被哪些角色連動）
    private static func buildRelations(_ cards: [Card]) -> [String: [CardRelation]] {
        var byNameJP: [String: [Card]] = [:]
        for card in cards {
            byNameJP[card.nameJP, default: []].append(card)
        }
        var index: [String: [CardRelation]] = [:]

        for card in cards where !card.textJP.isEmpty {
            for line in card.textLinesJP {
                for name in quotedNames(in: line) where name != card.nameJP {
                    guard let targets = byNameJP[name] else { continue }
                    let kind = CardRelation.Kind(line: line, target: targets[0])
                    for target in targets where target.id != card.id {
                        index[card.id, default: []]
                            .append(CardRelation(card: target, kind: kind))
                        index[target.id, default: []]
                            .append(CardRelation(card: card, kind: .referencedBy))
                    }
                }
            }
        }
        // 同一張卡可能被多行提到：每張只留最具體的關聯（羈絆 > CX連動 > 指名）
        var result: [String: [CardRelation]] = [:]
        for (id, relations) in index {
            var best: [String: CardRelation] = [:]
            for relation in relations {
                let existing = best[relation.card.id]
                if existing == nil || relation.kind.order < existing!.kind.order {
                    best[relation.card.id] = relation
                }
            }
            result[id] = best.values
                .sorted { ($0.kind.order, $0.card.id) < ($1.kind.order, $1.card.id) }
        }
        return result
    }

    private static func quotedNames(in line: String) -> [String] {
        var names: [String] = []
        var current: String?
        for character in line {
            if character == "「" {
                current = ""
            } else if character == "」" {
                if let name = current, !name.isEmpty { names.append(name) }
                current = nil
            } else if current != nil {
                current?.append(character)
            }
        }
        return names
    }

    func relations(for card: Card) -> [CardRelation] { relationIndex[card.id] ?? [] }

    func titleCode(of card: Card) -> String? { titleByCardID[card.id] }

    func cardCount(inTitle code: String) -> Int {
        titleByCardID.values.lazy.filter { $0 == code }.count
    }

    /// id 有沒有拆過彈：拆過的作品，篩選/收藏/導覽用的 id 是商品代碼而不是
    /// titleCode，兩種字串都可能長得像（有些 titleCode 本身就帶斜線），
    /// 靠這個集合分辨，不要用字串形狀猜
    func cards(inScope scope: String) -> [Card] {
        if productCodes.contains(scope) {
            return cards.filter { $0.productCode == scope }
        }
        return cards.filter { titleByCardID[$0.id] == scope }
    }

    /// 只列這個瀏覽單位出現過的特徵，篩選頁鎖定作品/商品時用——全部特徵一次
    /// 列出來常常有上百個跨作品的標籤，鎖定範圍後大多數根本不會出現在結果
    /// 裡，縮小範圍才看得出「這裡有哪些特徵可以篩」
    func traits(inScope scope: String) -> [String] {
        Array(Set(cards(inScope: scope).flatMap(\.traitsZH))).sorted()
    }

    func card(forPrinting id: String) -> Card? { cardIndex[id] }
    func printing(id: String) -> Printing? { printingIndex[id] }

    /// 預設排序：作品 → 等級 → 顏色 → 卡號（CX 排最後）
    private static func sortCards(_ cards: [Card],
                                  titleByCardID: [String: String]) -> [Card] {
        let colorOrder: [CardColor: Int] = [.yellow: 0, .green: 1, .red: 2, .blue: 3]
        return cards.sorted { a, b in
            let ta = titleByCardID[a.id] ?? "", tb = titleByCardID[b.id] ?? ""
            if ta != tb { return ta < tb }
            let la = a.level ?? 99, lb = b.level ?? 99
            if la != lb { return la < lb }
            let ca = colorOrder[a.color] ?? 9, cb = colorOrder[b.color] ?? 9
            if ca != cb { return ca < cb }
            return a.id < b.id
        }
    }

    /// 關鍵字指名的作品（卡片本身不含作品名，得另外比對 meta）
    func titleCodes(matching keyword: String) -> Set<String> {
        let lower = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        // 太短會配到一堆作品，反而干擾一般的卡名搜尋
        guard lower.count >= 2 else { return [] }
        var codes: Set<String> = []
        for set in sets {
            // titleCode 可能是 "BRD/W139"，使用者只會打前綴 "BRD"
            let prefix = set.titleCode.split(separator: "/").first.map(String.init)
                ?? set.titleCode
            if set.titleNameZH.lowercased().contains(lower)
                || set.titleNameJP.lowercased().contains(lower)
                || prefix.lowercased().hasPrefix(lower)
                || set.titleCode.lowercased().hasPrefix(lower) {
                codes.insert(set.titleCode)
            }
        }
        return codes
    }

    /// 疑似在找某個作品時給的選項；打錯字也照原樣保留使用者的輸入
    func suggestions(for keyword: String) -> [SearchSuggestion] {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let exact = titleCodes(matching: trimmed)

        var result: [SearchSuggestion] = []
        for set in sets {
            let prefix = set.titleCode.split(separator: "/").first.map(String.init)
                ?? set.titleCode
            let reason: SearchSuggestion.Reason?
            if exact.contains(set.titleCode) {
                reason = .exact
            } else if FuzzyMatch.isTypo(trimmed, of: prefix) {
                reason = .typo(matched: prefix)
            } else if FuzzyMatch.isTypo(trimmed, of: set.titleNameZH) {
                reason = .typo(matched: set.titleNameZH)
            } else {
                reason = nil
            }
            guard let reason else { continue }
            result.append(SearchSuggestion(titleCode: set.titleCode,
                                           titleName: set.titleNameZH,
                                           cardCount: cardCount(inTitle: set.titleCode),
                                           reason: reason))
        }
        // 精確的排前面，其次卡多的作品
        return result.sorted { a, b in
            let ea = a.isExact ? 0 : 1, eb = b.isExact ? 0 : 1
            if ea != eb { return ea < eb }
            return a.cardCount > b.cardCount
        }
    }

    /// §4.4.1：多個篩選條件之間是 AND，同一篩選內的多選是 OR
    func search(_ query: SearchQuery) -> [Card] {
        let keywordTitles = titleCodes(
            matching: query.keyword.trimmingCharacters(in: .whitespaces))
        return cards.filter { card in
            if let scope = query.titleCode {
                let matches = productCodes.contains(scope)
                    ? card.productCode == scope
                    : titleByCardID[card.id] == scope
                if !matches { return false }
            }
            if !query.levels.isEmpty {
                guard let level = card.level, query.levels.contains(level) else { return false }
            }
            if !query.colors.isEmpty, !query.colors.contains(card.color) { return false }
            if !query.types.isEmpty, !query.types.contains(card.cardType) { return false }
            if !query.triggers.isEmpty {
                guard let trigger = card.trigger, query.triggers.contains(trigger) else { return false }
            }
            if !query.traits.isEmpty,
               !card.traitsZH.contains(where: { query.traits.contains($0) }) { return false }
            if let source = query.sourceOnly, card.source != source { return false }

            let keyword = query.keyword.trimmingCharacters(in: .whitespaces)
            guard !keyword.isEmpty else { return true }
            // 打作品名（「棕色塵埃2」）時卡名比不到，改讓整個系列命中
            if !keywordTitles.isEmpty,
               keywordTitles.contains(titleByCardID[card.id] ?? "") { return true }
            let lower = keyword.lowercased()
            let normalized = SearchQuery.normalizeCardNumber(keyword)
            if !normalized.isEmpty,
               card.printings.contains(where: {
                   // 先比連續字串（打完整卡號、或只打 w139075 這種），
                   // 不中再走寬鬆比對（「hol 005」這種只記得頭尾的打法）
                   SearchQuery.normalizeCardNumber($0.id).contains(normalized)
                       || SearchQuery.looselyMatchesCardNumber(query: keyword, cardID: $0.id)
               }) { return true }
            // searchBlob 是載入時就算好的小寫全文；這裡再 lowercased() 等於
            // 每按一次鍵就把整個資料庫的卡名與能力文字重新配置一遍
            return card.searchBlob.contains(lower)
        }
    }
}
