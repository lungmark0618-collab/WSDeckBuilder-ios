import SwiftUI

struct GlassTabBarItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let systemImage: String
}

struct GlassTabBar<ID: Hashable>: View {
    @Environment(\.appSurface) private var surface
    let items: [GlassTabBarItem<ID>]
    @Binding var selection: ID

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selection = item.id
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 21, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selection == item.id ? Color.primary : Color.primary.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background {
                        if selection == item.id {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                }
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item.id ? .isSelected : [])
            }
        }
        .padding(7)
        .frame(maxWidth: 430)
        .frame(minHeight: 68)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(surface.panel.opacity(0.74))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(surface.hairline, lineWidth: 1)
                }
        }
        .comfortShadow(.floating)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}
