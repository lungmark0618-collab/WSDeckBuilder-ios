import AVFoundation
import SwiftUI

/// App 內建即時相機掃描：不用先開系統相機拍照存圖，鏡頭直接對準朋友出示
/// 的畫面就能掃到，掃到後跟 wsdeck:// 連結走同一條預覽流程。
struct DeckQRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DeckImportCoordinator.self) private var deckImport
    @State private var authStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var didDetect = false

    var body: some View {
        NavigationStack {
            ZStack {
                switch authStatus {
                case .authorized:
                    QRScannerView { text in
                        guard !didDetect else { return }
                        didDetect = true
                        handleDetected(text)
                    }
                    .ignoresSafeArea()
                    VStack {
                        Spacer()
                        Text("把朋友出示的 QR 對準鏡頭")
                            .font(.subheadline)
                            .padding(.horizontal, Spacing.s16)
                            .padding(.vertical, Spacing.s8)
                            .background(.black.opacity(0.6), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(.bottom, Spacing.s32)
                    }
                case .notDetermined:
                    ProgressView()
                        .task { await requestAccess() }
                case .denied, .restricted:
                    ContentUnavailableView(
                        "沒有相機權限", systemImage: "camera.fill",
                        description: Text("請到「設定」開啟本 App 的相機權限才能掃描。"))
                @unknown default:
                    EmptyView()
                }
            }
            .background(.black)
            .navigationTitle("掃描 QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authStatus = granted ? .authorized : .denied
    }

    private func handleDetected(_ text: String) {
        dismiss()
        // 等這個 sheet 真的收起來再彈預覽，兩個 sheet 疊在一起會被系統忽略
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            deckImport.handle(scannedText: text)
        }
    }
}
