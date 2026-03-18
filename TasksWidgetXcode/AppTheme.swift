import SwiftUI

// MARK: - Accent colour options (user-selectable)

enum AccentOption: String, CaseIterable {
    case pink
    case blue
    case teal
    case sage
    case slate
    
    var color: Color {
        switch self {
        case .pink:  return Color(red: 0.91, green: 0.35, blue: 0.58)
        case .blue:  return Color(red: 0.25, green: 0.45, blue: 0.85)
        case .teal:  return Color(red: 0.20, green: 0.60, blue: 0.58)
        case .sage:  return Color(red: 0.40, green: 0.55, blue: 0.45)
        case .slate: return Color(red: 0.40, green: 0.45, blue: 0.55)
        }
    }
    
    static func color(for key: String) -> Color {
        AccentOption(rawValue: key)?.color ?? AccentOption.pink.color
    }
}

// MARK: - Accent environment key

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = AccentOption.pink.color
}

extension EnvironmentValues {
    var accentColor: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}

// MARK: - Design tokens (Figma: light theme, pink default accent)

enum AppTheme {
    // Backgrounds
    static let background = Color(white: 0.97)
    static let surface = Color.white
    
    // Text
    static let textPrimary = Color(white: 0.15)
    static let textSecondary = Color(white: 0.4)
    static let textTertiary = Color(white: 0.55)
    
    // Default accent (used when environment not set)
    static let accent = Color(red: 0.91, green: 0.35, blue: 0.58)
    static let accentSoft = Color(red: 0.91, green: 0.35, blue: 0.58).opacity(0.15)
    
    // Task states
    static let completedGreen = Color(red: 0.2, green: 0.68, blue: 0.45)
    static let divider = Color(white: 0.88)
    
    // Cards
    static let rowBackground = Color.white
    static let rowBorder = Color(white: 0.92)
    static let cardShadow = Color.black.opacity(0.06)
    
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    // Corner radius
    static let radiusS: CGFloat = 6
    static let radiusM: CGFloat = 10
    static let radiusL: CGFloat = 14
}
