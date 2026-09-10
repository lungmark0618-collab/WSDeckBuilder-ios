import SwiftData
import SwiftUI

private struct OpenAppSidebarKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openAppSidebar: () -> Void {
        get { self[OpenAppSidebarKey.self] }
        set { self[OpenAppSidebarKey.self] = newValue }
    }
}

struct SidebarMenuButton: View {
    @Environment(\.openAppSidebar) private var open
    var body: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            open()
        } label: { Image(systemName: "line.3.horizontal") }
            .accessibilityLabel("開啟導覽選單")
    }
}

enum SidebarImportAction: String, CaseIterable {
    case camera, photo, file, text
    var title: String {
        switch self {
        case .camera: "相機掃描 QR Code"
        case .photo: "從圖片匯入"
        case .file: "從檔案匯入"
        case .text: "貼上牌表文字"
        }
    }
    var icon: String {
        switch self {
        case .camera: "camera.viewfinder"
        case .photo: "photo"
        case .file: "folder"
        case .text: "doc.on.clipboard"
        }
    }
}

struct AppSidebarView: View {
    @Environment(\.appSurface) private var surface
    @Environment(CardDatabase.self) private var database
    @Environment(PinnedDecksStore.self) private var pinned
    @Environment(FavoriteTitlesStore.self) private var favorites
    @Query(sort: \Deck.createdAt) private var decks: [Deck]
    @AppStorage("activeDeckUUID") private var activeUUID = ""
    @State private var importsExpanded = false
    let onClose: () -> Void
    let onTab: (RootTabView.Tab) -> Void
    let onDeck: (UUID) -> Void
    let onTitle: (String) -> Void
    let onImport: (SidebarImportAction) -> Void
    let onAI: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("WS Deck Builder").font(.headline)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("關閉選單")
            }
            .padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let active = decks.first(where: { $0.uuid.uuidString == activeUUID }) {
                        heading("繼續編輯")
                        row(active.name, icon: "pencil", subtitle: "\(active.totalCount) 張卡片") { onDeck(active.uuid) }
                    }
                    heading("瀏覽")
                    row("首頁", icon: "house") { onTab(.home) }
                    row("圖鑑", icon: "magnifyingglass") { onTab(.catalog) }
                    row("我的牌組", icon: "rectangle.stack") { onTab(.deck) }
                    heading("常用牌組")
                    let pinnedDecks = pinned.uuids.compactMap { id in decks.first { $0.uuid.uuidString == id } }
                    if pinnedDecks.isEmpty {
                        hint("在牌組清單向右滑，即可釘選常用牌組。")
                    }
                    ForEach(pinnedDecks) { deck in
                        row(deck.name, icon: "pin", subtitle: "\(deck.totalCount) 張卡片") { onDeck(deck.uuid) }
                    }
                    heading("收藏作品")
                    if favorites.titleCodes.isEmpty {
                        hint("在圖鑑點作品上的星星，就能從這裡快速開啟。")
                    }
                    ForEach(favorites.titleCodes.sorted(), id: \.self) { code in
                        row(database.scopeDisplayName(code), icon: "star") { onTitle(code) }
                    }
                    heading("工具")
                    DisclosureGroup(isExpanded: $importsExpanded) {
                        ForEach(SidebarImportAction.allCases, id: \.self) { action in
                            row(action.title, icon: action.icon) { onImport(action) }
                        }
                    } label: {
                        Label("匯入牌組", systemImage: "square.and.arrow.down")
                            .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 12)
                    row("AI 助手", icon: "bubble.left.and.bubble.right", action: onAI)
                    Divider().padding(.vertical, 8)
                    row("外觀與設定", icon: "gearshape") { onTab(.settings) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .foregroundStyle(Color.primary)
        .accessibilityAddTraits(.isModal)
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(surface.secondaryText)
            .padding(.top, 20).padding(.horizontal, 12)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(surface.secondaryText)
            .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func row(_ title: String, icon: String, subtitle: String? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body).multilineTextAlignment(.leading)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(surface.secondaryText) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
