import SwiftUI
import UIKit

// Vadan palette ("Muted Clay"), light values from the design canvas and dark values from its
// "Dark" boards. Mirrors ui/theme/Color.kt on Android: every token is a dynamic color that
// follows the system light/dark setting, so no screen has to know about dark mode.

private func themed(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
    })
}

private func fixed(_ value: UInt32) -> Color { Color(UIColor(hex: value)) }

extension UIColor {
    /// 0xRRGGBB, fully opaque.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum AppColor {
    // Brand
    /** The deep-clay brand surface (splash, auth header, onboarding). Same in light and dark. */
    static let brandClay = fixed(0x87463F)
    /** Clay — buttons stay clay in dark too. */
    static let primary = fixed(0xA65950)
    /** Deep clay — active tab, revealed answers. */
    static let primaryDark = themed(0x87463F, 0xE8A79E)
    /** Blush — selected tab pill, soft badges. */
    static let primarySoft = themed(0xF4E8E5, 0x3D2A27)
    /** Ink — dark cards, selected chips. */
    static let secondary = themed(0x3B403D, 0x343B36)
    /** Oat — avatars, secondary fills. */
    static let tertiary = themed(0xE8DCCB, 0x4A4033)
    /**
     * Clay for text, icons, focus rings and selection marks drawn ON a surface. Dark mode uses
     * the light coral, since primary clay is too dark to read on the dark backgrounds.
     */
    static let accent = themed(0xA65950, 0xE8A79E)
    /** Toasts, chat bubbles. */
    static let cream = themed(0xF5EFE7, 0x2E2A24)

    static let success = themed(0x3F7A5C, 0x8CCBA8)
    static let warning = themed(0xB7791F, 0xE3B266)
    static let error = themed(0xB3261E, 0xF2B8B5)

    // Neutral scale
    static let neutral100 = themed(0xF5EFE7, 0x2E2A24)
    /** Dividers, sheet handles. */
    static let neutral200 = themed(0xE8E6E2, 0x333834)
    /** Outlines. */
    static let neutral300 = themed(0xD8D5D0, 0x454B46)
    /** Dashed borders. */
    static let neutral400 = themed(0xCCC8C2, 0x5A605B)
    /** Outlines that are the only sign of a control (text fields, unselected radios): ≥3:1. */
    static let outline = themed(0x918F8B, 0x6C716D)
    /** Progress tracks. */
    static let trackGray = themed(0xE2DFDA, 0x2C312E)

    // Backgrounds
    /** Cards, sheets, tab bar. */
    static let backgroundPrimary = themed(0xFFFFFF, 0x232825)
    /** Screen background. */
    static let backgroundSecondary = themed(0xFAF8F5, 0x171A18)

    // Text colors
    static let textPrimary = themed(0x3B403D, 0xEEEAE4)
    /** Source phrases, chip labels. */
    static let textBody = themed(0x4A4F4C, 0xC8C5BF)
    static let textSecondary = themed(0x626763, 0xA2A6A1)
    /** Placeholders, hints (≥4.5:1). */
    static let textTertiary = themed(0x6E726F, 0x8A8F8B)
    /** On clay / ink fills, both modes. */
    static let textInverse = fixed(0xFFFFFF)
    /** Labels on ink cards. */
    static let textOnDark = themed(0xB6BBB7, 0xA9AFAA)
    static let textOnDarkMuted = themed(0xD5D9D6, 0xCBD0CC)

    // Friends tab badge (ink in light, coral in dark).
    static let badgeBackground = themed(0x3B403D, 0xE0897F)
    static let badgeContent = themed(0xFFFFFF, 0x1F1A19)

    /** The study session's done screen: ink in light mode, a deeper green-black in dark. */
    static let doneBackground = themed(0x3B403D, 0x1F2421)
}
