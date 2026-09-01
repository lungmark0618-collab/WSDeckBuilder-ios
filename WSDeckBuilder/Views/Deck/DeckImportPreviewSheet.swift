import SwiftData
import SwiftUI

/// 掃朋友分享的牌組 QR（系統相機喚起這個 App）之後的預覽畫面：
/// 列出牌組內容，使用者按「加入牌組」才真的寫進資料庫，按「取消」就當作
/// 沒發生過，不會留下任何痕跡。
struct DeckImportPreviewSheet: View {
    let parsed: DeckImporter.Parsed
    let onDismiss: () -> Void

    @Environment(CardDatabase.self) private var database
    @Environment(\.modelContext) private var context
    @Query(sort: \Deck.createdAt) private var decks: [Deck]
    @AppStorage("activeDeckUUID") private var activeDeckUUID: String = ""
    @State private var importError: String?

    private var totalCount: Int { parsed.entries.reduce(0) { $0 + $1.count } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(parsed.entries, id: \.printingID) { entry in
                        HStack {
                            Text(database.card(forPrinting: entry.printingID)?.nameZH ?? entry.printingID)
                                .lineLimit(1)
                            Spacer(minLength: Spacing.s8)
                            Text("×\(entry.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("\(parsed.name)（共 \(totalCount) 張）")
                } footer: {
                    Text("這是朋友分享給你的牌組，按「加入牌組」才會存到你的牌組清單裡。")
                }
            }
            .navigationTitle("朋友分享的牌組")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", role: .cancel) { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入牌組") { importNow() }
                }
            }
            .alert("匯入失敗", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } })) {
                Button("好") {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func importNow() {
        do {
            let result = try DeckImporter.createDeck(
                from: parsed, database: database,
                existingNames: decks.map(\.name), context: context)
            activeDeckUUID = result.deck.uuid.uuidString
            onDismiss()
        } catch {
            importError = error.localizedDescription
        }
    }
}
