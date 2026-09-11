import Foundation
import Observation

/// 同名／合併同名卡的組牌上限索引（§4.4.3 的例外表）。多數卡同名上限是 4 張，
/// 但少數卡的能力文字明講「此卡同名可放 N 張」甚至「可放任意張」，也有少數
/// 兩張不同卡名的卡共用一個合計上限（通常是覺醒/變身關係的角色）。這份規則
/// 從 WSDeckBuilder-data 的 `deck_building_rules.json` 抓回來，純資料結構，
/// 方便在測試裡手動建構特定規則。
struct NameLimitRules: Equatable {
    struct Group: Equatable {
        /// 共用同一個上限的卡名集合，沒有例外規則時就只有卡片自己
        let names: Set<String>
        /// nil = 無上限（可放任意張）
        let limit: Int?
    }

    private let groupByName: [String: Group]
    private let defaultLimit: Int

    /// 沒有任何例外規則時的預設值：人人都是同名 4 張上限，
    /// 抓不到例外表或例外表還沒抓回來時用這個，不會把原本合法的牌組誤判
    static let standard = NameLimitRules(defaultLimit: DeckValidator.nameLimit, groupByName: [:])

    init(defaultLimit: Int, groupByName: [String: Group]) {
        self.defaultLimit = defaultLimit
        self.groupByName = groupByName
    }

    init(data: DeckBuildingRulesFeed) {
        defaultLimit = data.defaultSameNameLimit
        var map: [String: Group] = [:]
        for rule in data.rules {
            let names = Set(rule.namesJP)
            guard !names.isEmpty else { continue }
            let limit = rule.limitKind == "unlimited" ? nil : rule.limit
            let group = Group(names: names, limit: limit)
            for name in names { map[name] = group }
        }
        groupByName = map
    }

    /// 這個卡名所屬的分組與上限；沒有例外規則就回傳卡名自己＋預設上限
    func group(for nameJP: String) -> Group {
        groupByName[nameJP] ?? Group(names: [nameJP], limit: defaultLimit)
    }
}

/// `deck_building_rules.json` 的解碼結構，只取用得到的欄位——`source_cards`
/// 那些附帶的原文摘錄只是例外表產生時的可追溯依據，App 端不需要。
struct DeckBuildingRulesFeed: Decodable {
    let schemaVersion: Int
    let defaultSameNameLimit: Int
    let rules: [Rule]

    struct Rule: Decodable {
        let namesJP: [String]
        let limit: Int?
        let limitKind: String

        enum CodingKeys: String, CodingKey {
            case namesJP = "names_jp"
            case limit
            case limitKind = "limit_kind"
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case defaultSameNameLimit = "default_same_name_limit"
        case rules
    }
}

/// 背景抓組牌限制例外表，對應 WaveNameService 同一套「抓不到就沿用快取／
/// 預設值，不用錯誤打斷使用者」的作法——這只是少數卡片的規則細節，不是
/// 關鍵功能，查不到就照標準 4 張上限判斷，不會把原本合法的牌組誤判成違規。
@Observable
@MainActor
final class DeckBuildingRulesService {
    private(set) var rules: NameLimitRules = .standard {
        didSet { DeckValidator.activeRules = rules }
    }

    private static let url = URL(string: "https://raw.githubusercontent.com"
        + "/lungmark0618-collab/WSDeckBuilder-data/main/deck_building_rules.json")!
    private static var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("deck_building_rules_cache.json")
    }
    /// 舊格式一律不看，App 只認得看得懂的 schema，跟卡表更新同一套保護
    private static let supportedSchemaVersion = 1

    init() {
        loadCache()
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheFile),
              let decoded = try? JSONDecoder().decode(DeckBuildingRulesFeed.self, from: data),
              decoded.schemaVersion <= Self.supportedSchemaVersion else { return }
        rules = NameLimitRules(data: decoded)
    }

    func refresh() async {
        do {
            var request = URLRequest(url: Self.url)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(DeckBuildingRulesFeed.self, from: data)
            guard decoded.schemaVersion <= Self.supportedSchemaVersion else { return }
            rules = NameLimitRules(data: decoded)
            try? data.write(to: Self.cacheFile)
        } catch {
            // 抓不到就沿用快取／標準規則，見上方類別註解
        }
    }
}
