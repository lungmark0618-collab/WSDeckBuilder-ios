import SwiftUI

struct GlassTabBarItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let systemImage: String
}

struct GlassTabBar<ID: Hashable>: View {
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
                            .font(.system(size: 25, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(selection == item.id ? Color.accentColor : .white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                    .background {
                        if selection == item.id {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                }
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .padding(7)
        .frame(maxWidth: 430)
        .frame(height: 82)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(AppSurface.panel.opacity(0.74))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(AppSurface.hairline, lineWidth: 1)
                }
        }
        .comfortShadow(.floating)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}
