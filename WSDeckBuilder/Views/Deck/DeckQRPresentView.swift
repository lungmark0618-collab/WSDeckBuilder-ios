import SwiftUI

/// 面對面分享牌組：直接把 QR 顯示在螢幕上讓朋友的手機掃，不用先出圖存檔、
/// 再傳來傳去佔空間——打牌現場最實用的分享方式。
struct DeckQRPresentView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss

    private var qrImage: UIImage? {
        DeckImageExporter.qrImage(from: DeckImageExporter.Payload.encode(deck: deck), scale: 12)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s24) {
                Spacer()
                if let qrImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .padding(Spacing.s16)
                        .background(.white, in: RoundedRectangle(cornerRadius: Radius.large))
                        .comfortShadow(.card)
                } else {
                    ContentUnavailableView("這副牌組還沒有卡", systemImage: "qrcode")
                }
                VStack(spacing: Spacing.s4) {
                    Text(deck.name).font(.headline)
                    Text("讓朋友直接用相機掃這個畫面，或用他 App 裡的掃描功能")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Spacer()
            }
            .padding(Spacing.s24)
            .navigationTitle("出示 QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
