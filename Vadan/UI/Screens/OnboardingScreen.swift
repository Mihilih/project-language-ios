import SwiftUI

private struct OnboardingPage {
    let title: String
    let body: String
}

private let pages = [
    OnboardingPage(
        title: "Your pocket phrasebook",
        body: "Your personal language learning companion. Translate, save and practise the phrases you actually use."
    ),
    OnboardingPage(
        title: "Translate between languages easily",
        body: "Instantly translate words and phrases between more than 190 languages."
    ),
    OnboardingPage(
        title: "Save and organize your phrases",
        body: "Keep every translation that matters in one searchable library."
    ),
    OnboardingPage(
        title: "Study with flashcards",
        body: "Master new vocabulary in quick flashcard sessions and keep your streak going."
    ),
    OnboardingPage(
        title: "Learn with your friends",
        body: "Send each other useful phrases and see how everyone is doing."
    ),
]

private let track = Color.white.opacity(0.18)

/** Illustrations are laid out on the design's 390 × 420 frame and scaled to the screen. */
private let artWidth: CGFloat = 390
private let artHeight: CGFloat = 420

/**
 * First-launch intro from the design canvas: five swipeable steps on deep clay. `onFinish` runs
 * for both "Start learning" and "Skip" (OnboardingScreen.kt).
 */
struct OnboardingScreen: View {
    let onFinish: () -> Void

    @State private var page = 0

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Back · progress · Skip
            HStack(spacing: 12) {
                ZStack {
                    if page > 0 {
                        Button { withAnimation { page -= 1 } } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(AppColor.textInverse)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Back")
                    }
                }
                .frame(width: 44, height: 44)

                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= page ? AppColor.tertiary : track)
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement()
                .accessibilityLabel("Step \(page + 1) of \(pages.count)")

                ZStack(alignment: .trailing) {
                    if !isLast {
                        Button(action: onFinish) {
                            Text("Skip")
                                .font(AppFont.dmSans(15, .semibold))
                                .foregroundStyle(AppColor.textInverse)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .frame(width: 64, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button {
                if isLast { onFinish() } else { withAnimation { page += 1 } }
            } label: {
                HStack(spacing: 10) {
                    Text(page == 0 ? "Get started" : (isLast ? "Start learning" : "Next"))
                        .font(AppFont.dmSans(17, .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Capsule().fill(AppColor.backgroundPrimary))
                .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(AppColor.brandClay.ignoresSafeArea())
    }
}

private struct OnboardingPageView: View {
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            // The text always gets the room it needs; the illustration scales down to fit
            // whatever height is left (and never past the screen width).
            GeometryReader { proxy in
                let scale = min(proxy.size.width / artWidth, proxy.size.height / artHeight, 1.15)
                ZStack(alignment: .topLeading) {
                    switch index {
                    case 0: WelcomeArt()
                    case 1: TranslateArt()
                    case 2: SaveArt()
                    case 3: FlashcardArt()
                    default: FriendsArt()
                    }
                }
                .frame(width: artWidth, height: artHeight, alignment: .topLeading)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .padding(.top, 8)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Text(pages[index].title)
                    .font(AppFont.poppins(40))
                    .tracking(-0.8)
                    .foregroundStyle(AppColor.textInverse)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(pages[index].body)
                    .font(AppFont.dmSans(17))
                    .lineSpacing(4)
                    .foregroundStyle(AppColor.textInverse)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }
}

// MARK: - Illustrations (positions in points on the 390 × 420 design frame)

/** Places `content` with its top-left corner at (x, y), rotated around its centre. */
private struct Placed<Content: View>: View {
    let x: CGFloat
    let y: CGFloat
    var rotation: Double = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .fixedSize()
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
    }
}

private struct WordChip: View {
    let text: String
    let background: Color
    let color: Color
    let fontSize: CGFloat

    var body: some View {
        Text(text)
            .font(AppFont.poppins(fontSize))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Capsule().fill(background))
    }
}

private struct Tag: View {
    let text: String
    let background: Color
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFont.dmSans(11, .bold))
            .tracking(11 * 0.08)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .roundedBackground(background, 6)
    }
}

private struct WelcomeArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Placed(x: 34, y: 46, rotation: -6) { WordChip(text: "Hello", background: AppColor.tertiary, color: AppColor.textPrimary, fontSize: 34) }
            Placed(x: 186, y: 108, rotation: 5) { WordChip(text: "வணக்கம்", background: AppColor.backgroundPrimary, color: AppColor.textPrimary, fontSize: 26) }
            Placed(x: 52, y: 186, rotation: -3) { WordChip(text: "ආයුබෝවන්", background: AppColor.secondary, color: AppColor.textInverse, fontSize: 28) }
            // Kato waving hello, as in the design's first slide.
            Placed(x: 214, y: 186) { Kato(pose: .wave, width: 140, outline: false) }
            Placed(x: 70, y: 312, rotation: 8) { WordChip(text: "नमस्कार", background: AppColor.cream, color: AppColor.textPrimary, fontSize: 24) }
        }
    }
}

