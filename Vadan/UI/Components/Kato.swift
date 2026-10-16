import SwiftUI

/**
 * Kato, the Vadan cat, drawn flat in the logo's style (Kato.kt). Each pose has a plain version
 * for clay / dark surfaces and an ink-outlined one for light surfaces.
 */
enum KatoPose: String {
    case sit, wave, read, talk, celebrate, sleep
}

/**
 * `width` is the design's `size`; Kato is 1.25x as tall as wide. Decorative, so VoiceOver skips
 * it. Colors are fixed, so Kato looks the same in light and dark mode.
 */
struct Kato: View {
    let pose: KatoPose
    let width: CGFloat
    let outline: Bool

    var body: some View {
        Image(outline ? "kato_\(pose.rawValue)_outline" : "kato_\(pose.rawValue)")
            .resizable()
            .interpolation(.high)
            .frame(width: width, height: width * 1.25)
            .accessibilityHidden(true)
    }
}

/** The Vadan cat-head mark (logo without the tile). */
struct VadanMark: View {
    var size: CGFloat = 40

    var body: some View {
        Image("vadan_mark")
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
