import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 單一牌組編輯，依等級分組；卡表／統計／缺卡切換，卡表可切圖片或清單（§4.3）
struct DeckDetailView: View {
    @Bindable var deck: Deck
    @Environment(CardDatabase.self) private var database
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .cards
    @State private var detailCard: Card?
    @State private var isEditing = false
    @State private var isPickingCover = false
    /// 拖曳排序中，正在拖的卡片 id——用舊式 onDrag/onDrop(delegate:) 而不是
    /// .draggable/.dropDestination，因為後者在 List 裡跟 Section、Button
    /// 標籤混用時，實測長按會浮起來但放開完全不會真的換位置
    @State private var draggingCardID: String?
    /// 缺卡頁是否連已收齊的一起顯示
    @State private var showCollected = false
    /// 卡表的顯示方式（與圖鑑分頁各自記憶）
    @AppStorage("deckUsesGrid") private var usesGrid = true
    /// 出好的牌組圖片；有值就跳分享面板
    @State private var deckImageURL: URL?
    @State private var isRenderingImage = false
    @State private var showQRPresent = false

    @Query private var collection: [CollectionEntry]

    private enum Mode: String, CaseIterable {
        case cards = "卡表"
        case stats = "統計"
        case shortage = "缺卡"
    }

    private var shortages: [CollectionStore.Shortage] {
        CollectionStore.shortages(deck: deck, database: database,
                                  index: CollectionStore.index(collection))
    }

    private var countedItems: [DeckValidator.CountedCard] {
        DeckExporter.groupByCard(deck: deck, database: database)
            .map { DeckValidator.CountedCard(card: $0.card, count: $0.count) }
    }

    private var validation: DeckValidator.Result {
        DeckValidator.validate(countedItems)
    }

