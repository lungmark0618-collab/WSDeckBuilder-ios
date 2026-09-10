# iOS 牌組卡表拖曳排序 —— 問題整理與已嘗試方法

給接手的夥伴看的完整背景。這份只談 **iOS** 版（Android 版的拖曳排序已經修好並驗證過，沒有這個問題）。

## 現象

牌組詳情頁「卡表」分頁、清單模式（`WSDeckBuilder/Views/Deck/DeckDetailView.swift`），每一列左側有個 `line.3.horizontal` 拖曳把手，抓著它上下拖可以在同一個等級分區（Lv0／Lv1…／CX）內重新排序。

**使用者在真機上反覆回報**：拖曳排序不會照預期運作。回報過的具體症狀（每次修完再回報都不一樣，可能是同一個根因的不同表現，也可能是好幾個各自獨立的 bug）：

1. 長按會浮起來，但放開後完全沒換位置，順序還原成拖之前的樣子。
2. 有換位置，但跳到很奇怪的地方，或是一路「雪崩」跳到分區最底部（不管手指移動多少都一樣跳到底）。
3. 拖曳過程中清單很卡頓，正在拖的那一列偶爾會整個「消失」一下再重繪。
4. 最新一輪（2026-09-07）：使用者說「還是一樣的問題」，附了一段螢幕錄影，畫面顯示拖曳中有一列不在原本的位置（疑似浮到畫面上方、控制中心的位置附近），最後結論仍是「會換位置但跳到奇怪的地方 / 一直雪崩到底部」。

**目前狀態**：我（Claude）這邊用 iOS 模擬器（Simulator，透過 MCP 工具送合成觸控事件）反覆測試最新版本，看起來是正常的（見下方「最新一版的邏輯」），但使用者在真機上仍回報同樣的問題。**模擬器驗證通過、真機仍失敗**，這個落差本身就是最大的謎團，也是這次想請別人一起看的主因。

## 環境

- SwiftUI，`IPHONEOS_DEPLOYMENT_TARGET = 17.0`
- 清單用原生 `List` + `Section`（不是自己刻的 ScrollView），`listStyle(.insetGrouped)`
- 拖曳排序完全是手刻的，**沒有用**任何系統的 drag-and-drop API（原因見下方「已嘗試方法」第 1、2 輪，都失敗了）
- 相關檔案：`WSDeckBuilder/Views/Deck/DeckDetailView.swift`（單一檔案，約 618 行，拖曳邏輯集中在 `cardList` 這個 computed property，目前約在第 263～370 行）
- Git 歷史：這個功能相關的 commit 從 `c414b18`（build 20）一路到 `d6c0b3e`（build 26），共 7 次「修好了」的嘗試，訊息都在 commit log 裡

## 已嘗試方法（照時間順序，新到舊在最下面反過來看也可以）

### 第 1 輪（build 20）：系統原生 `.onMove` + `editMode`
最早的實作是標準 SwiftUI 寫法：`List` 的 `ForEach` 加 `.onMove`，搭配 `.environment(\.editMode, ...)` 切換編輯模式才能拖。
**使用者要求**：不想要「先切排序模式」這個額外步驟，希望直接長按就能拖（見對話中 2026-09-06 的需求：「想要不需要切模式就能直接拖」）。於是整個砍掉重做。

### 第 2 輪（build 21）：`.draggable` / `.dropDestination`（iOS 16+ 系統 API）
改用蘋果新的 Transferable 拖放 API：每一列 `.draggable(item.card.id)` + `.dropDestination(for: String.self) { ... }`。
**結果**：使用者實測「長按會浮起來，但拖了放開沒換位置」。懷疑是這組系統 API 在 `List` 裡跟 `DisclosureGroup`／`Button` 標籤混用時的已知相容性問題。

### 第 3 輪（build 21，同一版内又改一次）：舊式 `.onDrag` / `.onDrop(delegate:)`
換成更成熟的舊 API（`NSItemProvider` + `DropDelegate`），理論上比 Transferable 穩定。
**結果**：使用者實測還是「長按會浮起來，放開不會真的換位置」。跟第 2 輪同樣的症狀。這時候懷疑問題不是哪個系統 API 的鍋，而是這個 `List`（有 `Section`、每列是 `DisclosureGroup` 包 `Button`）本身跟系統拖放手勢有更底層的衝突，於是決定完全放棄系統拖放。

### 第 4 輪（build 22）：完全手刻手勢（第一版）
不靠任何系統拖放，改成：
- 每列左側一個小把手圖示，`DragGesture(minimumDistance: 2, coordinateSpace: .named("cardListSpace"))`
- 用 `GeometryReader` + `PreferenceKey` 量每列在共用座標空間裡的位置（`rowFrames: [String: CGRect]`）
- `onChanged` 裡拿目前拖曳位移換算出「手指現在對到哪一列」，用陣列搬移（`section.items` 直接呼叫 `moveCards`，**當時是每次交換都立刻 `context.save()` 寫回 SwiftData**）

