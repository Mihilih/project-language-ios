import Foundation
import Combine

struct TranslationUiState {
    var sourceLanguage: Language
    var targetLanguage: Language
    var inputText: String
    var translation: String
    var romanization: String
    var isSaving = false
    /** A request is in flight; `translation` may still be the previous result. */
    var isTranslating = false
    /** Which phrase was last saved (or found already saved), so the button can read "Saved". */
    var savedKey: String? = nil

    var currentKey: String { "\(sourceLanguage.code)|\(targetLanguage.code)|\(inputText.trimmed.lowercased())" }
    var isSaved: Bool { savedKey != nil && savedKey == currentKey }
}

enum SaveOutcome { case saved, alreadySaved, failed, signedOut }

/** The Translate tab (viewmodel/TranslationViewModel.kt). */
@MainActor
final class TranslationViewModel: ObservableObject {
    private static let typingPauseNanos: UInt64 = 300_000_000

    /** Every language Google Translate supports, A–Z. */
    let supportedLanguages: [Language] = Languages.all

    @Published private(set) var uiState: TranslationUiState
    /** Starred and recently used languages, for the top of the language picker. */
    @Published private(set) var languagePrefs: LanguagePrefs

    private let translationRepository = TranslationRepository.shared
    private let prefsRepository = LanguagePrefsRepository.shared
    private let romanizer = RomanizationHelper()
    private var cancellables = Set<AnyCancellable>()
    /** The in-flight translation; a newer request cancels it so stale results never land. */
    private var translateTask: Task<Void, Never>?

    /** Set once the user picks or swaps a language, so a late Firestore load can't undo it. */
    private var pairChosen = false

    init() {
        prefsRepository.bind(AuthManager.getCurrentUserId())
        let prefs = prefsRepository.prefs
        languagePrefs = prefs
        uiState = TranslationUiState(
            sourceLanguage: Languages.find(prefs.lastSource) ?? Languages.english,
            targetLanguage: Languages.find(prefs.lastTarget) ?? Languages.sinhala,
            inputText: "",
            translation: "",
            romanization: ""
        )
        translationRepository.warmUp()

        // Open on the last pair, including one saved on another device (that copy arrives from
        // Firestore a moment after the screen opens).
        prefsRepository.$prefs
            .sink { [weak self] saved in
                guard let self else { return }
                self.languagePrefs = saved
                if self.pairChosen { return }
                guard let source = Languages.find(saved.lastSource),
                      let target = Languages.find(saved.lastTarget) else { return }
                let state = self.uiState
                if state.sourceLanguage != source || state.targetLanguage != target {
                    self.uiState.sourceLanguage = source
                    self.uiState.targetLanguage = target
                    if state.inputText.isNotBlank { self.translate() }
                }
            }
            .store(in: &cancellables)
    }

    func toggleFavoriteLanguage(_ code: String) { prefsRepository.toggleFavorite(code) }

    func swapLanguages() {
        let current = uiState
        let swappedInput = current.translation.hasPrefix("Error:") ? "" : current.translation
        uiState.sourceLanguage = current.targetLanguage
        uiState.targetLanguage = current.sourceLanguage
        uiState.inputText = swappedInput
        uiState.translation = ""
        uiState.romanization = ""
        rememberPair()
        if swappedInput != "" { translate() }
    }

    /** Picking the language already on the other side swaps the two, like Google Translate. */
    func setSourceLanguage(_ lang: Language) {
        if lang == uiState.sourceLanguage { return rememberPair() }
        if lang == uiState.targetLanguage { return swapLanguages() }
        uiState.sourceLanguage = lang
        rememberPair()
        if uiState.inputText.isNotBlank { translate() }
    }

    func setTargetLanguage(_ lang: Language) {
        if lang == uiState.targetLanguage { return rememberPair() }
        if lang == uiState.sourceLanguage { return swapLanguages() }
        uiState.targetLanguage = lang
        rememberPair()
        if uiState.inputText.isNotBlank { translate() }
    }

    private func rememberPair() {
        pairChosen = true
        prefsRepository.usePair(source: uiState.sourceLanguage.code, target: uiState.targetLanguage.code)
    }

    func updateInput(_ input: String) {
        uiState.inputText = input
        if input.isBlank {
            translateTask?.cancel()
            uiState.translation = ""
            uiState.romanization = ""
            uiState.isTranslating = false
        } else {
            translate(debounce: true)
        }
    }

    /**
     * Translate the current input. While typing (`debounce` = true) it waits for a short pause
     * first, so we call the backend once per phrase rather than once per keystroke.
     */
    func translate(debounce: Bool = false) {
        translateTask?.cancel()
        let start = uiState
        let startText = start.inputText.trimmed
        // Already translated this (e.g. swapped back, or retyped it): show it straight away.
        if let hit = translationRepository.cached(startText, start.sourceLanguage.code, start.targetLanguage.code) {
            showTranslation(hit)
            return
        }
        // Show "translating" right away, even during the typing pause.
        uiState.isTranslating = !startText.isEmpty
        translateTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: Self.typingPauseNanos)
            }
            if Task.isCancelled { return }
            let state = uiState
            let text = state.inputText.trimmed
            if text.isEmpty { return }
            let result = await translationRepository.translateText(
                text, sourceLang: state.sourceLanguage.code, targetLang: state.targetLanguage.code
            )
            if Task.isCancelled { return }
            switch result {
            case .success(let translated):
                showTranslation(translated)
            case .failure(let error):
                // TranslateBox treats an "Error:" prefix as "no usable translation".
                uiState.translation = "Error: \(error.localizedDescription)"
                uiState.romanization = ""
                uiState.isTranslating = false
            }
        }
    }

    /** Romanization from the server (Azure) when it sent one, otherwise from the phone. */
    private func showTranslation(_ result: TranslationResult) {
        uiState.translation = result.translation
        uiState.romanization = result.romanization
            ?? romanizer.romanize(result.translation, sourceLanguage: uiState.targetLanguage.code)
        uiState.isTranslating = false
    }

    /** Saves what's on screen to the library. Saving the same phrase twice is a no-op. */
    func saveCurrentPhrase(onResult: @escaping (SaveOutcome) -> Void) {
        let state = uiState
        if state.isSaving || state.isTranslating { return }
        if state.isSaved { return onResult(.alreadySaved) }
        guard let userId = AuthManager.getCurrentUserId() else { return onResult(.signedOut) }

        let key = state.currentKey
        let phrase = Phrase(
            original: state.inputText.trimmed,
            translated: state.translation,
            romanized: state.romanization,
            sourceLang: state.sourceLanguage.code,
            targetLang: state.targetLanguage.code
        )
        uiState.isSaving = true
        Task {
            let (success, message) = await PhraseRepository.savePhrase(userId: userId, phrase: phrase)
            let outcome: SaveOutcome
            if success {
                outcome = .saved
            } else if message == PhraseRepository.alreadySaved {
                outcome = .alreadySaved
            } else {
                outcome = .failed
            }
            uiState.isSaving = false
            if outcome != .failed { uiState.savedKey = key }
            onResult(outcome)
        }
    }
}
