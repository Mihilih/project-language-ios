import Foundation
import Combine
import UIKit
import FirebaseAuth
import FirebaseFirestore

/** Saves the answer to "What are you learning?" as the user's favorite languages. */
@MainActor
final class LearningLanguagesViewModel: ObservableObject {
    private let languagePrefs = LanguagePrefsRepository.shared

    init() {
        languagePrefs.bind(AuthManager.getCurrentUserId())
    }

    func save(_ codes: [String]) {
        languagePrefs.setLearningLanguages(codes, deviceLanguage: Locale.preferredLanguages.first)
    }
}

/**
 * The number on the Friends tab: pending friend requests plus unread phrase suggestions.
 * Follows sign-in/out, so it never shows (or listens for) another account's counts.
 */
@MainActor
final class BadgeViewModel: ObservableObject {
    @Published private(set) var friendsBadge = 0

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var uid: String?
    private var requestsListener: ListenerRegistration?
    private var suggestionsListener: ListenerRegistration?
    private var requests = 0
    private var suggestions = 0

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.bind(user?.uid) }
        }
    }

    deinit {
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
        requestsListener?.remove()
        suggestionsListener?.remove()
    }

    private func bind(_ newUid: String?) {
        if newUid == uid && (newUid == nil || requestsListener != nil) { return }
        uid = newUid
        requestsListener?.remove()
        suggestionsListener?.remove()
        requestsListener = nil
        suggestionsListener = nil
        requests = 0
        suggestions = 0
        friendsBadge = 0
        guard newUid != nil else { return }
        requestsListener = FriendRepository.shared.incomingFriendRequests { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.requests = (try? result.get().count) ?? 0
                self.friendsBadge = self.requests + self.suggestions
            }
        }
        suggestionsListener = SuggestionRepository.shared.pendingSuggestionsForCurrentUser { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.suggestions = (try? result.get().count) ?? 0
                self.friendsBadge = self.requests + self.suggestions
            }
        }
    }
}

struct SuggestToFriendUiState {
    var friendships: [Friendship] = []
    var isLoadingFriends = true
    var friendsError = false
    var isSending = false
}

/** Backs the "Suggest to a friend" sheet: the friend list, and sending. */
@MainActor
final class SuggestToFriendViewModel: ObservableObject {
    @Published private(set) var uiState = SuggestToFriendUiState()
    private var listener: ListenerRegistration?

    init() {
        listener = FriendRepository.shared.myFriendships { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let friendships):
                    self.uiState.friendships = friendships
                    self.uiState.isLoadingFriends = false
                    self.uiState.friendsError = false
                case .failure:
                    self.uiState.isLoadingFriends = false
                    self.uiState.friendsError = true
                    self.listener?.remove()
                }
            }
        }
    }

    deinit { listener?.remove() }

    func send(toUids: [String], phrase: PhraseSnapshot, message: String?, onResult: @escaping (Bool, String?) -> Void) {
        if uiState.isSending { return }
        uiState.isSending = true
        Task {
            let (success, error) = await SuggestionRepository.shared.sendSuggestion(toUids: toUids, phraseSnapshot: phrase, message: message)
            uiState.isSending = false
            onResult(success, error)
        }
    }
}

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug, translation, idea, other

    var id: String { rawValue }
    var key: String { rawValue }

    var label: String {
        switch self {
        case .bug: return "Something's broken"
        case .translation: return "Translation issue"
        case .idea: return "Idea"
        case .other: return "Other"
        }
    }
}

struct FeedbackUiState {
    var sending = false
    var error: String? = nil
}

/** Sends the Profile "Send feedback" form through the `sendFeedback` function. */
@MainActor
final class FeedbackViewModel: ObservableObject {
    static let maxMessage = 2000

    @Published private(set) var uiState = FeedbackUiState()

    func send(category: FeedbackCategory, message: String, onSent: @escaping () -> Void) {
        if uiState.sending { return }
        uiState = FeedbackUiState(sending: true)
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        #if DEBUG
        let debugSuffix = " debug"
        #else
        let debugSuffix = ""
        #endif
        let payload: [String: Any] = [
            "category": category.key,
            "message": message.trimmed,
            // Helps reproduce bugs; no personal data beyond what the user typed.
            "appVersion": "\(version) (\(build))\(debugSuffix)",
            "device": "Apple \(Self.modelIdentifier()), iOS \(UIDevice.current.systemVersion)",
        ]
        Task {
            do {
                _ = try await Backend.functions.httpsCallable("sendFeedback").call(payload)
                uiState = FeedbackUiState()
                onSent()
            } catch {
                uiState = FeedbackUiState(error: friendly(error))
            }
        }
    }

    func clearError() {
        uiState.error = nil
    }

    private func friendly(_ error: Error) -> String {
        switch error.functionsCode {
        case .resourceExhausted, .invalidArgument:
            return error.localizedDescription.isBlank ? "Couldn't send feedback." : error.localizedDescription
        case .unavailable, .deadlineExceeded:
            return "You're offline. Try again when you're connected."
        default:
            return "Couldn't send feedback. Please try again."
        }
    }

    /** e.g. "iPhone16,2" (or the simulated model in the Simulator). */
    private static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) Simulator"
        }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