**我（Claude）用模擬器測試「看起來」正常**，實際上傳給使用者後：

### 第 5 輪（build 23）：修「連環交換」+「一開牌組就拖」的 race
使用者這輪回報「會換位置但跳到很奇怪的地方 / 一直雪崩到底部」。
診斷出兩個問題並修正：
1. 交換後拿「自己」的新位置當基準，但 Compose/SwiftUI 這時候還沒重新排版，讀到的是舊值，導致補償量算錯，越拖越偏（改成 `dragStartMidY` 只在手指按下那一刻記錄一次，不再每次重讀）。
2. 一打開牌組就立刻拖，`rowFrames` 可能還沒量完，只抓一次基準會抓到 `nil`、整次手勢失效（改成沒抓到就持續重試）。

**依然用模擬器合成觸控測試，順序正確**。上傳後：

### 第 6 輪（build 24）：修「每次交換都存檔」造成的卡頓／消失
使用者這輪回報「清單列的還是很卡，而且拖曳的卡片會消失」。
診斷：每次交換位置都立刻呼叫 `context.save()`，觸發 SwiftData／`@Query` 整個重新整理，導致：
- 拖曳中持續卡頓
- 那一列在重新整理的瞬間有時會被判定成「消失」重繪一次

**修法**：拖曳中只在記憶體裡的 `liveSectionItems`（本地 `@State`）排序，**不寫資料庫**；只有放開手指（`onEnded`）才呼叫一次 `commitOrder(liveSectionItems, in: section)` 真的寫回 `deck.cardOrder`。這是目前架構的基礎，之後幾輪都是在這個架構上修。

**模擬器測試通過**（快速連續拖過好幾列，畫面流暢、順序正確、有存住）。上傳後：

### 第 7 輪（build 26，最新）：修「快速連續拖曳事件密度太高」的殘留雪崩
使用者又送了一段螢幕錄影，顯示拖曳中有一列位置跑到很奇怪的地方（疑似跑到接近畫面最上方、狀態列/控制中心那一帶），最終結果仍是「跳到奇怪地方 / 雪崩到底部」。

**這次的診斷**：每次交換位置後，`liveSectionItems` 換了，但「其他列」的實際位置（`rowFrames`，靠每一列自己的 `GeometryReader` 回報）不會馬上更新，要等 SwiftUI 真的重新排版一輪。如果手指滑得夠快、`DragGesture.onChanged` 觸發的密度夠高，下一個事件很可能會在 `rowFrames` 還沒更新前就跑到，用「還沒更新的舊位置」去判斷這次該跟誰交換 —— 判斷錯了，於是亂跳，而且會一路複合下去（跟 Android 版之前修好的雪崩問題是同一種「用到過期位置資料」的病灶，只是在 iOS 這邊是被「事件密度」觸發，在 Android 那邊是被「排版時序」觸發）。

**修法**：加一個 `awaitingLayoutRefresh` 旗標。每次交換完，先把它設成 `true`，暫停「要不要交換」的判斷（但手指的位移還是持續反映在畫面上，只是不會再觸發新的交換判斷）；等 `.onPreferenceChange(RowFramePreferenceKey.self)` 真的收到新版面（代表 SwiftUI 排版真的跑完了），才把旗標清成 `false`，恢復判斷。

**測試方式**：這次特別針對「密度」做了驗證 —— 用 8ms 間隔、每次只移動 4pt 的密集合成觸控點（模擬接近真實螢幕更新頻率的連續觸控），確認：
- 極密集的點：完全沒反應（懷疑是模擬器本身把過密的合成觸控點吃掉/合併了，不確定是不是真的反映了真機行為）
- 較合理密度（20ms 間隔、每次 30-40pt）：正確換位、沒有雪崩、離開頁面重進有存住
- 一次大範圍快速拖過整個 3 列的分區：正確停在該停的位置，沒有雪崩到別的分區

**這一版已經上傳 TestFlight（build 26），使用者更新後測試，回報「還是沒有用，都還是一樣的問題」。**

## 目前程式碼（build 26，`DeckDetailView.swift` 約 263～370 行）

核心狀態變數（約第 15～31 行附近）：
```swift
@State private var draggingCardID: String?
@State private var dragOffsetY: CGFloat = 0
@State private var rowFrames: [String: CGRect] = [:]
@State private var dragStartMidY: CGFloat?
@State private var draggingSectionTitle: String?
@State private var liveSectionItems: [DeckExporter.CardCount] = []
@State private var awaitingLayoutRefresh = false
```

