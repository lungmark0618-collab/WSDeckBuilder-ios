import SwiftUI

/// 全域浮動聊天按鈕：可以拖到畫面任何位置（即時跟著手指，左右上下都可以），
/// 放著不動一段時間會收到最近的那個邊緣、只留一點點探出來；點探出來的部分
/// 或再拖它都會展開回來。整個按鈕可以在「設定」關掉。
struct FloatingChatButton: View {
    @Environment(\.appSurface) private var surface
    @Environment(AIChatCoordinator.self) private var coordinator
    @Environment(AppearanceSettings.self) private var appearance
    @AppStorage("aiChatButtonEnabled") private var isEnabled = true

    private let size: CGFloat = 52
    private let peek: CGFloat = 18
    private let idleDelay: UInt64 = 3_000_000_000

    /// 使用者自己拖過的位置；nil 代表還沒拖過，用預設右下角
    @State private var position: CGPoint?
    @State private var dragTranslation: CGSize = .zero
    /// nil＝展開；true／false＝收在左邊／右邊
    @State private var collapsedToLeft: Bool?
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        if isEnabled {
            GeometryReader { geo in
                let defaultPos = CGPoint(x: geo.size.width - size / 2 - Spacing.s16,
                                         y: geo.size.height - size / 2 - 90)
                let basePos = position ?? defaultPos
                let restingPos: CGPoint = {
                    guard let collapsedToLeft else { return basePos }
                    let x = collapsedToLeft ? -size / 2 + peek : geo.size.width + size / 2 - peek
                    return CGPoint(x: x, y: basePos.y)
                }()
                let livePos = CGPoint(x: restingPos.x + dragTranslation.width,
                                      y: restingPos.y + dragTranslation.height)

                button
                    .position(livePos)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                cancelHide()
                                if collapsedToLeft != nil { collapsedToLeft = nil }
                                dragTranslation = value.translation
                            }
                            .onEnded { value in
                                // 位移很小視為點一下，不是拖曳；點在收合狀態下要展開，
                                // 展開狀態下直接開聊天視窗
                                let moved = abs(value.translation.width) > 4 || abs(value.translation.height) > 4
                                dragTranslation = .zero
                                if !moved {
                                    if collapsedToLeft != nil {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            collapsedToLeft = nil
                                        }
                                        scheduleHide()
                                    } else {
                                        coordinator.openGeneral()
                                        scheduleHide()
                                    }
                                    return
                                }
                                var next = CGPoint(x: restingPos.x + value.translation.width,
                                                   y: restingPos.y + value.translation.height)
                                next.x = min(max(next.x, size / 2), geo.size.width - size / 2)
                                next.y = min(max(next.y, size / 2), geo.size.height - size / 2)
                                position = next
                                collapsedToLeft = nil
                                scheduleHide()
                            }
                    )
                    .onAppear { scheduleHide() }
                    .onDisappear { hideTask?.cancel() }
            }
            .allowsHitTesting(true)
        }
    }

    private var button: some View {
        Image(systemName: "bubble.left.and.bubble.right.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(width: size, height: size)
            .background(surface.panelElevated, in: Circle())
            .overlay { Circle().strokeBorder(appearance.accentColor.opacity(0.25), lineWidth: 1) }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            .opacity(collapsedToLeft != nil ? 0.6 : 1)
            .accessibilityLabel("問 AI")
    }

    private func cancelHide() {
        hideTask?.cancel()
        hideTask = nil
    }

    /// 放著不動 idleDelay 秒後收到最近的邊緣，不干擾使用者接下來想做的事
    private func scheduleHide() {
        cancelHide()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: idleDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                collapsedToLeft = isNearLeftEdge()
            }
        }
    }

    private func isNearLeftEdge() -> Bool {
        // UIScreen 在這裡夠用：只是決定收左還是收右，不需要真的量容器寬度
        let screenWidth = UIScreen.main.bounds.width
        let x = position?.x ?? (screenWidth - size / 2 - Spacing.s16)
        return x < screenWidth / 2
    }
}
