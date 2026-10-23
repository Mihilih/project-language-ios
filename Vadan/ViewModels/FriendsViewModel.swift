import Foundation
import Combine
import FirebaseFirestore

enum FriendsTab { case friends, suggestions, requests }

struct FriendsUiState {
    var activeTab: FriendsTab = .friends
    var friendships: [Friendship] = []
    var incomingRequests: [FriendRequest] = []
    var suggestions: [Suggestion] = []
    var pendingSuggestions: [Suggestion] = []
    var searchQuery = ""
    var searchResults: [PublicUserSearchResult] = []
    var isSearchLoading = false
    /** The query the current `searchResults` are for; nil until a search finishes. */
    var searchedQuery: String? = nil
    // False until each list's first snapshot arrives, so tabs show a spinner, not "empty".
    var friendsLoaded = false
    var requestsLoaded = false
    var suggestionsLoaded = false
    var pendingOutgoingRequests: Set<String> = []
    var pendingRequestIds: Set<String> = []
    var pendingSuggestionIds: Set<String> = []
    /** Friends being removed right now (the button shows progress). */
    var removingFriendUids: Set<String> = []
    var errorMessage: String? = nil
}

/** The Friends tab (viewmodel/FriendsViewModel.kt). */
@MainActor
final class FriendsViewModel: ObservableObject {
    @Published private(set) var uiState = FriendsUiState()

    private let friendRepository = FriendRepository.shared
    private let suggestionRepository = SuggestionRepository.shared
    private var listeners: [ListenerRegistration] = []

    init() {
        observeFriends()
        observeRequests()
        observeSuggestions()
        observePendingSuggestions()
    }

    deinit { listeners.forEach { $0.remove() } }

    func setActiveTab(_ tab: FriendsTab) { uiState.activeTab = tab }

    func onSearchQueryChange(_ query: String) {
        uiState.searchQuery = query
        uiState.errorMessage = nil
    }

    func clearError() { uiState.errorMessage = nil }

    func searchUsers() {
        let query = uiState.searchQuery.trimmed
        if query.isBlank {
            uiState.searchResults = []
            uiState.searchedQuery = nil
            uiState.errorMessage = nil
            uiState.isSearchLoading = false
            return
        }
        uiState.isSearchLoading = true
        uiState.errorMessage = nil
        Task {
            let (results, error) = await friendRepository.searchUsers(query: query)
            uiState.isSearchLoading = false
            uiState.searchResults = results
            // A failed search isn't "nobody found"; the error message covers it.
            uiState.searchedQuery = error == nil ? query : nil
            uiState.errorMessage = error.map { friendlyError($0, fallback: "Search failed. Please try again.") }
        }
    }

    func sendFriendRequest(toUid: String, note: String? = nil, onResult: @escaping (Bool, String?) -> Void = { _, _ in }) {
        uiState.pendingOutgoingRequests.insert(toUid)
        uiState.errorMessage = nil
        Task {
            let (success, message) = await friendRepository.sendFriendRequest(toUid: toUid, note: note)
            uiState.pendingOutgoingRequests.remove(toUid)
            uiState.errorMessage = success ? nil : friendlyError(message)
            onResult(success, message)
        }
    }

    func respondToRequest(_ requestId: String, accept: Bool) {
        uiState.pendingRequestIds.insert(requestId)
        uiState.errorMessage = nil
        Task {
            let (success, message) = await friendRepository.respondToRequest(requestId: requestId, accept: accept)
            uiState.pendingRequestIds.remove(requestId)
            uiState.errorMessage = success ? nil : friendlyError(message)
        }
    }

    func updateSuggestionStatus(_ suggestionId: String, status: String) {
        uiState.pendingSuggestionIds.insert(suggestionId)
        uiState.errorMessage = nil
        Task {
            let (success, message) = await suggestionRepository.updateSuggestionStatus(suggestionId: suggestionId, status: status)
            uiState.pendingSuggestionIds.remove(suggestionId)
            uiState.errorMessage = success ? nil : friendlyError(message)
        }
    }

