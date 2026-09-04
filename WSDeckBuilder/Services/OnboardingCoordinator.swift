import Observation
import SwiftUI

/// 首次使用的引導教學步驟。順序即教學順序，每一步都對應畫面上一個真實的
/// 互動（不是截圖假操作），使用者做了那個動作，教學才會往下走。
///
/// 步驟順序刻意先在「牌組」分頁建立一副牌組，再回「圖鑑」示範加卡——
/// 加卡動作需要有一副現有牌組才 make sense，順序反過來會卡住。
enum OnboardingStep: Int, CaseIterable {
    /// 純招呼語，不指任何元件、不算進「N / 總數」的步驟計數裡
    case welcome
    case homeIntro
    case search
    case filter
    case notifications
    case createDeck
    case pinDecks
    case viewCard
    case addToDeck
    case appearance

    var title: String {
        switch self {
        case .welcome: "歡迎使用"
        case .homeIntro: "首頁公告"
        case .search: "搜尋卡片"
        case .filter: "篩選條件"
        case .notifications: "通知"
        case .createDeck: "建立牌組"
        case .pinDecks: "釘選常用牌組"
        case .viewCard: "查看卡片"
        case .addToDeck: "加入牌組"
        case .appearance: "外觀設定"
        }
    }

    var body: String {
        switch self {
        case .welcome: "歡迎使用本程式，接下來我會教你如何使用這些功能。"
        case .homeIntro: "上面可以左右滑動看最新商品，下面是官方公告，點進去可以看我們整理過的重點再決定要不要去官網看完整內容。"
        case .search: "在上面的搜尋列輸入卡號、卡名或能力文字，試著打「hololive」看看。"
        case .filter: "點篩選，可以用等級、顏色、種類縮小範圍。"
        case .notifications: "開發者的公告和卡表更新，都會在這裡提醒你。"
        case .createDeck: "點右上角的＋，建立你的第一副牌組。"
        case .pinDecks: "在牌組上向右滑，點「釘選到首頁」，常用的牌組就會出現在首頁最上方，不用每次都切分頁找。"
        case .viewCard: "回到圖鑑，點一部作品、再點一張卡，看看完整能力文字翻譯。"
        case .addToDeck: "在卡片上點「＋」，把它加進剛剛建立的牌組。"
        case .appearance: "點「外觀」，字級、背景、強調色都能依你喜好調整。"
        }
    }

    /// 這一步該切去哪個分頁；nil 表示留在使用者目前所在的分頁就好
    var tab: RootTabView.Tab? {
        switch self {
        case .welcome: nil
        case .homeIntro: .home
        case .search, .filter, .notifications, .viewCard, .addToDeck: .catalog
        case .createDeck, .pinDecks: .deck
        case .appearance: .settings
        }
    }

    /// 提示卡右上角「N / 總數」用的編號，招呼語不算在內——使用者看到的是
    /// 「開始教學」而不是「1/8 之 1」這種怪數字
    var displayIndex: Int? { self == .welcome ? nil : rawValue }
    static var countedTotal: Int { allCases.count - 1 }
}

/// 引導教學的狀態機。真正的「做了什麼」由各畫面自己在對應的動作裡呼叫
/// `notify(_:)`，這裡只負責「目前該顯示第幾步、有沒有結束」。
@Observable
@MainActor
final class OnboardingCoordinator {
    private static let completedKey = "onboarding.completed"

    private(set) var isActive: Bool
    private(set) var currentStep: OnboardingStep?

    /// 畫面回報「這一步的目標元件在螢幕上的哪個位置」，疊層用這個畫出光圈
    var anchors: [OnboardingStep: Anchor<CGRect>] = [:]

    init() {
        let completed = UserDefaults.standard.bool(forKey: Self.completedKey)
        isActive = !completed
        currentStep = isActive ? OnboardingStep.allCases.first : nil
    }

    /// 各畫面在真正的動作發生時呼叫。只有「現在正好在等這一步」才會前進，
    /// 使用者提早點到後面步驟的目標不會誤觸——那個元件這時候通常也還沒出現。
    func notify(_ step: OnboardingStep) {
        guard isActive, currentStep == step else { return }
        advance()
    }

    /// 教學卡片上的「下一步」，不管真實動作有沒有發生都放行——
    /// 不能讓不知道要怎麼操作的人卡在某一步走不下去。
    func advance() {
        guard let current = currentStep,
              let index = OnboardingStep.allCases.firstIndex(of: current) else { return }
        let next = index + 1
        if next < OnboardingStep.allCases.count {
            currentStep = OnboardingStep.allCases[next]
        } else {
            finish()
        }
    }

    func skip() { finish() }

    /// 教學卡片上的「上一步」，回頭看漏掉或忘記的說明；
    /// 已經在第一步就沒有更前面可以退了
    func retreat() {
        guard let current = currentStep,
              let index = OnboardingStep.allCases.firstIndex(of: current),
              index > 0 else { return }
        currentStep = OnboardingStep.allCases[index - 1]
    }

    /// 設定頁的「幫助」按鈕：讓看過教學的人也能重新從頭跑一次
    func restart() {
        UserDefaults.standard.set(false, forKey: Self.completedKey)
        isActive = true
        currentStep = OnboardingStep.allCases.first
    }

    private func finish() {
        isActive = false
        currentStep = nil
        UserDefaults.standard.set(true, forKey: Self.completedKey)
    }
}
