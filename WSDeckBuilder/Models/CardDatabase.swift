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
    /// nil＝沒拆彈，顯示原本作品名；有值＝顯示「作品名 標籤」。標籤優先用
    /// wave_names.json 提供的官方商品名稱（如「Vol.2」「新装版」），該系列
    /// 官方資料還不夠乾淨時才退回舊的「第一彈/第二彈」數字猜測法
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
    /// productCode → 官方彈次標籤，來自 WaveNameService；重建 browsableSets 時要用
    private var waveNameOverrides: [String: String] = [:]
    /// 全部特徵（供 FilterSheet 列舉）
    private(set) var allTraits: [String] = []
    /// titleCode → 該作品最新一波的商品代碼數字，供「探索作品」畫面「由新到舊」
    /// 排序用。啟動時算好一次，不然每次排序都要整份卡表掃一輪——資料量還小
    /// （幾千張）時不明顯，卡表膨脹到三萬多張後，排序時對每個作品各掃一次
    /// 全部卡片會把主執行緒卡到被系統判定沒回應而關掉
    private var newestSetNumberByTitleCode: [String: Int] = [:]

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
        var newestSetNumberByTitleCode: [String: Int] = [:]
    }

    /// 六百多萬位元組的 JSON 在主執行緒解會卡住畫面數秒，丟到背景做。
    /// `waveNameOverrides` 是啟動時已經有的官方彈次標籤快取（見 WaveNameService），
    /// 這樣圖鑑一開始建立就是官方名稱，不用等網路查完才從數字猜測法換過來
    @MainActor
    func load(waveNameOverrides: [String: String] = [:]) async {
        guard !isLoading, cards.isEmpty else { return }
        self.waveNameOverrides = waveNameOverrides
        await rebuild()
    }

    /// WaveNameService 背景抓到新版官方彈次標籤時呼叫，只重建 browsableSets，
    /// 不用重新解一次整份卡表 JSON
    @MainActor
    func applyWaveNameOverrides(_ overrides: [String: String]) {
        guard !cards.isEmpty else { return }
        waveNameOverrides = overrides
        (browsableSets, productCodes) = Self.buildBrowsableSets(
            sets: sets, cards: cards, titleByCardID: titleByCardID,
            waveNameOverrides: overrides)
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
        let overrides = waveNameOverrides
        let work = Task.detached(priority: .userInitiated) { Self.buildSnapshot(waveNameOverrides: overrides) }
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
            newestSetNumberByTitleCode = snapshot.newestSetNumberByTitleCode
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

    private static func buildSnapshot(waveNameOverrides: [String: String]) -> LoadOutcome {
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
        var newestByTitle: [String: Int] = [:]
        for card in snapshot.cards {
            guard let titleCode = snapshot.titleByCardID[card.id] else { continue }
            let number = numericSuffix(card.productCode)
            if number > (newestByTitle[titleCode] ?? 0) { newestByTitle[titleCode] = number }
        }
        snapshot.newestSetNumberByTitleCode = newestByTitle
        (snapshot.browsableSets, snapshot.productCodes) = buildBrowsableSets(
            sets: snapshot.sets, cards: snapshot.cards, titleByCardID: snapshot.titleByCardID,
            waveNameOverrides: waveNameOverrides)
        return .success(snapshot)
    }

    /// 同系列橫跨多個商品代碼（如「葬送的芙莉蓮」S108/S128/S136）的作品拆成
    /// 好幾個瀏覽單位；只有 1 個代碼的作品維持原樣，用 titleCode 當 id
    private static func buildBrowsableSets(
        sets: [CardSetMeta], cards: [Card], titleByCardID: [String: String],
        waveNameOverrides: [String: String]
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
                // 依商品代碼裡的數字排序（如 S108 < S128 < S136）當顯示順序
                let ordered = codes.sorted {
                    (numericSuffix($0), $0) < (numericSuffix($1), $1)
                }
                // 官方標籤要整個系列每一彈都查得到才採用（見 make_wave_names.py
                // 的產生規則），免得同系列一部分用官方名稱、一部分用猜的
                let officialLabels: [String: String]? = {
                    var found: [String: String] = [:]
                    for code in ordered {
                        guard let label = waveNameOverrides[code] else { return nil }
                        found[code] = label
                    }
                    return found
                }()
                for (index, code) in ordered.enumerated() {
                    let count = titleCards.lazy.filter { $0.productCode == code }.count
                    let label: String?
                    if let officialLabels {
                        let raw = officialLabels[code] ?? ""
                        label = raw.isEmpty ? nil : raw
                    } else {
                        label = waveLabel(for: index + 1)
                    }
                    result.append(BrowsableSet(
                        id: code, titleCode: meta.titleCode,
                        titleNameZH: meta.titleNameZH, titleNameJP: meta.titleNameJP,
                        cardCount: count, productCode: code, waveLabel: label))
                    productCodes.insert(code)
                }
            }
        }
        return (result, productCodes)
    }

    /// 商品代碼結尾的數字（如 "SFN/S108" → 108），沒有數字結尾就當 0，非 private——
    /// 「由新到舊」排序（見 newestSetNumber）跟拆彈排序共用同一套規則
    static func numericSuffix(_ code: String) -> Int {
        let digits = code.reversed().prefix(while: \.isNumber)
        return Int(String(digits.reversed())) ?? 0
    }

    /// 這部作品目前收錄最新一波的商品代碼數字，供「探索作品」畫面「由新到舊」
    /// 排序用。Bushiroad 的彈次編號（如 S108、S136）全系列共用同一個流水號，
    /// 數字愈大代表愈晚發售，不必額外維護發售日期欄位。查表 O(1)——這裡以前
    /// 每次呼叫都線性掃過全部卡片找同作品的，卡表膨脹到三萬多張後排序一次
    /// 就要掃好幾百萬次，主執行緒卡住被系統判定沒回應而關掉（§4.3 圖鑑排序）
    func newestSetNumber(forTitleCode titleCode: String) -> Int {
        newestSetNumberByTitleCode[titleCode] ?? 0
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

    /// 卡表的 meta 本來就帶著每部作品的張數，直接查表就好——這裡以前是掃過
    /// `titleByCardID` 全部卡片再數有幾張符合，`suggestions(for:)` 每個候選
    /// 作品都會呼叫一次，卡表夠大時同一次打字就會疊出好幾輪全表掃描
    func cardCount(inTitle code: String) -> Int {
        sets.first(where: { $0.titleCode == code })?.cardCount ?? 0
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

    /// 畫面標題／篩選摘要要顯示的名稱：一般情況直接查 browsableSets 就有；
    /// 「不分彈瀏覽整個作品」用的 id 是裸 titleCode，不在 browsableSets 裡
    /// （每個 BrowsableSet 拆彈後 id 都是 productCode），要另外查 sets 補上
    func scopeDisplayName(_ code: String) -> String {
        if let set = browsableSets.first(where: { $0.id == code }) { return set.displayNameZH }
        if let meta = sets.first(where: { $0.titleCode == code }) { return "\(meta.titleNameZH)（不分彈）" }
        return code
    }

    /// 只列這個瀏覽單位出現過的特徵，篩選頁鎖定作品/商品時用——全部特徵一次
    /// 列出來常常有上百個跨作品的標籤，鎖定範圍後大多數根本不會出現在結果
    /// 裡，縮小範圍才看得出「這裡有哪些特徵可以篩」
    func traits(inScope scope: String) -> [String] {
        Array(Set(cards(inScope: scope).flatMap(\.traitsZH))).sorted()
    }

    /// 這個瀏覽範圍拆出的彈次選項（如 OVL 底下的 S62／S66／SE54…），只有
    /// 拆過彈的作品才有東西可選——「不分彈」瀏覽整個作品、或直接鎖進某彈時，
    /// 讓使用者進一步縮小到某幾彈。只有 1 個彈次可選時回傳空陣列，篩選頁
    /// 才知道要整區藏起來，不然選了也等於沒選
    func waves(inScope scope: String) -> [BrowsableSet] {
        let scopeTitleCode = browsableSets.first(where: { $0.id == scope })?.titleCode ?? scope
        let matches = browsableSets.filter { $0.titleCode == scopeTitleCode && $0.productCode != nil }
        return matches.count > 1 ? matches : []
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
            let ca = a.color.flatMap { colorOrder[$0] } ?? 9
            let cb = b.color.flatMap { colorOrder[$0] } ?? 9
            if ca != cb { return ca < cb }
            return a.id < b.id
        }
    }

    /// 關鍵字指名的作品（卡片本身不含作品名，得另外比對 meta）
    func titleCodes(matching keyword: String) -> Set<String> {
        let lower = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        guard !lower.isEmpty else { return [] }
        // 只打一個字時，作品名只用「開頭是這個字」比對（不是 contains）——
        // 這樣打第一個字就有結果，又不會因為隨便哪部作品名字中間剛好有這個字
        // 就整批命中，看起來像亂猜；打到第二個字才放寬成整段都算
        let onlyPrefix = lower.count == 1
        var codes: Set<String> = []
        for set in sets {
            // titleCode 可能是 "BRD/W139"，使用者只會打前綴 "BRD"
            let prefix = set.titleCode.split(separator: "/").first.map(String.init)
                ?? set.titleCode
            let nameZH = set.titleNameZH.lowercased()
            let nameJP = set.titleNameJP.lowercased()
            let nameMatches = onlyPrefix
                ? (nameZH.hasPrefix(lower) || nameJP.hasPrefix(lower))
                : (nameZH.contains(lower) || nameJP.contains(lower))
            if nameMatches
                || prefix.lowercased().hasPrefix(lower)
                || set.titleCode.lowercased().hasPrefix(lower) {
                codes.insert(set.titleCode)
            }
        }
        return codes
    }

    /// 疑似在找某個作品時給的選項；打錯字也照原樣保留使用者的輸入。
    /// 只打一個字時只用精確前綴比對（見 titleCodes(matching:)），不跑容錯
    /// 比對——編輯距離在一個字上沒有意義，隨便什麼字都會判成「打錯字」
    func suggestions(for keyword: String) -> [SearchSuggestion] {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let exact = titleCodes(matching: trimmed)
        let allowTypoMatch = trimmed.count >= 2

        var result: [SearchSuggestion] = []
        for set in sets {
            let prefix = set.titleCode.split(separator: "/").first.map(String.init)
                ?? set.titleCode
            let reason: SearchSuggestion.Reason?
            if exact.contains(set.titleCode) {
                reason = .exact
            } else if allowTypoMatch, FuzzyMatch.isTypo(trimmed, of: prefix) {
                reason = .typo(matched: prefix)
            } else if allowTypoMatch, FuzzyMatch.isTypo(trimmed, of: set.titleNameZH) {
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

    /// §4.4.1：多個篩選條件之間是 AND，同一篩選內的多選是 OR。
    /// 關鍵字比對依「像不像使用者要找的那張卡」分等第排序，不是比對到就照原始
    /// 順序塞回去——不然打第一個字時，卡名裡有這個字的卡會被能力文字裡剛好有
    /// 這個字的卡（通常一大票）淹沒，看起來像沒在猜使用者要找什麼。
    func search(_ query: SearchQuery) -> [Card] {
        let keywordTitles = titleCodes(
            matching: query.keyword.trimmingCharacters(in: .whitespaces))
        let filtered = cards.filter { card in
            if let scope = query.titleCode {
                let matches = productCodes.contains(scope)
                    ? card.productCode == scope
                    : titleByCardID[card.id] == scope
                if !matches { return false }
            }
            if !query.levels.isEmpty {
                guard let level = card.level, query.levels.contains(level) else { return false }
            }
            if !query.colors.isEmpty {
                guard let color = card.color, query.colors.contains(color) else { return false }
            }
            if !query.types.isEmpty, !query.types.contains(card.cardType) { return false }
            if !query.triggers.isEmpty {
                guard let trigger = card.trigger, query.triggers.contains(trigger) else { return false }
            }
            if !query.traits.isEmpty,
               !card.traitsZH.contains(where: { query.traits.contains($0) }) { return false }
            if !query.waves.isEmpty, !query.waves.contains(card.productCode) { return false }
            if let source = query.sourceOnly, card.source != source { return false }
            return true
        }

        let keyword = query.keyword.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return filtered }
        let lower = keyword.lowercased()
        let normalized = SearchQuery.normalizeCardNumber(keyword)

        // 4：卡名開頭就是這個字（中英日都適用，打第一個字最想看到的結果）
        // 3：卡名裡有這個字，但不是開頭
        // 2：命中作品名或卡號
        // 1：只有能力文字裡才找得到，排在最後面墊底
        func score(_ card: Card) -> Int? {
            let nameZH = card.nameZH.lowercased()
            let nameJP = card.nameJP.lowercased()
            if nameZH.hasPrefix(lower) || nameJP.hasPrefix(lower) { return 4 }
            if nameZH.contains(lower) || nameJP.contains(lower) { return 3 }
            // 打作品名（「棕色塵埃2」）時卡名比不到，改讓整個系列命中
            if !keywordTitles.isEmpty,
               keywordTitles.contains(titleByCardID[card.id] ?? "") { return 2 }
            if !normalized.isEmpty,
               card.printings.contains(where: {
                   // 先比連續字串（打完整卡號、或只打 w139075 這種），
                   // 不中再走寬鬆比對（「hol 005」這種只記得頭尾的打法）
                   SearchQuery.normalizeCardNumber($0.id).contains(normalized)
                       || SearchQuery.looselyMatchesCardNumber(query: keyword, cardID: $0.id)
               }) { return 2 }
            // searchBlob 是載入時就算好的小寫全文；這裡再 lowercased() 等於
            // 每按一次鍵就把整個資料庫的卡名與能力文字重新配置一遍
            if card.searchBlob.contains(lower) { return 1 }
            return nil
        }

        return filtered
            .compactMap { card in score(card).map { (card, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}