    var body: some View {
        VStack(spacing: 0) {
            validationHeader
            Picker("模式", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, Spacing.s8)

            switch mode {
            case .cards:
                if usesGrid { cardGrid } else { cardList }
            case .stats: DeckStatsView(items: countedItems)
            case .shortage: shortageList
            }
        }
        .background(AppSurface.background)
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 卡表模式才需要切換圖片／清單
            if mode == .cards {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { usesGrid.toggle() }
                    } label: {
                        Image(systemName: usesGrid ? "list.bullet" : "square.grid.3x3")
                    }
                    .accessibilityLabel(usesGrid ? "改為清單顯示" : "改為圖片顯示")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { actionMenu }
            ToolbarItem(placement: .confirmationAction) {
                if isEditing {
                    Button("完成") {
                        deck.updatedAt = .now
                        try? context.save()
                        withAnimation { isEditing = false }
                    }
                    .fontWeight(.bold)
                } else {
                    Button("編輯") {
                        withAnimation { isEditing = true }
                    }
                }
            }
        }
        .sheet(item: $detailCard) { card in
            // 依畫面上的分區順序帶入，滑動順序才跟看到的一致
            CardDetailSheet(card: card, siblings: orderedCards, deck: deck)
        }
        .sheet(isPresented: $isPickingCover) {
            DeckCoverPickerView(deck: deck)
        }
        .sheet(item: $deckImageURL) { url in
            ShareSheet(items: [url])
        }
        .sheet(isPresented: $showQRPresent) {
            DeckQRPresentView(deck: deck)
        }
    }

    // MARK: - 規則驗證列（§4.4.3）

    private var validationHeader: some View {
        HStack(spacing: Spacing.s8) {
            ruleChip("\(validation.totalCount)/50", ok: validation.totalOK)
            ruleChip("CX \(validation.climaxCount)/8", ok: validation.climaxOK)
            if !validation.namesOK {
                ruleChip("同名超過4張", ok: false, symbol: "exclamationmark.triangle.fill")
            }
            if validation.mixedTitles {
                ruleChip("跨作品混搭", ok: false, symbol: "exclamationmark.triangle.fill",
                         tint: .orange)
            }
            Spacer(minLength: 0)
            if validation.isLegal {
                Label("符合規則", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.s8)
        .background {
            ZStack {
                Color(.secondarySystemBackground)
                CardArtBackdrop(printing: deck.coverPrinting(database: database),
                                blur: 20, opacity: 1, saturation: 2.0)
                LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom)
            }
            .clipped()
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    /// 深色背景上的規則標籤
    private func ruleChip(_ text: String, ok: Bool,
                          symbol: String? = nil, tint: Color = .red) -> some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.caption2)
            }
            Text(text)
        }
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(ok ? .green : (symbol == nil ? .white : tint))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.black.opacity(0.32), in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        }
    }

    // MARK: - 圖片網格（依等級分區，含張數徽章與快速增減）

    private var cardGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.s8, pinnedViews: [.sectionHeaders]) {
                ForEach(sections, id: \.title) { section in
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.s12)],
                                  spacing: Spacing.s16) {
                            // 依刷版分格：1 SR + 3 R 就顯示 SR 與 R 各一格
                            ForEach(printingTiles(for: section), id: \.printing.id) { tile in
                                CardGridItemView(card: tile.card, deck: deck,
                                                 printing: tile.printing,
                                                 editable: isEditing) {
                                    detailCard = tile.card
                                }
                                .contextMenu {
                                    Button {
                                        deck.coverPrintingID = tile.printing.id
                                        deck.updatedAt = .now
                                        try? context.save()
                                    } label: {
                                        Label("設為牌組封面", systemImage: "photo.badge.checkmark")
                                    }
                                    if !deck.coverPrintingID.isEmpty {
                                        Button {
                                            deck.coverPrintingID = ""
                                            try? context.save()
                                        } label: {
                                            Label("恢復自動封面", systemImage: "arrow.uturn.backward")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    } header: {
                        Text("\(section.title) (\(section.count))")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(.bar)
                    }
                }
            }
            // 純 ScrollView 用 safeAreaInset 加底部淨空會讓整個 ScrollView 卡住滑不動
            // （原因不明，換成直接加大內容 padding 才是穩定作法）
            .padding(.bottom, 140)
        }
        .scrollContentBackground(.hidden)
        .background(AppSurface.background)
        .overlay {
            if deck.entries.isEmpty {
                ContentUnavailableView("牌組是空的",
                                       systemImage: "rectangle.stack.badge.plus",
                                       description: Text("到「圖鑑」分頁選擇此牌組後按＋加卡"))
            }
        }
    }

    // MARK: - 卡表

    private var cardList: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section("\(section.title) (\(section.count))") {
                    ForEach(section.items, id: \.card.id) { item in
                        DeckEntryRowView(
                            deck: deck,
                            card: item.card,
                            totalForName: DeckValidator.nameCount(of: item.card,
                                                                  in: countedItems),
                            editable: isEditing) {
                            detailCard = item.card
                        }
                        // 不用先切「排序模式」，長按任一列直接拖到想要的位置放開即可。
                        // 用舊式 onDrag/onDrop(delegate:)，不用 .draggable/.dropDestination——
                        // 後者在 List 裡跟這一列的 Button 標籤混用時，實測長按會浮起來，
                        // 但放開完全不會真的換位置（drop 沒有被觸發）
                        .onDrag {
                            draggingCardID = item.card.id
                            return NSItemProvider(object: item.card.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: CardReorderDropDelegate(
                            targetID: item.card.id,
                            items: section.items,
                            draggingID: $draggingCardID,
                            onMove: { from, to in moveCards(in: section, from: from, to: to) }
                        ))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppSurface.background)
        .clearsGlassTabBar()
        .overlay {
            if deck.entries.isEmpty {
                ContentUnavailableView("牌組是空的",
                                       systemImage: "rectangle.stack.badge.plus",
                                       description: Text("到「圖鑑」分頁選擇此牌組後按＋加卡"))
            }
        }
    }

    /// 把某個分區內拖曳後的新順序，寫回整副牌的排序記錄——其他分區的位置不動
    private func moveCards(in section: LevelSection, from: IndexSet, to: Int) {
        var sectionIDs = section.items.map(\.card.id)
        sectionIDs.move(fromOffsets: from, toOffset: to)

        let allIDs = DeckExporter.groupByCard(deck: deck, database: database).map(\.card.id)
        var fullOrder = deck.customOrder(sorting: allIDs)
        let sectionSet = Set(sectionIDs)
        var newValues = sectionIDs.makeIterator()
        for i in fullOrder.indices where sectionSet.contains(fullOrder[i]) {
            if let next = newValues.next() { fullOrder[i] = next }
        }
        deck.setCardOrder(fullOrder, context: context)
    }

    /// 拖曳排序放開時的目標——手指拖著的那張卡「進入」某一列的範圍就觸發一次
    /// 交換，跟 Android 那邊「量每列位置決定交換」是同一個思路
    private struct CardReorderDropDelegate: DropDelegate {
        let targetID: String
        let items: [DeckExporter.CardCount]
        @Binding var draggingID: String?
        let onMove: (IndexSet, Int) -> Void

        func dropEntered(info: DropInfo) {
            guard let draggingID, draggingID != targetID,
                  let from = items.firstIndex(where: { $0.card.id == draggingID }),
                  let to = items.firstIndex(where: { $0.card.id == targetID })
            else { return }
            onMove(IndexSet(integer: from), to > from ? to + 1 : to)
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            draggingID = nil
            return true
        }
    }

    private struct LevelSection {
        let title: String
        let count: Int
        let items: [DeckExporter.CardCount]
    }

    private struct PrintingTile {
        let card: Card
        let printing: Printing
    }

    /// 把每張卡展開成「牌組中有放的刷版」各一格
    private func printingTiles(for section: LevelSection) -> [PrintingTile] {
        section.items.flatMap { item in
            item.card.printings.compactMap { printing in
                (deck.entry(forPrinting: printing.id)?.count ?? 0) > 0
                    ? PrintingTile(card: item.card, printing: printing)
                    : nil
            }
        }
    }

    /// 卡表分區攤平成一串，供詳情頁左右滑動
    private var orderedCards: [Card] {
        sections.flatMap { $0.items.map(\.card) }
    }

    private var sections: [LevelSection] {
        let unordered = DeckExporter.groupByCard(deck: deck, database: database)
        let orderIndex = Dictionary(uniqueKeysWithValues:
            deck.customOrder(sorting: unordered.map(\.card.id)).enumerated().map { ($1, $0) })
        let grouped = unordered.sorted { (orderIndex[$0.card.id] ?? 0) < (orderIndex[$1.card.id] ?? 0) }
        var result: [LevelSection] = []
        for level in 0...3 {
            let items = grouped.filter { $0.card.level == level && $0.card.cardType != .climax }
            if !items.isEmpty {
                result.append(.init(title: "Lv\(level)",
                                    count: items.reduce(0) { $0 + $1.count },
                                    items: items))
            }
        }
        let climax = grouped.filter { $0.card.cardType == .climax }
        if !climax.isEmpty {
            result.append(.init(title: "CX",
                                count: climax.reduce(0) { $0 + $1.count },
                                items: climax))
        }
        return result
    }

    // MARK: - 缺卡清單（對照「我的收藏」算出還要收哪些）

    private var shortageList: some View {
        // 收齊的卡會從缺卡清單消失，開著這個才改得回來（例如標錯了）
        let items = showCollected ? allTrackedItems : shortages
        let total = shortages.reduce(0) { $0 + $1.missing }
        return List {
            if items.isEmpty {
                ContentUnavailableView("這副牌都收齊了",
                                       systemImage: "checkmark.seal.fill",
                                       description: Text("牌組內每張卡的擁有數都足夠"))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(items) { item in
                        shortageRow(item)
                    }
                } header: {
                    HStack {
                        Text(total > 0 ? "還缺 \(total) 張（共 \(shortages.count) 種）"
                                       : "都收齊了")
                        Spacer()
                        Button(showCollected ? "只看缺的" : "顯示全部") {
                            withAnimation { showCollected.toggle() }
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                } footer: {
                    Text("直接在這裡按＋標記入手，或往左滑一次收齊整組。數量記在「我的收藏」，"
                         + "其他牌組共用。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .clearsGlassTabBar()
        .toolbar {
            if mode == .shortage, !shortages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全部收齊") { fillAll() }
                        .font(.caption)
                }
            }
        }
    }

    /// 牌組內每個刷版的收藏進度（含已收齊的），供「顯示全部」使用
    private var allTrackedItems: [CollectionStore.Shortage] {
        let index = CollectionStore.index(collection)
        return deck.entries
            .compactMap { entry -> CollectionStore.Shortage? in
                guard let card = database.card(forPrinting: entry.printingID),
                      let printing = database.printing(id: entry.printingID) else { return nil }
                return CollectionStore.Shortage(printing: printing, card: card,
                                                needed: entry.count,
                                                owned: index[entry.printingID] ?? 0)
            }
            .sorted { $0.printing.id < $1.printing.id }
    }

    private func shortageRow(_ item: CollectionStore.Shortage) -> some View {
        let done = item.missing == 0
        return HStack(spacing: 10) {
            CardImageView(printing: item.printing,
                          cardName: item.card.nameZH,
                          landscape: item.card.cardType == .climax)
                .frame(width: item.card.cardType == .climax ? 60 : 42)
                .opacity(done ? 0.45 : 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.card.nameZH)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(done ? .secondary : .primary)
                HStack(spacing: 6) {
                    Text(item.printing.rarity).font(.caption2.bold())
                    Text(item.printing.id).font(.caption2.monospaced())
                }
                .foregroundStyle(.secondary)
                if done {
                    Label("已收齊", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Text("還缺 \(item.missing)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 4)

            // 就地加減，不用再進詳情頁
            VStack(spacing: 2) {
                CountStepper(count: item.owned) { delta in
                    CollectionStore.adjust(printingID: item.printing.id, by: delta,
                                           entries: collection, context: context)
                }
                Text("\(item.owned)/\(item.needed)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { detailCard = item.card }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !done {
                Button {
                    fill(item)
                } label: {
                    Label("一次收齊", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
    }

    /// 把某張補到牌組需要的張數
    private func fill(_ item: CollectionStore.Shortage) {
        guard item.missing > 0 else { return }
        CollectionStore.adjust(printingID: item.printing.id, by: item.missing,
                               entries: collection, context: context)
    }

    private func fillAll() {
        for item in shortages { fill(item) }
    }

    // MARK: - 牌組操作＋匯出（§4.4.5，ShareLink）

    private var actionMenu: some View {
        Menu {
            Section {
                Button {
                    isPickingCover = true
                } label: {
                    Label("選擇封面", systemImage: "photo.badge.checkmark")
                }
                .disabled(deck.entries.isEmpty)
            }
            Section {
                Button {
                    showQRPresent = true
                } label: {
                    Label("出示 QR 給朋友掃", systemImage: "qrcode")
                }
                .disabled(deck.entries.isEmpty)
            }
            Section("匯出") {
                Button {
                    Task { await makeDeckImage() }
                } label: {
                    Label("匯出牌組圖片（可掃回）", systemImage: "photo")
                }
                .disabled(deck.entries.isEmpty || isRenderingImage)

                ShareLink(item: DeckExporter.simpleText(deck: deck, database: database)) {
                    Label("匯出牌表（簡潔版）", systemImage: "doc.plaintext")
                }
                ShareLink(item: DeckExporter.collectorText(deck: deck, database: database)) {
                    Label("匯出收牌清單（含刷版）", systemImage: "list.bullet.rectangle")
                }
                ShareLink(item: CollectionStore.shortageText(deck: deck, shortages: shortages)) {
                    Label("匯出缺卡清單", systemImage: "cart")
                }
                if let url = DeckExporter.jsonFile(deck: deck) {
                    ShareLink(item: url,
                              preview: SharePreview("\(deck.name).json")) {
                        Label("匯出 JSON 備份（可再匯入）", systemImage: "curlybraces")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    /// 出圖只用已快取的卡圖，不在這裡連網下載——牌店現場網路差時
    /// 至少還出得了圖，缺圖的位置畫卡名佔位。
    @MainActor
    private func makeDeckImage() async {
        isRenderingImage = true
        defer { isRenderingImage = false }
        let printings = DeckExporter.groupByCard(deck: deck, database: database)
            .map(\.card.defaultPrinting)
        let images = await ImageCache.shared.cachedOnly(printings)
        deckImageURL = DeckImageExporter.imageFile(deck: deck, database: database,
                                                   images: images)
    }
}
