import SwiftUI

/// 全域浮動聊天按鈕，疊在分頁畫面右下角、Tab Bar 上方；拖曳可以調整
/// 上下位置，避免擋住畫面裡剛好在那個高度的重要按鈕
struct FloatingChatButton: View {
    @Environment(AIChatCoordinator.self) private var coordinator
    @Environment(AppearanceSettings.self) private var appearance
    @State private var dragOffsetY: CGFloat = 0
    @State private var settledOffsetY: CGFloat = 0

    var body: some View {
        Button {
            coordinator.openGeneral()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(appearance.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .accessibilityLabel("問 AI")
        .offset(y: settledOffsetY + dragOffsetY)
        .gesture(
            DragGesture()
                .onChanged { value in dragOffsetY = value.translation.height }
                .onEnded { value in
                    settledOffsetY += value.translation.height
                    dragOffsetY = 0
                }
        )
        .padding(.trailing, Spacing.s16)
        .padding(.bottom, 90)
    }
}
