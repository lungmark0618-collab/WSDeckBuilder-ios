import SwiftUI

/// 讓一排 chip 滿了自動換行，不再側滑捲動——篩選頁的等級／顏色／種類／
/// 特徵這些多選 chip 列原本用 ScrollView(.horizontal) 塞成一行，選項一多
/// 大半都藏在畫面外看不到，換成這個之後一次全部攤開。
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.s8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        for row in rows(for: subviews, maxWidth: width) {
            height += row.height + (row.isLast ? 0 : spacing)
        }
        return CGSize(width: width == .infinity ? idealWidth(subviews) : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                item.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct RowItem {
        let view: LayoutSubview
        let size: CGSize
    }
    private struct Row {
        let items: [RowItem]
        let height: CGFloat
        let isLast: Bool
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current: [RowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        func flush() {
            guard !current.isEmpty else { return }
            rows.append(Row(items: current, height: currentHeight, isLast: false))
            current = []
            currentWidth = 0
            currentHeight = 0
        }

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth > 0, currentWidth + spacing + size.width > maxWidth {
                flush()
            }
            current.append(RowItem(view: subview, size: size))
            currentWidth += (currentWidth > 0 ? spacing : 0) + size.width
            currentHeight = max(currentHeight, size.height)
        }
        flush()

        if var last = rows.popLast() {
            last = Row(items: last.items, height: last.height, isLast: true)
            rows.append(last)
        }
        return rows
    }

    private func idealWidth(_ subviews: Subviews) -> CGFloat {
        subviews.reduce(CGFloat.zero) { $0 + $1.sizeThatFits(.unspecified).width + spacing }
    }
}
