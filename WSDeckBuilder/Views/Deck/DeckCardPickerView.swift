import SwiftUI

/// 選牌綁定來源牌組，與主圖鑑的純瀏覽模式分開。
struct DeckCardPickerView: View {
    let deckUUID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var path: [CatalogRoute] = []

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("完成") { dismiss() }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            CardCatalogView(route: .root, editingDeckUUID: deckUUID)
                .navigationDestination(for: CatalogRoute.self) { route in
                    CardCatalogView(route: route, editingDeckUUID: deckUUID)
                        .toolbar { doneButton }
                }
                .toolbar { doneButton }
        }
        .swipeToGoBack {
            if path.isEmpty { dismiss() } else { path.removeLast() }
        }
    }
}
