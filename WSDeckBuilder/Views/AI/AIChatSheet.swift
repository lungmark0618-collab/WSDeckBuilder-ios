import SwiftUI

/// 浮動聊天視窗：問卡牌效果／問規則共用同一個輸入框跟對話串
struct AIChatSheet: View {
    @Environment(\.appSurface) private var surface
    @Environment(AIChatCoordinator.self) private var coordinator
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack {
            VStack(spacing: 0) {
                if let card = coordinator.cardContext?.card {
                    cardContextBanner(card)
                }
                if !RulesReference.isAvailable {
                    rulesUnavailableBanner
                }
                messageList
                inputBar
            }
            .background(surface.background)
            .navigationTitle("問 AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .swipeToGoBack()
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.s12) {
                    if coordinator.messages.isEmpty {
                        emptyState
                    }
                    ForEach(coordinator.messages) { message in
                        AIChatBubble(message: message).id(message.id)
                    }
                }
                .padding(Spacing.s16)
            }
            .onChange(of: coordinator.messages.count) {
                guard let last = coordinator.messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text("可以問什麼？")
                .font(.subheadline.bold())
            Text("・這張卡是什麼效果、能不能跟某張卡連動\n・規則問題，例如：安可跟重置的順序、CX combo 怎麼判定")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardContextBanner(_ card: Card) -> some View {
        HStack(spacing: Spacing.s8) {
            Image(systemName: "rectangle.stack.fill")
                .foregroundStyle(appearance.accentColor)
            Text("已帶入卡片：\(card.nameZH)")
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer()
            Button {
                coordinator.clearCardContext()
            } label: {
                Text("清除")
                    .font(.caption)
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.vertical, Spacing.s8)
        .background(appearance.accentColor.opacity(0.12))
    }

    private var rulesUnavailableBanner: some View {
        HStack(spacing: Spacing.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("尚未內建規則資料，規則類問題的答案不保證準確")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.vertical, Spacing.s4)
    }

    private var inputBar: some View {
        @Bindable var coordinator = coordinator
        return HStack(spacing: Spacing.s8) {
            TextField("輸入問題…", text: $coordinator.draftText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, Spacing.s12)
                .padding(.vertical, Spacing.s8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            Button {
                coordinator.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(coordinator.draftText.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? AnyShapeStyle(.tertiary) : AnyShapeStyle(appearance.accentColor))
            }
            .disabled(coordinator.draftText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Spacing.s12)
        .background(.bar)
    }
}

private struct AIChatBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Group {
                if message.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    // AI 回答常帶 **粗體** 這類 Markdown 語法，純文字顯示會看到
                    // 一堆星號、像是壞掉——解析成 AttributedString 才會是真的粗體
                    Text(Self.attributedText(message.text))
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, Spacing.s12)
            .padding(.vertical, Spacing.s8)
            .background(
                message.role == .user ? Color.accentColor : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .foregroundStyle(message.role == .user ? .white : .primary)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    /// 解析失敗（極少見的畸形語法）就退回純文字，不要整個訊息顯示不出來
    private static func attributedText(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
