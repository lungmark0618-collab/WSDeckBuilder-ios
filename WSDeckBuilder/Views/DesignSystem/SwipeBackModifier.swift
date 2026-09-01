import SwiftUI

/// 讓 NavigationStack 推進的畫面整個範圍都能向右滑退回上一頁，不侷限系統手勢
/// 那條窄窄的左邊緣——大螢幕單手操作常常滑不到邊緣，尤其從圖鑑作品選單點進
/// 某部作品後想滑回選單這種情境。
///
/// 用 DragGesture 判斷「明顯偏水平的右滑」才觸發 `dismiss()`（在 NavigationStack
/// 推進的畫面裡，dismiss() 就是退回上一頁），並用 simultaneousGesture 而不是
/// gesture，讓畫面本身的捲動、左右滑動卡片這些手勢還能正常運作，不會被搶走。
private struct SwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard value.translation.width > 80,
                          abs(value.translation.height) < 60 else { return }
                    dismiss()
                }
        )
    }
}

extension View {
    /// 整個畫面都能滑動退回上一頁，不侷限系統手勢的邊緣窄條。
    /// 掛在 `navigationDestination`／`NavigationLink` 推進的目的畫面上。
    func swipeToGoBack() -> some View { modifier(SwipeBackModifier()) }
}
