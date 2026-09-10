import SwiftUI

/// 返回只從右側邊緣開始，避免與卡片輪播、橫向清單、滑桿和拖曳排序衝突。
enum BackSwipePolicy {
    static func shouldReturn(horizontal: CGFloat, vertical: CGFloat) -> Bool {
        horizontal < -80 && abs(horizontal) > abs(vertical) * 1.5
    }
}

private struct SwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)?

    func body(content: Content) -> some View {
        content.overlay(alignment: .trailing) {
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
                .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                    guard BackSwipePolicy.shouldReturn(horizontal: value.translation.width,
                                                       vertical: value.translation.height) else { return }
                    if let action { action() } else { dismiss() }
                })
        }
    }
}

extension View {
    /// 原生系統返回仍可使用；App 另外提供右側邊緣向左滑返回。
    func swipeToGoBack(action: (() -> Void)? = nil) -> some View {
        modifier(SwipeBackModifier(action: action))
    }
}
