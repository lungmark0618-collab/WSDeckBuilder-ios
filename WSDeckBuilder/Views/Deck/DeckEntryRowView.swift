import SwiftData
import SwiftUI

/// 牌組卡表單列。點擊開啟卡片詳情；刷版與張數調整集中在詳情頁處理。
struct DeckEntryRowView: View {
    let deck: Deck
    let card: Card
    /// 同名（跨卡號、跨刷版）合計，供 4 張上限標紅
    let totalForName: Int
    /// false = 純瀏覽（隱藏＋/－與刪除）
    var editable = true
    var onTap: () -> Void

    @Environment(\.modelContext) private var context
    private var overLimit: Bool { totalForName > DeckValidator.nameLimit }
    private var cardTotal: Int { deck.count(of: card) }

    /// 未展開時的小標籤，如 RR×2 SR×1
    private var raritySummary: String {
        card.printings.compactMap { printing in
            let count = deck.entry(forPrinting: printing.id)?.count ?? 0
            return count > 0 ? "\(printing.rarity)×\(count)" : nil
        }.joined(separator: " ")
    }

    var body: some View {
        label.swipeActions(edge: .trailing) {
            if editable {
                Button(role: .destructive) {
                    for printing in card.printings {
                        if let entry = deck.entry(forPrinting: printing.id) {
                            deck.adjust(printingID: printing.id, by: -entry.count,
                                        context: context)
                        }
                    }
                } label: {
                    Label("移除", systemImage: "trash")
                }
            }
        }
    }

    /// 牌組中實際放的刷版優先，沒有才退回普卡
    private var displayPrinting: Printing {
        card.printings.first { (deck.entry(forPrinting: $0.id)?.count ?? 0) > 0 }
            ?? card.defaultPrinting
    }

    private var label: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // 純文字清單太難掃視，補一張縮圖當視覺錨點
                CardImageView(printing: displayPrinting,
                              cardName: card.nameZH,
                              landscape: card.cardType == .climax)
                    .frame(width: card.cardType == .climax ? 52 : 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.nameZH)
                        .font(.callout)
                        .foregroundStyle(overLimit ? .red : .primary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if let level = card.level, card.cardType != .climax {
                            Text("Lv\(level)")
                        }
                        Text(raritySummary.isEmpty ? card.id : raritySummary)
                    }
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Text("×\(cardTotal)")
                    .font(.body.monospacedDigit().bold())
                    .foregroundStyle(overLimit ? .red : .primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}
