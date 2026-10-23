import Foundation
import FirebaseFunctions

/** A translation plus its romanization from the server (Azure), when it has one. */
struct TranslationResult: Equatable {
    let translation: String
    var romanization: String? = nil
}

struct TranslationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/**
 * Translates through the `translate` Cloud Function (model/TranslationRepository.kt). The
 * function calls Google Translate with its own service account, so no API key ships in the app.
 */
final class TranslationRepository {
    static let shared = TranslationRepository()

    private static let cacheSize = 200

    /** Recent results, so swapping languages back or retyping a phrase shows instantly. */
    private var recent: [String: TranslationResult] = [:]
    /** Least recently used first. */
    private var order: [String] = []
    private let lock = NSLock()

    /** A translation we already have for this exact request, or nil. */
    func cached(_ text: String, _ sourceLang: String, _ targetLang: String) -> TranslationResult? {
        lock.lock()
        defer { lock.unlock() }
        let k = key(text, sourceLang, targetLang)
        guard let hit = recent[k] else { return nil }
        touch(k)
        return hit
    }

    /**
     * Wakes the `translate` function (and fetches an App Check token) before the user's first
     * request, so that request doesn't pay for a cold start. Errors are ignored.
     */
    func warmUp() {
        Backend.functions.httpsCallable("translate").call(["warm": true]) { _, _ in }
    }

    func translateText(_ text: String, sourceLang: String, targetLang: String) async -> Result<TranslationResult, Error> {
        if let hit = cached(text, sourceLang, targetLang) { return .success(hit) }
        do {
            let result = try await Backend.functions.httpsCallable("translate")
                .call(["text": text, "source": sourceLang, "target": targetLang])
            let data = result.dict
            guard let translation = data.string("translation") else {
                return .failure(TranslationError(message: "No translation found"))
            }
            let romanization = data.string("romanization").flatMap { $0.isBlank ? nil : $0 }
            let value = TranslationResult(translation: translation, romanization: romanization)
            store(key(text, sourceLang, targetLang), value)
            return .success(value)
        } catch {
            print("⚠️ translate failed: \(error)")
            return .failure(TranslationError(message: friendlyMessage(error)))
        }
    }

    private func store(_ k: String, _ value: TranslationResult) {
        lock.lock()
        defer { lock.unlock() }
        recent[k] = value
        touch(k)
        while order.count > Self.cacheSize {
            recent.removeValue(forKey: order.removeFirst())
        }
    }

    /** Must be called with the lock held. */
    private func touch(_ k: String) {
        order.removeAll { $0 == k }
        order.append(k)
    }

    private func key(_ text: String, _ source: String, _ target: String) -> String { "\(source)|\(target)|\(text)" }

    private func friendlyMessage(_ error: Error) -> String {
        switch error.functionsCode {
        case .resourceExhausted:
            return "Daily translation limit reached. Try again tomorrow."
        // Signed in but still rejected = App Check didn't verify this device (e.g. a debug
        // build whose debug token isn't registered in the Firebase console).
        case .unauthenticated:
            return AuthManager.getCurrentUserId() != nil
                ? "This device couldn't be verified, so translation is blocked. Try again later."
                : "Please sign in to translate."
        case .invalidArgument:
            return error.localizedDescription.isBlank ? "That text can't be translated." : error.localizedDescription
        case .unavailable, .deadlineExceeded:
            return "Couldn't reach the translator. Check your connection."
        default:
            return "Translation failed. Please try again."
        }
    }
}
