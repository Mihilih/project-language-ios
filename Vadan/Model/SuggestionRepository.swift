import Foundation
import FirebaseFirestore

/** Phrase suggestions between friends (model/SuggestionRepository.kt). */
final class SuggestionRepository {
    static let shared = SuggestionRepository()

    /** Every suggestion sent to the signed-in user, newest first. */
    func suggestionsForCurrentUser(onChange: @escaping (Result<[Suggestion], Error>) -> Void) -> ListenerRegistration? {
        listen(pendingOnly: false, onChange: onChange)
    }

    /** Only the unread (`pending`) ones, for badges and counts. */
    func pendingSuggestionsForCurrentUser(onChange: @escaping (Result<[Suggestion], Error>) -> Void) -> ListenerRegistration? {
        listen(pendingOnly: true, onChange: onChange)
    }

    private func listen(pendingOnly: Bool, onChange: @escaping (Result<[Suggestion], Error>) -> Void) -> ListenerRegistration? {
        guard let currentUid = AuthManager.getCurrentUserId() else {
            onChange(.success([]))
            return nil
        }
        return Backend.db.collection("suggestions")
            .whereField("toUid", isEqualTo: currentUid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let items = (snapshot?.documents ?? [])
                    .filter { !pendingOnly || ($0.data().string("status") ?? "").equalsIgnoreCase("pending") }
                    .map(Self.toSuggestion)
                    .sorted { ($0.createdAt?.millis ?? 0) > ($1.createdAt?.millis ?? 0) }
                onChange(.success(items))
            }
    }

    func sendSuggestion(toUids: [String], phraseSnapshot: PhraseSnapshot, message: String? = nil) async -> (Bool, String?) {
        let cleanedTargets = toUids.map(\.trimmed).filter { !$0.isBlank }
        if cleanedTargets.isEmpty { return (false, "Select at least one friend") }
        var payload: [String: Any] = [
            "toUids": cleanedTargets,
            "phraseSnapshot": Self.toMap(phraseSnapshot),
        ]
        let cleanedMessage = message?.trimmed ?? ""
        if cleanedMessage.isNotBlank { payload["message"] = cleanedMessage }
        do {
            let result = try await Backend.functions.httpsCallable("sendPhraseSuggestion").call(payload)
            let success = result.dict.bool("success") ?? false
            return (success, success ? nil : "Suggestion failed")
        } catch {
            return (false, error.message)
        }
    }

    func updateSuggestionStatus(suggestionId: String, status: String) async -> (Bool, String?) {
        do {
            try await Backend.db.collection("suggestions").document(suggestionId).updateData([
                "status": status,
                "readAt": FieldValue.serverTimestamp(),
            ])
            return (true, nil)
        } catch {
            return (false, error.message)
        }
    }

    /** Phrases the signed-in user has sent to `friendUid`, newest first (for their profile). */
    func suggestionsSentTo(_ friendUid: String, onChange: @escaping (Result<[Suggestion], Error>) -> Void) -> ListenerRegistration? {
        guard let currentUid = AuthManager.getCurrentUserId() else {
            onChange(.success([]))
            return nil
        }
        return Backend.db.collection("suggestions")
            .whereField("fromUid", isEqualTo: currentUid)
            .whereField("toUid", isEqualTo: friendUid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let items = (snapshot?.documents ?? [])
                    .map(Self.toSuggestion)
                    .sorted { ($0.createdAt?.millis ?? 0) > ($1.createdAt?.millis ?? 0) }
                onChange(.success(items))
            }
    }

    private static func toSuggestion(_ doc: QueryDocumentSnapshot) -> Suggestion {
        let data = doc.data()
        let snapshot = data["phraseSnapshot"] as? [String: Any]
        return Suggestion(
            id: doc.documentID,
            fromUid: data.string("fromUid").orEmpty,
            toUid: data.string("toUid").orEmpty,
            phraseSnapshot: snapshot.map(toPhraseSnapshot) ?? PhraseSnapshot(),
            message: data.string("message"),
            status: data.string("status").orEmpty,
            createdAt: data.timestamp("createdAt"),
            readAt: data.timestamp("readAt")
        )
    }

    private static func toMap(_ snapshot: PhraseSnapshot) -> [String: Any] {
        [
            "id": snapshot.id.map { $0 as Any } ?? NSNull(),
            "original": snapshot.original,
            "translated": snapshot.translated,
            "romanized": snapshot.romanized,
            "sourceLang": snapshot.sourceLang,
            "targetLang": snapshot.targetLang,
        ]
    }

    private static func toPhraseSnapshot(_ map: [String: Any]) -> PhraseSnapshot {
        PhraseSnapshot(
            id: map.string("id"),
            original: map.string("original") ?? "",
            translated: map.string("translated") ?? "",
            romanized: map.string("romanized") ?? "",
            sourceLang: map.string("sourceLang") ?? "",
            targetLang: map.string("targetLang") ?? ""
        )
    }
}
