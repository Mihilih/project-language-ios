import SwiftUI

/// The app's two typefaces (ui/theme/Type.kt on Android). Sizes are in points, the iOS
/// equivalent of Android's sp: they scale with the user's text size setting.
enum AppFont {
    enum Weight {
        case regular, medium, semibold, bold
    }

    /** Display face: screen titles, phrases, big numbers. Poppins ships Medium/SemiBold/Bold. */
    static func poppins(_ size: CGFloat, _ weight: Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .regular, .medium: name = "Poppins-Medium"
        case .semibold: name = "Poppins-SemiBold"
        case .bold: name = "Poppins-Bold"
        }
        return .custom(name, size: size)
    }

    /** Body face: everything else (labels, buttons, captions). */
    static func dmSans(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .regular: name = "DMSans-Regular"
        case .medium: name = "DMSans-Medium"
        case .semibold: name = "DMSans-SemiBold"
        case .bold: name = "DMSans-Bold"
        }
        return .custom(name, size: size)
    }

    /** UIKit version, for the PDF exporter. */
    static func uiFont(_ name: String, _ size: CGFloat, fallbackWeight: UIFont.Weight) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
    }
}

extension View {
    /** Main screen titles ("Translate", "Library", …): Poppins 32, -0.02em. */
    func screenTitleStyle() -> some View {
        self.font(AppFont.poppins(32))
            .tracking(-0.64)
            .foregroundStyle(AppColor.textPrimary)
    }

    /** Small uppercase labels ("FROM", "COLLECTIONS"): DM Sans Bold 11, 0.1em. */
    func overlineStyle(size: CGFloat = 11, color: Color = AppColor.textSecondary) -> some View {
        self.font(AppFont.dmSans(size, .bold))
            .tracking(size * 0.1)
            .foregroundStyle(color)
    }

    /** Phrase text on cards (Poppins 22, semibold). */
    func phraseTextStyle() -> some View {
        self.font(AppFont.poppins(22))
            .foregroundStyle(AppColor.textPrimary)
    }
}

/**
 * Synthetic italic. DM Sans ships no italic face, and SwiftUI doesn't slant custom fonts on its
 * own, so this shears the text the way Android's fake italic does (about 12°).
 */
struct Slant: GeometryEffect {
    var amount: CGFloat = 0.21

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(a: 1, b: 0, c: -amount, d: 1, tx: amount * size.height / 2, ty: 0))
    }
}

extension View {
    /** Italic for DM Sans text (see Slant). */
    func slanted() -> some View { modifier(Slant()) }
}
