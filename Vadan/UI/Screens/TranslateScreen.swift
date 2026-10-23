import SwiftUI

/** The Translate tab (TranslateScreen.kt). */
struct TranslateScreen: View {
    /** False while another tab is showing. Leaving the tab clears the input, as on Android. */
    let isActive: Bool

    @StateObject private var viewModel = TranslationViewModel()
    @StateObject private var toast = ToastState()
    @State private var suggestOpen = false

    var body: some View {
        let uiState = viewModel.uiState
        let prefs = viewModel.languagePrefs
        VStack(spacing: 0) {
            AppHeader(text: "Translate") {
                Text("Translates as you type")
                    .font(AppFont.dmSans(13, .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
            TranslateBox(
                supportedLanguages: viewModel.supportedLanguages,
                favoriteLanguages: prefs.favorites,
                recentLanguages: prefs.recents,
                onToggleFavoriteLanguage: viewModel.toggleFavoriteLanguage,
                sourceLanguage: uiState.sourceLanguage,
                targetLanguage: uiState.targetLanguage,
                swapLanguages: viewModel.swapLanguages,
                setSource: viewModel.setSourceLanguage,
                setTarget: viewModel.setTargetLanguage,
                onInputChanged: viewModel.updateInput,
                inputText: uiState.inputText,
                translatedText: uiState.translation,
                romanization: uiState.romanization,
                onSavePhrase: {
                    viewModel.saveCurrentPhrase { outcome in
                        switch outcome {
                        case .saved: toast.success("Saved to your library")
                        case .alreadySaved: toast.success("Already in your library")
                        case .failed: toast.error("Couldn't save the phrase. Please try again.")
                        case .signedOut: toast.error("Please log in to save phrases")
                        }
                    }
                },
                onSuggestToFriend: {
                    toast.dismiss()
                    suggestOpen = true
                },
                saved: uiState.isSaved,
                saving: uiState.isSaving,
                translating: uiState.isTranslating
            ) {
                AppToastHost(state: toast)
            }
        }
        .background(AppColor.backgroundSecondary)
        .onChange(of: isActive) { _, active in
            if !active { viewModel.updateInput("") }
        }
        .appSheet(isPresented: $suggestOpen) {
            SuggestToFriendSheet(
                phrase: PhraseSnapshot(
                    original: uiState.inputText.trimmed,
                    translated: uiState.translation,
                    romanized: uiState.romanization,
                    sourceLang: uiState.sourceLanguage.code,
                    targetLang: uiState.targetLanguage.code
                ),
                onSent: { names in
                    suggestOpen = false
                    toast.success(suggestedToText(names))
                }
            )
        }
    }
}
