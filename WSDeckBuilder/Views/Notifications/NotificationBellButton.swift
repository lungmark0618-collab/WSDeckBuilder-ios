import SwiftUI

/// 圖鑑分頁右上角的鈴鐺，開發者發的通知有未讀時顯示紅點或數字（使用者在設定裡選）
struct NotificationBellButton: View {
    @Environment(AnnouncementCenter.self) private var center
    @Environment(OnboardingCoordinator.self) private var onboarding
    @State private var showList = false

    var body: some View {
        Button {
            showList = true
            onboarding.notify(.notifications)
        } label: {
            // 固定用沒有內建圓點的 "bell"——"bell.badge" 這個 SF Symbol 本身就
            // 畫了一個小圓點，跟我們自己疊加的紅點/數字會擠在同一個角落重疊。
            // 額外給個 24x24 的框——工具列現在是系統的玻璃分組樣式，容器邊界
            // 比舊版窄，徽章位移量稍微大一點就會被裁到，框大一點、位移收斂一點
            // 才有安全空間
            Image(systemName: "bell")
                .frame(width: 24, height: 24)
                .overlay(alignment: .topTrailing) { badge }
        }
        .onboardingAnchor(.notifications)
        .sheet(isPresented: $showList) {
            AnnouncementListView()
        }
    }

    @ViewBuilder
    private var badge: some View {
        if center.unreadCount > 0 {
            switch center.badgeStyle {
            case .dot:
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
            case .count:
                Text(center.unreadCount > 99 ? "99+" : "\(center.unreadCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 15, minHeight: 15)
                    .background(.red, in: Capsule())
                    .offset(x: 6, y: -5)
            }
        }
    }
}
