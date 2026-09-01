import AVFoundation
import SwiftUI

/// 即時相機 QR 掃描：不用先拍照存檔，鏡頭對準朋友出示的 QR 就直接讀出來。
/// 用 AVFoundation 而不是 VisionKit 的 DataScannerViewController——後者最低
/// 支援到 iOS 16 且部分機型不保證有，AVCaptureMetadataOutput 相容性更廣。
struct QRScannerView: UIViewControllerRepresentable {
    /// 每偵測到一個 QR 就會呼叫一次；同一個內容連續偵測到不會重複呼叫
    var onDetect: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onDetect = onDetect
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onDetect: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var lastDetected: String?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureSession()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [session] in session.stopRunning() }
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        private var previewLayer: AVCaptureVideoPreviewLayer?

        private func configureSession() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let code = metadataObjects
                .compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue })
                .first else { return }
            // 鏡頭對著同一個碼每幀都會觸發，同一個內容只處理一次
            guard code != lastDetected else { return }
            lastDetected = code
            onDetect?(code)
        }
    }
}
