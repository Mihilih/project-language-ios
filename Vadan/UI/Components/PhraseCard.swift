import SwiftUI

/** A saved phrase in the Library (PhraseCard.kt). */
struct PhraseCard: View {
    let phrase: Phrase
    var onFavoriteToggle: (String, Bool) -> Void = { _, _ in }
    /** Shows a "Suggest to a friend" button under the heart when set. */
    var onSuggest: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                LanguagePairChip(text: "\(phrase.sourceLang.uppercased()) → \(phrase.targetLang.uppercased())")
                    .padding(.bottom, 4)
                Text(phrase.original)
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textBody)
                Text(phrase.translated)
                    .phraseTextStyle()
                if phrase.romanized.isNotBlank {
                    Text(phrase.romanized)
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textSecondary)
                        .slanted()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Button {
                    onFavoriteToggle(phrase.id, !phrase.isFavorite)
                } label: {
                    Image(systemName: phrase.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(phrase.isFavorite ? AppColor.accent : AppColor.textSecondary)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(phrase.isFavorite
                    ? "Remove “\(phrase.translated)” from favorites"
                    : "Add “\(phrase.translated)” to favorites")

                SpeakButton(text: phrase.translated, language: phrase.targetLang, size: 48)

                if let onSuggest {
                    Button(action: onSuggest) {
                        AppSymbol(name: "paperplane")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Suggest “\(phrase.translated)” to a friend")
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .roundedBackground(AppColor.backgroundPrimary, 20)
    }
}

/** Small "EN → SI" tag used on phrase cards. */
struct LanguagePairChip: View {
    let text: String
    var background: Color = AppColor.backgroundSecondary

    var body: some View {
        Text(text)
            .font(AppFont.dmSans(11, .bold))
            .tracking(11 * 0.06)
            .foregroundStyle(AppColor.textBody)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .roundedBackground(background, 6)
    }
}
