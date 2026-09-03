import SwiftUI

/// Vercel / Geist tokens. Do not invent a second palette.
enum Theme {
    // Dark inverse (vercel.com + Geist dark-theme)
    static let canvas = Color(hex: 0x000000)
    static let surface = Color(hex: 0x0A0A0A)
    static let raised = Color(hex: 0x111111)
    static let hairline = Color(hex: 0x333333)
    static let ink = Color(hex: 0xEDEDED)
    static let body = Color(hex: 0xA1A1A1)
    static let muted = Color(hex: 0x888888)

    static let accents1 = Color(hex: 0x111111)
    static let accents2 = Color(hex: 0x333333)
    static let accents3 = Color(hex: 0x444444)
    static let accents5 = Color(hex: 0x888888)
    static let accents7 = Color(hex: 0xEAEAEA)
    static let accents8 = Color(hex: 0xFAFAFA)

    static let blue = Color(hex: 0x0070F3)
    static let error = Color(hex: 0xEE0000)
    static let warning = Color(hex: 0xF5A623)
    static let success = Color(hex: 0x46A758)

    static let border = Color.white.opacity(0.08)
    static let borderStrong = Color.white.opacity(0.15)

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let pill: CGFloat = 9999
    }

    enum Space {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x6: CGFloat = 24
        static let x8: CGFloat = 32
        static let gap: CGFloat = 24
        static let control: CGFloat = 40
        static let sidebar: CGFloat = 240
        static let topbar: CGFloat = 48
    }

    static func sans(_ size: CGFloat, weight: GeistWeight = .regular) -> Font {
        Font.custom(weight.sansName, size: size)
    }

    static func mono(_ size: CGFloat, weight: GeistMonoWeight = .regular) -> Font {
        Font.custom(weight.rawValue, size: size)
    }
}

enum GeistWeight {
    case regular, medium, semibold

    var sansName: String {
        switch self {
        case .regular: return "Geist-Regular"
        case .medium: return "Geist-Medium"
        case .semibold: return "Geist-SemiBold"
        }
    }
}

enum GeistMonoWeight: String {
    case regular = "GeistMono-Regular"
    case medium = "GeistMono-Medium"
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