private struct TranslateArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Placed(x: 28, y: 50, rotation: -2) {
                VStack(alignment: .leading, spacing: 10) {
                    Tag(text: "ENGLISH", background: AppColor.backgroundSecondary, color: AppColor.textBody)
                    Text("Where is the bathroom?")
                        .font(AppFont.dmSans(22, .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }
                .padding(20)
                .frame(width: 300, alignment: .leading)
                .roundedBackground(AppColor.backgroundPrimary, 24)
            }
            Placed(x: 62, y: 196, rotation: 2) {
                VStack(alignment: .leading, spacing: 10) {
                    Tag(text: "SINHALA", background: Color.white.opacity(0.16), color: AppColor.textInverse)
                    Text("වැසිකිළිය කොහෙද?")
                        .font(AppFont.poppins(28))
                        .foregroundStyle(AppColor.textInverse)
                }
                .padding(22)
                .frame(width: 300, alignment: .leading)
                .roundedBackground(AppColor.secondary, 24)
            }
            Placed(x: 172, y: 160) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(AppColor.tertiary))
            }
        }
    }
}

private struct SaveArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Placed(x: 60, y: 60, rotation: -9) {
                RoundedRectangle(cornerRadius: 24).fill(AppColor.secondary).frame(width: 270, height: 150)
            }
            Placed(x: 60, y: 90, rotation: 5) {
                RoundedRectangle(cornerRadius: 24).fill(AppColor.tertiary).frame(width: 270, height: 150)
            }
            Placed(x: 50, y: 140) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Tag(text: "EN → SI", background: AppColor.backgroundSecondary, color: AppColor.textBody)
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(AppColor.accent)
                    }
                    Text("Thank you")
                        .font(AppFont.dmSans(15))
                        .foregroundStyle(AppColor.textBody)
                    Text("ස්තූතියි")
                        .font(AppFont.poppins(30))
                        .foregroundStyle(AppColor.textPrimary)
                }
                .padding(20)
                .frame(width: 290, alignment: .leading)
                .roundedBackground(AppColor.backgroundPrimary, 24)
            }
        }
    }
}

private struct FlashcardArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Placed(x: 45, y: 40) {
                HStack(spacing: 6) {
                    ForEach([true, true, false, false].indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i < 2 ? AppColor.tertiary : track)
                            .frame(height: 6)
                    }
                }
                .frame(width: 300)
            }
            Placed(x: 45, y: 70) {
                VStack(spacing: 12) {
                    Tag(text: "ENGLISH", background: AppColor.backgroundSecondary, color: AppColor.textBody)
                    Text("Good morning")
                        .font(AppFont.poppins(34))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Tap to reveal")
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(width: 300, height: 230)
                .roundedBackground(AppColor.backgroundPrimary, 28)
            }
            Placed(x: 45, y: 320) {
                HStack(spacing: 8) {
                    RatingPill(text: "Didn't get it", outlined: true)
                    RatingPill(text: "Unsure", background: Color.white.opacity(0.12))
                    RatingPill(text: "Got it", background: AppColor.tertiary, color: AppColor.textPrimary)
                }
                .frame(width: 300)
            }
        }
    }
}

private struct RatingPill: View {
    let text: String
    var outlined: Bool = false
    var background: Color = .clear
    var color: Color = AppColor.textInverse

    var body: some View {
        Text(text)
            .font(AppFont.dmSans(13, .bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                if outlined {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 16).fill(background)
                }
            }
    }
}

private struct FriendsArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Placed(x: 40, y: 50) {
                Text("S")
                    .font(AppFont.poppins(24))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(AppColor.tertiary))
            }
            Placed(x: 108, y: 48) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sarah_learns suggested")
                        .font(AppFont.dmSans(13, .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                    Text("यह कितने का है?")
                        .font(AppFont.poppins(24))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("How much does this cost?")
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textBody)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(width: 240, alignment: .leading)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 24, bottomTrailingRadius: 24, topTrailingRadius: 24)
                        .fill(AppColor.backgroundPrimary)
                )
            }
            Placed(x: 108, y: 222) {
                Text("“Useful for the market!”")
                    .font(AppFont.dmSans(16))
                    .foregroundStyle(AppColor.textInverse)
                    .slanted()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 20)
                            .fill(AppColor.secondary)
                    )
            }
            // Kato celebrating the saved phrase (replaces the second avatar in the design).
            Placed(x: 276, y: 262) { Kato(pose: .celebrate, width: 84, outline: false) }
            Placed(x: 112, y: 310) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Saved to library")
                        .font(AppFont.dmSans(14, .bold))
                        .foregroundStyle(AppColor.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(AppColor.tertiary))
            }
        }
    }
}
