import SwiftUI

/// 全 App 共用的間距／圓角／陰影／按鈕層級，讓「舒適感」有一致的準則可循，
/// 不是每個畫面各自決定數字。
///
/// 跟 AppearanceSettings 分工：AppearanceSettings 管使用者可調的內容色
/// （文字色、背景、強調色），這裡管結構性的間距／圓角／陰影／按鈕樣式，
/// 兩者疊加使用——按鈕樣式一律讀 Color.accentColor，會自動跟著使用者選的
/// 強調色（不論是固定色還是跟著作品變色）。

// MARK: - 間距（8pt 網格）

enum Spacing {
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
}

// MARK: - 介面表面色

/// 每個畫面從環境取得相同配色，讓切換背景會立即更新所有分頁與 sheet。
struct AppSurface {
    var style: BackgroundStyle = .pureBlack
    var customHex: String = "E8E4DC"

    var background: Color {
        switch style {
        case .system: Color(.systemGroupedBackground)
        case .light: Color(white: 0.96)
        case .dark: Color(white: 0.055)
        case .pureBlack: .black
        case .paper: Color(red: 0.96, green: 0.94, blue: 0.88)
        case .midnight: Color(red: 0.06, green: 0.09, blue: 0.16)
        case .custom: Color(UIColor(rgbHex: customHex))
        }
    }

    var panel: Color { surface(elevated: false) }
    var panelElevated: Color { surface(elevated: true) }
    var hairline: Color { Color.primary.opacity(0.10) }
    var secondaryText: Color { .secondary }

    private func surface(elevated: Bool) -> Color {
        let style = style
        let custom = UIColor(rgbHex: customHex)
        return Color(UIColor { traits in
            let isDark: Bool
            if style == .system {
                isDark = traits.userInterfaceStyle == .dark
            } else if style == .custom {
                isDark = custom.relativeLuminance <= 0.179
            } else {
                isDark = style.colorScheme == .dark
            }
            let base: UIColor
            switch style {
            case .paper: base = UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1)
            case .midnight: base = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
            case .custom: base = custom
            default: base = isDark ? .black : .white
            }
            return base.mixed(with: .white, amount: isDark ? (elevated ? 0.16 : 0.10) : (elevated ? 0.90 : 0.72))
        })
    }
}

private struct AppSurfaceKey: EnvironmentKey {
    static let defaultValue = AppSurface()
}

extension EnvironmentValues {
    var appSurface: AppSurface {
        get { self[AppSurfaceKey.self] }
        set { self[AppSurfaceKey.self] = newValue }
    }
}

extension UIColor {
    convenience init(rgbHex: String) {
        let value = UInt32(rgbHex, radix: 16) ?? 0xE8E4DC
        self.init(red: CGFloat((value >> 16) & 255) / 255,
                  green: CGFloat((value >> 8) & 255) / 255,
                  blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    var rgbHex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int((min(max(r, 0), 1) * 255).rounded()),
                      Int((min(max(g, 0), 1) * 255).rounded()), Int((min(max(b, 0), 1) * 255).rounded()))
    }

    var relativeLuminance: Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let value = Double(c)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r + (r2 - r) * amount, green: g + (g2 - g) * amount,
                       blue: b + (b2 - b) * amount, alpha: 1)
    }
}

// MARK: - 圓角

enum Radius {
    /// 小徽章、色塊這類極小元件
    static let sharp: CGFloat = 4
    /// 卡片、按鈕、大多數容器的預設值——夠柔和又不會過度可愛
    static let mid: CGFloat = 14
    /// 少數當作視覺焦點的大卡片（如牌組列表的封面列），比一般卡片更圓一點
    static let large: CGFloat = 20
    /// 短標籤、膠囊按鈕；長文字按鈕別用這個，兩端會擠出不自然的尖角
    static let pill: CGFloat = 999
}

// MARK: - 柔和陰影

/// 材質層次用的陰影，統一走這裡而不是每處各自指定顏色／模糊半徑，
/// 避免有的地方陰影死黑、有的地方又完全沒有層次。
enum ShadowLevel {
    /// 貼著背景的卡片、格子
    case card
    /// 浮起來的元件，如懸浮按鈕、彈出選單
    case floating

    fileprivate var color: Color {
        switch self {
        case .card: .black.opacity(0.14)
        case .floating: .black.opacity(0.22)
        }
    }
    fileprivate var radius: CGFloat { self == .card ? 7 : 14 }
    fileprivate var y: CGFloat { self == .card ? 3 : 6 }
}

extension View {
    func comfortShadow(_ level: ShadowLevel = .card) -> some View {
        shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }

    /// 浮動玻璃分頁列不佔版面、也不會壓縮安全區，捲動內容自己不知道要
    /// 留位置給它——直接掛在 RootTabView 外層的 safeAreaInset 又會被
    /// NavigationStack 擋下來傳不到 List/Form 裡，所以改成每個會捲到底的
    /// List／Form／ScrollView 自己掛這個，才能保證最後一塊內容不被蓋到。
    func clearsGlassTabBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 140)
        }
    }
}

// MARK: - 按鈕層級

/// 實心：一個畫面只留給唯一的主要動作
struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Spacing.s16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
            .foregroundStyle(.white)
            .comfortShadow(.card)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 淡色：次要但仍重要的動作
struct TonalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Spacing.s16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(Color.accentColor.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: Radius.mid, style: .continuous))
            .foregroundStyle(Color.accentColor)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 外框：低風險或可逆的次要動作
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Spacing.s16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: Radius.mid, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1.3)
            }
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FilledButtonStyle {
    static var filled: FilledButtonStyle { FilledButtonStyle() }
}
extension ButtonStyle where Self == TonalButtonStyle {
    static var tonal: TonalButtonStyle { TonalButtonStyle() }
}
extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
}
