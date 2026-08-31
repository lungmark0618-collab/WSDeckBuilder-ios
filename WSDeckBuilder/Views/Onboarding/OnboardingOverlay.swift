import SwiftUI

/// 讓畫面上的元件回報自己的位置，教學疊層才能在正確的地方畫光圈。
/// 沒被回報的步驟（例如「隨便點一部作品」這種不指定單一元件的步驟）
/// 疊層就只顯示提示卡，不畫光圈——兩種都合理，不是漏做。
struct OnboardingAnchorKey: PreferenceKey {
    static var defaultValue: [OnboardingStep: Anchor<CGRect>] = [:]
    static func reduce(value: inout [OnboardingStep: Anchor<CGRect>],
                       nextValue: () -> [OnboardingStep: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 標記「這個元件是教學某一步要指的目標」
    func onboardingAnchor(_ step: OnboardingStep) -> some View {
        anchorPreference(key: OnboardingAnchorKey.self, value: .bounds) { [step: $0] }
    }
}

/// 教學疊層本體：目標元件周圍的光圈 + 浮動提示卡。
/// 刻意不擋任何點擊（沒有全螢幕的深色遮罩、沒有 hit-testing 陷阱）——
/// 使用者要切分頁、要點別的地方，教學不應該擋路，這是「直接操作」教學
/// 跟傳統強制性 modal 導覽最大的差異。
struct OnboardingOverlay: View {
    let coordinator: OnboardingCoordinator
    let resolve: (OnboardingStep) -> CGRect?

    var body: some View {
        if let step = coordinator.currentStep {
            ZStack {
                if let rect = resolve(step) {
                    spotlight(around: rect)
                }
            }
            // 沒有光圈時 ZStack 會縮成 0 大小，疊在左上角的提示卡也會跟著跑掉——
            // 撐滿整個畫面，.overlay(alignment: .bottom) 才抓得到正確的底部位置。
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 這層先關掉 hit-testing，再用 .overlay 疊上提示卡——
            // .overlay 是後加的新圖層，不會被前面這個 false 波及，
            // 這樣才能兩全其美：光圈不擋點擊，提示卡上的按鈕仍可點。
            .allowsHitTesting(false)
            .overlay(alignment: .bottom) {
                tooltip(for: step)
                    .padding(.horizontal, Spacing.s16)
                    // 浮動玻璃分頁列佔掉螢幕最下面約 98pt，提示卡要墊高避開，
                    // 不然兩層疊在一起，「跳過教學」有時會被蓋到點不到
                    .padding(.bottom, 116)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: step)
        }
    }

    private func spotlight(around rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .background {
                RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            }
            .frame(width: rect.width + 16, height: rect.height + 16)
            .position(x: rect.midX, y: rect.midY)
            .shadow(color: .accentColor.opacity(0.5), radius: 10)
    }

    private func tooltip(for step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack {
                Text(step.title)
                    .font(.headline)
                Spacer()
                if let index = step.displayIndex {
                    Text("\(index) / \(OnboardingStep.countedTotal)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(step.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button("跳過教學") { coordinator.skip() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // 純文字按鈕預設點擊範圍只有字面大小，特地撐大好點
                    .padding(.vertical, Spacing.s8)
                    .padding(.trailing, Spacing.s16)
                    .contentShape(Rectangle())
                Spacer()
                if step != OnboardingStep.allCases.first {
                    Button("上一步") { coordinator.retreat() }
                        .buttonStyle(.outline)
                }
                Button(buttonLabel(for: step)) {
                    coordinator.advance()
                }
                .buttonStyle(.filled)
            }
        }
        .padding(Spacing.s16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .comfortShadow(.floating)
        .allowsHitTesting(true)
        .frame(maxWidth: 420)
    }

    private func buttonLabel(for step: OnboardingStep) -> String {
        if step == .welcome { return "開始" }
        if step == OnboardingStep.allCases.last { return "完成" }
        return "下一步"
    }
}