    /**
     * Copies the suggested phrase into the current user's library, then marks the suggestion
     * as `saved` (which lets the backend notify the sender).
     */
    func saveSuggestionToLibrary(_ suggestion: Suggestion, onResult: @escaping (Bool, String?) -> Void = { _, _ in }) {
        guard let uid = AuthManager.getCurrentUserId() else { return onResult(false, "Not signed in") }
        uiState.pendingSuggestionIds.insert(suggestion.id)
        uiState.errorMessage = nil
        let snapshot = suggestion.phraseSnapshot
        let phrase = Phrase(
            original: snapshot.original,
            translated: snapshot.translated,
            romanized: snapshot.romanized,
            sourceLang: snapshot.sourceLang,
            targetLang: snapshot.targetLang
        )
        Task {
            let (saved, message) = await PhraseRepository.savePhrase(userId: uid, phrase: phrase)
            // Already in the library counts as saved: still mark the suggestion as saved.
            if !saved && message != PhraseRepository.alreadySaved {
                uiState.pendingSuggestionIds.remove(suggestion.id)
                uiState.errorMessage = "Couldn't save phrase"
                onResult(false, "Couldn't save phrase")
                return
            }
            let (success, statusMessage) = await suggestionRepository.updateSuggestionStatus(suggestionId: suggestion.id, status: "saved")
            uiState.pendingSuggestionIds.remove(suggestion.id)
            uiState.errorMessage = success ? nil : friendlyError(statusMessage)
            onResult(success, statusMessage)
        }
    }

    func removeFriend(_ friendUid: String, onResult: @escaping (Bool) -> Void = { _ in }) {
        uiState.removingFriendUids.insert(friendUid)
        uiState.errorMessage = nil
        Task {
            let (success, message) = await friendRepository.removeFriend(friendUid: friendUid)
            uiState.removingFriendUids.remove(friendUid)
            uiState.errorMessage = success ? nil : friendlyError(message, fallback: "Couldn't remove friend. Please try again.")
            onResult(success)
        }
    }

    // A listener can fail, most often with PERMISSION_DENIED right after logging out. It
    // just stops that list.
    private func listenerFailed(_ markLoaded: (inout FriendsUiState) -> Void) {
        markLoaded(&uiState)
        if AuthManager.getCurrentUserId() != nil {
            uiState.errorMessage = "Couldn't load friends. Check your connection."
        }
    }

    private func observeFriends() {
        if let l = friendRepository.myFriendships(onChange: { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let friendships):
                    self.uiState.friendships = friendships
                    self.uiState.friendsLoaded = true
                case .failure:
                    self.listenerFailed { $0.friendsLoaded = true }
                }
            }
        }) { listeners.append(l) } else { uiState.friendsLoaded = true }
    }

    private func observeRequests() {
        if let l = friendRepository.incomingFriendRequests(onChange: { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let requests):
                    self.uiState.incomingRequests = requests
                    self.uiState.requestsLoaded = true
                case .failure:
                    self.listenerFailed { $0.requestsLoaded = true }
                }
            }
        }) { listeners.append(l) } else { uiState.requestsLoaded = true }
    }

    private func observeSuggestions() {
        if let l = suggestionRepository.suggestionsForCurrentUser(onChange: { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let suggestions):
                    self.uiState.suggestions = suggestions
                    self.uiState.suggestionsLoaded = true
                case .failure:
                    self.listenerFailed { $0.suggestionsLoaded = true }
                }
            }
        }) { listeners.append(l) } else { uiState.suggestionsLoaded = true }
    }

    private func observePendingSuggestions() {
        if let l = suggestionRepository.pendingSuggestionsForCurrentUser(onChange: { [weak self] result in
            Task { @MainActor in
                // Same query as above; its failure is already reported.
                if case .success(let suggestions) = result { self?.uiState.pendingSuggestions = suggestions }
            }
        }) { listeners.append(l) }
    }
}

/**
 * Turns raw Firebase messages into something a person can act on. Messages our own Cloud
 * Functions throw ("You're already friends") are already readable and pass through.
 */
func friendlyError(_ raw: String?, fallback: String = "Something went wrong. Please try again.") -> String {
    guard let raw, !raw.isBlank else { return fallback }
    let e = raw.lowercased()
    if ["network", "unavailable", "offline", "timeout", "deadline"].contains(where: { e.contains($0) }) {
        return "You're offline. Try again when you reconnect."
    }
    if ["permission", "insufficient", "internal"].contains(where: { e.contains($0) }) || raw.contains("_") {
        return fallback
    }
    return raw
}

/** Live list of phrases the signed-in user has sent to one friend (their profile). */
@MainActor
final class SentSuggestionsModel: ObservableObject {
    @Published private(set) var items: [Suggestion] = []
    private var listener: ListenerRegistration?

    func start(friendUid: String) {
        listener?.remove()
        listener = SuggestionRepository.shared.suggestionsSentTo(friendUid) { [weak self] result in
            Task { @MainActor in
                // A failed listener just shows nothing sent.
                self?.items = (try? result.get()) ?? []
            }
        }
    }

    deinit { listener?.remove() }
}
