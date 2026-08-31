import SwiftUI

/// 鈴鐺點開後的通知列表。開場即視為已讀——跟大多數通知中心一樣，
/// 「看過列表」就算已讀，不用逐則點開才算數。
struct AnnouncementListView: View {
    @Environment(AnnouncementCenter.self) private var center
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Group {
                if center.items.isEmpty {
                    ContentUnavailableView("目前沒有通知", systemImage: "bell.slash")
                } else {
                    List {
                        ForEach(center.items) { item in
                            row(for: item)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation { center.delete(item) }
                                    } label: {
                                        Label("刪除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("全部刪除", role: .destructive) { confirmDeleteAll = true }
                        .disabled(center.items.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("全部刪除通知？", isPresented: $confirmDeleteAll) {
                Button("刪除", role: .destructive) {
                    withAnimation { center.deleteAll() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("目前看到的通知都會消失，之後也不會再出現。")
            }
        }
        .onAppear { center.markAllRead() }
    }

    private func row(for item: Announcement) -> some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            if center.isUnread(item) {
                Circle().fill(.red).frame(width: 7, height: 7)
                    .padding(.top, 6)
            }
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(item.title).font(.headline)
                Text(item.body).font(.subheadline).foregroundStyle(.secondary)
                Text(item.date).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, Spacing.s4)
    }
}
