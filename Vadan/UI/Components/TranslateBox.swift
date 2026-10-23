import SwiftUI

private enum PickingSide: String, Identifiable {
    case source, target
    var id: String { rawValue }
}

/** The Translate tab's content: language pair, input card, result card, actions (TranslateBox.kt). */
struct TranslateBox<Footer: View>: View {
    let supportedLanguages: [Language]
    let favoriteLanguages: [String]
    let recentLanguages: [String]
    let onToggleFavoriteLanguage: (String) -> Void
    let sourceLanguage: Language
    let targetLanguage: Language
    let swapLanguages: () -> Void
    let setSource: (Language) -> Void
    let setTarget: (Language) -> Void
    let onInputChanged: (String) -> Void
    let inputText: String
    let translatedText: String
    let romanization: String
    let onSavePhrase: () -> Void
    let onSuggestToFriend: () -> Void
    /** This exact phrase is already in the library: the button reads "Saved" in ink. */
    var saved: Bool = false
    var saving: Bool = false
    /** A translation request is in flight; `translatedText` may be the previous result. */
    var translating: Bool = false
    /** Shown under the buttons, where the design puts its toast. */
    @ViewBuilder var footer: () -> Footer

    @State private var picking: PickingSide?

    var body: some View {
        let hasTranslation = translatedText.isNotBlank &&
            !translatedText.hasPrefix("Error:") && !translatedText.hasPrefix("Exception:")
        // Don't save or suggest a translation that belongs to the previous input.
        let actionsEnabled = hasTranslation && !translating

        ScrollView {
            VStack(spacing: 14) {
                // FROM ⇄ TO
                HStack(spacing: 8) {
                    LanguagePickerButton(selectedLanguage: sourceLanguage, label: "FROM") { picking = .source }
                    SwapLanguagesButton(action: swapLanguages)
                    LanguagePickerButton(selectedLanguage: targetLanguage, label: "TO") { picking = .target }
                }
                .padding(6)
                .roundedBackground(AppColor.backgroundPrimary, 20)

                TranslateInputTextField(
                    inputText: inputText,
                    onInputChanged: onInputChanged,
                    languageLabel: sourceLanguage.name.uppercased(),
                    showClear: !inputText.isEmpty,
                    onClear: { onInputChanged("") }
                )

                TranslatedTextBox(
                    translation: translatedText,
                    romanization: romanization,
                    languageLabel: targetLanguage.name.uppercased(),
                    languageCode: targetLanguage.code,
                    loading: translating
                )

                HStack(spacing: 10) {
                    AppButton(
                        text: saved ? "Saved" : (saving ? "Saving…" : "Save phrase"),
                        icon: saved ? "bookmark.fill" : "bookmark",
                        enabled: actionsEnabled && !saving,
                        variant: .filled,
                        containerColor: saved ? AppColor.secondary : AppColor.primary,
                        action: onSavePhrase
                    )
                    AppButton(
                        text: "Suggest to friend",
                        icon: "paperplane",
                        enabled: actionsEnabled,
                        variant: .outlined,
                        action: onSuggestToFriend
                    )
                }

                footer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
            // Tapping anywhere outside the text closes the keyboard (the field is multi-line,
            // so Return adds a line instead).
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { KeyboardObserver.dismiss() }
            )
        }
        .scrollDismissesKeyboard(.immediately)
        .background(AppColor.backgroundSecondary)
        .appSheet(item: $picking, fullHeight: true) { side in
            LanguagePickerSheet(
                title: side == .source ? "Translate from" : "Translate to",
                selected: side == .source ? sourceLanguage : targetLanguage,
                favorites: favoriteLanguages,
                recents: recentLanguages,
                languages: supportedLanguages,
                onSelect: { language in
                    if side == .source { setSource(language) } else { setTarget(language) }
                    picking = nil
                },
                onToggleFavorite: onToggleFavoriteLanguage
            )
        }
    }
}

/** The dark result card. */
struct TranslatedTextBox: View {
    let translation: String
    let romanization: String
    var languageLabel: String = ""
    /** Target language, for the speaker button. */
    var languageCode: String = ""
    var loading: Bool = false

    var body: some View {
        let speakable = !loading && translation.isNotBlank &&
            !translation.hasPrefix("Error:") && !translation.hasPrefix("Exception:")
        VStack(alignment: .leading, spacing: 10) {
            if !languageLabel.isEmpty || loading {
                HStack(spacing: 0) {
                    Text(languageLabel)
                        .overlineStyle(color: AppColor.textOnDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if loading {
                        ProgressView()
                            .tint(AppColor.textOnDark)
                            .controlSize(.mini)
                            .frame(width: 14, height: 14)
                            .accessibilityLabel("Translating")
                    }
                    if speakable && !languageCode.isEmpty {
                        // Full 48pt touch target; pulled right so the icon lines up with the card edge.
                        SpeakButton(text: translation, language: languageCode, tint: AppColor.textInverse, size: 48)
                            .offset(x: 12)
                            .frame(height: 24)
                    }
                }
                .frame(minHeight: 24)
            }
            if translation != "" {
                // While a new translation loads, the previous one stays but fades back.
                let fade: Double = loading ? 0.45 : 1
                Text(translation)
                    .font(AppFont.poppins(30))
                    .foregroundStyle(AppColor.textInverse.opacity(fade))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if romanization != "" {
                    Text(romanization)
                        .font(AppFont.dmSans(15))
                        .foregroundStyle(AppColor.textOnDarkMuted.opacity(fade))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(loading ? "Translating…" : "Translation appears here")
                    .font(AppFont.poppins(24))
                    .foregroundStyle(AppColor.textOnDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Kato chatting in the corner of the empty card, as in the design.
                Kato(pose: .talk, width: 64, outline: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .roundedBackground(AppColor.secondary, 24)
    }
}

/** The white input card. */
struct TranslateInputTextField: View {
    let inputText: String
    let onInputChanged: (String) -> Void
    var languageLabel: String = ""
    var showClear: Bool = false
    var onClear: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !languageLabel.isEmpty {
                Text(languageLabel).overlineStyle()
            }
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("Type or paste a phrase")
                        .font(AppFont.poppins(24))
                        .foregroundStyle(AppColor.textTertiary)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextField("", text: Binding(get: { inputText }, set: onInputChanged), axis: .vertical)
                    .font(AppFont.poppins(24))
                    .foregroundStyle(AppColor.textPrimary)
                    .tint(AppColor.accent)
                    .lineLimit(1...)
                    .accessibilityLabel("Type or paste a phrase to translate")
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            if showClear {
                HStack {
                    Spacer()
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Clear text")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .roundedBackground(AppColor.backgroundPrimary, 24)
    }
}

struct SwapLanguagesButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.textInverse)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppColor.primary))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Swap languages")
    }
}