手勢邏輯（`cardList` computed property 內）：見上方原始碼片段，重點是：
1. 把手圖示（不是整列）掛 `DragGesture(minimumDistance: 2, coordinateSpace: .named("cardListSpace"))`
2. `onChanged`：算出 `draggedCenterY`（用只記一次的 `dragStartMidY` + 即時 `dragOffsetY`），跟 `liveSectionItems` 裡其他列的 `rowFrames` 比對找出目標列，本地陣列 `move(fromOffsets:toOffset:)`，設 `awaitingLayoutRefresh = true`
3. `onEnded`：呼叫 `commitOrder` 寫回 SwiftData，重置所有狀態
4. List 上掛 `.onPreferenceChange(RowFramePreferenceKey.self)`：更新 `rowFrames`，並把 `awaitingLayoutRefresh` 清回 `false`

## 目前測試上的限制（這點可能才是問題核心）

**我完全沒辦法在真機上測試**，只能用 iOS Simulator + 一個內部工具（透過合成觸控事件 `touch_path`，指定一串 `(x, y, dt_ms)` 座標點模擬手指移動）。這個工具本身有幾個已知問題：

1. 座標空間換算常常抓不準（螢幕截圖像素 vs 模擬器工具吃的「device points」之間的縮放比例，這次測試中經驗值大約要除以 2.284，但不是每個 UI 區域都準）。
2. 沒辦法真的測試「長按」的時間閾值、手指的實際壓力/接觸面積、多點觸控等真機才有的細節。
3. 合成觸控事件的密度控制不了是否真的對應真機螢幕更新頻率下的觸控回報密度——這次特別測了 8ms 間隔但完全沒反應，不確定是模擬器把過密事件吃掉了，還是這個密度本身就有問題，沒辦法進一步確認。
4. **每一輪修正都是「在模擬器上驗證過看起來沒問題」才上傳，但使用者在真機上永遠復現得出來**。這代表：要嘛是模擬器跟真機在這個特定手勢（`DragGesture` 掛在一個很小的把手圖示上，套在 `List` 裡）上有實質行為差異，要嘛是我每次的合成觸控測試方式本身就沒有真的觸發到 bug 會出現的那個條件（例如：真的手指按壓的不穩定性、真機的觸控取樣率、SwiftUI 在真機 GPU/CPU 上的實際排版耗時跟模擬器不同導致 race window 大小不同）。

## 還沒試過、值得考慮的方向

1. **完全避開「其他列動態位置查找」這個模式**，改成純粹用「索引距離」而不是「像素位置」來判斷交換（例如：記錄每列的固定高度／或乾脆假設等高，用 `(draggedCenterY - startMidY) / averageRowHeight` 直接算出應該移動幾格，而不是每次都重新掃描 `rowFrames` 比對邊界）。這樣可以整個繞開「其他列位置資料過不過期」這個問題根源，不用再頭痛痛 race。
2. **改用一個獨立的座標系統／固定高度假設**，不透過 `GeometryReader`／`PreferenceKey` 這種要等排版才更新的機制。
3. **直接請使用者側錄一次「打開 Xcode 裝置主控台（Console app）連接真機」的 log**，看看真機上這段程式碼實際跑起來時，`onChanged` 觸發的頻率、`rowFrames` 更新的時間點，才能真正confirm race window 有多大——這是目前最大的資訊缺口：**完全沒有真機端的任何 log 或除錯資訊**，所有判斷都是「看使用者截圖/錄影 + 用模擬器複現」，這條路可能已經走到頭了。
4. 考慮整個換一種實作策略：用 `List` 原生 `.onMove`（第 1 輪用過的），但不透過 `editMode` 全域切換，而是**只讓「正在長按的那一列」局部進入可拖曳狀態**（如果 SwiftUI 版本支援的話），這樣可以吃到系統原生拖曳排序的穩定性，同時滿足「不用切模式」的需求。目前還沒試過這個折衷方案。
5. 錄影裡有出現「拖曳中一列跑到接近狀態列/控制中心」的畫面——這暗示 offset 數值一度變得非常大（大到接近整個螢幕高度）。這跟目前的「雪崩到分區底部」描述不完全一樣，值得进一步追問使用者：**到底是「跳到分區裡最後一張卡的位置」，還是「跳到完全超出清單範圍、接近螢幕頂部/底部邊緣」？** 這兩種症狀指向的 bug 機制不同，值得先問清楚再繼續猜。

## Android 對照（供參考，這邊已經修好且驗證過）

Android 版（`WSDeckBuilder-android/app/src/main/java/com/mark/wsdeck/ui/deck/DeckCardsView.kt`）也曾經歷過幾乎一樣的雪崩問題，最後修法核心概念相同：**換位後先暫停判定下一次交換，等真的收到新版面回報才恢復**（Android 端叫 `pendingSwapOldTop`，iOS 端叫 `awaitingLayoutRefresh`，機制對應但實作細節不同）。Android 這邊已經用 `adb`／`uiautomator` 在 Android Emulator 上實測驗證通過（快速連續拖曳、多次重開驗證持久化），使用者也沒有再回報問題。**這說明「換位後暫停判定」這個核心思路本身是對的**，iOS 這邊大概率是實作細節或平台特有的 race 沒堵乾淨，而不是整個方向錯了。
