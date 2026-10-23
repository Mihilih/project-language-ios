import Foundation
import Combine
import FirebaseFirestore

enum DateAddedFilter: CaseIterable {
    case allTime, thisWeek, thisMonth
}

struct LibraryUiState {
    var allPhrases: [Phrase] = []
    var phrases: [Phrase] = []
    var searchQuery = ""
    var selectedLanguages: Set<String> = []
    var favoritesOnly = false
    var dateAddedFilter: DateAddedFilter = .allTime
    var availableLanguages: [String] = []
    var isLoading = true
    /** The phrase list itself couldn't be loaded (shown as a full error state with retry). */
    var loadFailed = false
    /** A one-off action failed (favorite, delete); shown as a toast, then cleared. */
    var errorMessage: String? = nil
}

/** What the Export sheet exports (from the design: all, favorites, or what's on screen). */
enum ExportScope { case all, favorites, current }

/** A finished export, ready to hand to the share sheet. */
enum ExportResult {
    case pdfFile(URL)
    case text(String)
    case textFile(URL)
}

/** Above this, share a .txt file instead of a long message (same limit as Android). */
private let maxShareText = 50_000

/** The Library, and the phrase lists behind Study and study sessions (LibraryViewModel.kt). */
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var uiState = LibraryUiState()

    /** Most recently deleted phrase, kept so the Library can offer Undo. */
    private(set) var lastDeleted: Phrase?

    /**
     * Keeps the library in sync with Firestore. New saves (from Translate or a friend's
     * suggestion), favorites and deletes show up immediately — no reloads.
     */
    private var listener: ListenerRegistration?

    init() {
        observePhrases()
    }

    deinit { listener?.remove() }

    /** Try loading again after a failure. */
    func retry() {
        uiState.isLoading = true
        uiState.loadFailed = false
        observePhrases()
    }

    func clearError() {
        uiState.errorMessage = nil
    }

    private func observePhrases() {
        listener?.remove()
        listener = nil
        guard let userId = AuthManager.getCurrentUserId() else {
            uiState.allPhrases = []
            uiState.phrases = []
            uiState.isLoading = false
            uiState.loadFailed = true
            return
        }
        listener = PhraseRepository.observePhrases(userId: userId) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let phrases):
                    var next = self.uiState
                    next.allPhrases = phrases.sorted { $0.timestamp > $1.timestamp }
                    next.isLoading = false
                    next.loadFailed = false
                    next.availableLanguages = Self.languagesIn(phrases)
                    self.applyFilters(next)
                case .failure:
                    // Firestore keeps serving cached phrases offline, so this means a real
                    // failure (e.g. permissions). Keep whatever is already on screen.
                    let empty = self.uiState.allPhrases.isEmpty
                    self.uiState.isLoading = false
                    self.uiState.loadFailed = empty
                    self.uiState.errorMessage = empty ? nil : "Couldn't refresh your phrases"
                }
            }
        }
    }

    func onSearchQueryChange(_ query: String) {
        var next = uiState
        next.searchQuery = query
        applyFilters(next)
    }

    func updateFilters(selectedLanguages: Set<String>, favoritesOnly: Bool, dateAddedFilter: DateAddedFilter) {
        var next = uiState
        next.selectedLanguages = selectedLanguages
        next.favoritesOnly = favoritesOnly
        next.dateAddedFilter = dateAddedFilter
        applyFilters(next)
    }

    func toggleFavorite(phraseId: String, isFavorite: Bool) {
        guard let userId = AuthManager.getCurrentUserId() else { return }
        if phraseId.isBlank {
            uiState.errorMessage = "Unable to favorite: missing phrase id"
            return
        }
        // Flip it locally right away; the listener confirms it. No reload, so the list
        // doesn't flash or jump.
        var next = uiState
        next.allPhrases = next.allPhrases.map { phrase in
            var p = phrase
            if p.id == phraseId { p.isFavorite = isFavorite }
            return p
        }
        next.errorMessage = nil
        applyFilters(next)

        Task {
            let (success, _) = await PhraseRepository.toggleFavorite(userId: userId, phraseId: phraseId, isFavorite: isFavorite)
            if !success {
                var reverted = uiState
                reverted.allPhrases = reverted.allPhrases.map { phrase in
                    var p = phrase
                    if p.id == phraseId { p.isFavorite = !isFavorite }
                    return p
                }
                reverted.errorMessage = "Couldn't update favorite. Please try again."
                applyFilters(reverted)
            }
        }
    }

    /** Deletes a phrase (removed from the list immediately). `onResult` reports failures. */
    func deletePhrase(_ phrase: Phrase, onResult: @escaping (Bool) -> Void = { _ in }) {
        guard let userId = AuthManager.getCurrentUserId(), !phrase.id.isBlank else { return onResult(false) }
        lastDeleted = phrase
        var next = uiState
        next.allPhrases.removeAll { $0.id == phrase.id }
        applyFilters(next)
        Task {
            let (success, _) = await PhraseRepository.deletePhrase(userId: userId, phraseId: phrase.id)
            if !success {
                lastDeleted = nil
                // Put it back; the listener would too, but this avoids a gap.
                var restored = uiState
                restored.allPhrases = (restored.allPhrases + [phrase]).sorted { $0.timestamp > $1.timestamp }
                applyFilters(restored)
            }
            onResult(success)
        }
    }

    /** Undo the last delete: restores the phrase with its original id, favorite and date. */
    func undoDelete() {
        guard let userId = AuthManager.getCurrentUserId(), let phrase = lastDeleted else { return }
        lastDeleted = nil
        var next = uiState
        next.allPhrases = (next.allPhrases.filter { $0.id != phrase.id } + [phrase]).sorted { $0.timestamp > $1.timestamp }
        applyFilters(next)
        PhraseRepository.restorePhrase(userId: userId, phrase: phrase)
    }

    func phrasesFor(_ scope: ExportScope) -> [Phrase] {
        switch scope {
        case .all: return uiState.allPhrases
        case .favorites: return uiState.allPhrases.filter(\.isFavorite)
        case .current: return uiState.phrases
        }
    }

    private func exportTitle(_ scope: ExportScope) -> String {
        switch scope {
        case .all: return "My phrases"
        case .favorites: return "My favorite phrases"
        case .current: return "My phrases (selection)"
        }
    }

    /** Builds the PDF off the main thread; `onResult` gets nil if it failed. */
    func exportPdf(_ scope: ExportScope, onResult: @escaping (ExportResult?) -> Void) {
        let phrases = phrasesFor(scope)
        let title = exportTitle(scope)
        Task.detached(priority: .userInitiated) {
            let url: URL?
            do {
                url = try PhraseExporter.exportPdf(phrases, title: title)
            } catch {
                print("LibraryExport: PDF export failed: \(error)")
                url = nil
            }
            await MainActor.run { onResult(url.map { .pdfFile($0) }) }
        }
    }

    /** Plain text for messaging apps; long libraries go as a .txt file instead. */
    func exportText(_ scope: ExportScope, onResult: @escaping (ExportResult?) -> Void) {
        let text = PhraseExporter.exportText(phrasesFor(scope), title: exportTitle(scope))
        if text.utf16.count <= maxShareText { return onResult(.text(text)) }
        Task.detached(priority: .userInitiated) {
            let url = try? PhraseExporter.exportTextFile(text)
            await MainActor.run { onResult(url.map { .textFile($0) }) }
        }
    }

    /** The languages this user actually has phrases in, A–Z — the filter shows only these. */
    private static func languagesIn(_ phrases: [Phrase]) -> [String] {
        phrases
            .flatMap { [$0.sourceLang, $0.targetLang] }
            .map { $0.trimmed.lowercased() }
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted { Languages.displayName($0).lowercased() < Languages.displayName($1).lowercased() }
    }

    private func applyFilters(_ baseState: LibraryUiState) {
        let query = baseState.searchQuery.trimmed.lowercased()
        let selectedLanguages = Set(baseState.selectedLanguages.map { $0.lowercased() })
        let now = Phrase.nowMillis()
        let cutoffTime: Int64?
        switch baseState.dateAddedFilter {
        case .allTime: cutoffTime = nil
        case .thisWeek: cutoffTime = now - 7 * 24 * 60 * 60 * 1000
        case .thisMonth: cutoffTime = now - 30 * 24 * 60 * 60 * 1000
        }

        let filtered = baseState.allPhrases.filter { phrase in
            let matchesQuery = query.isBlank || [
                phrase.original, phrase.translated, phrase.romanized, phrase.sourceLang, phrase.targetLang,
            ].contains { $0.containsIgnoreCase(query) }
            let matchesLanguage = selectedLanguages.isEmpty ||
                selectedLanguages.contains(phrase.sourceLang.lowercased()) ||
                selectedLanguages.contains(phrase.targetLang.lowercased())
            let matchesFavorite = !baseState.favoritesOnly || phrase.isFavorite
            let matchesDate = cutoffTime.map { phrase.timestamp >= $0 } ?? true
            return matchesQuery && matchesLanguage && matchesFavorite && matchesDate
        }

        var next = baseState
        next.phrases = filtered
        uiState = next
    }
}
