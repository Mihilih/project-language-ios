import Foundation
import CryptoKit
import FirebaseFirestore

/** The user's saved phrases at `users/{uid}/phrases` (model/PhraseRepository.kt). */
enum PhraseRepository {
    /** Passed as the message when a save is skipped because the phrase is already saved. */
    static let alreadySaved = "already_saved"

    private static func phrases(_ userId: String) -> CollectionReference {
        Backend.db.collection("users").document(userId).collection("phrases")
    }

    /**
     * The same phrase (same text and language pair, ignoring case and extra spaces) always gets
     * the same document id, so it can only be saved once. Must stay identical to Android's
     * phraseKey so a phrase saved on one platform is recognised on the other.
     */
    static func phraseKey(_ phrase: Phrase) -> String {
        // Java's \s (no UNICODE_CHARACTER_CLASS) is exactly these six characters.
        let collapsed = phrase.original.trimmed.lowercased()
            .replacingOccurrences(of: "[ \\t\\n\\u000B\\f\\r]+", with: " ", options: .regularExpression)
        let normalized = [
            phrase.sourceLang.trimmed.lowercased(),
            phrase.targetLang.trimmed.lowercased(),
            collapsed,
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().take(32)
    }

    /**
     * Saves `phrase` unless it's already in the library. On success the message is the
     * document id; for a duplicate it's `alreadySaved` with success = false.
     */
    static func savePhrase(userId: String, phrase: Phrase) async -> (Bool, String?) {
        let ref = phrases(userId).document(phraseKey(phrase))
        do {
            _ = try await Backend.db.runTransaction { tx, errorPointer -> Any? in
                do {
                    if try tx.getDocument(ref).exists {
                        errorPointer?.pointee = NSError(
                            domain: FirestoreErrorDomain,
                            code: FirestoreErrorCode.alreadyExists.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: alreadySaved]
                        )
                        return nil
                    }
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                tx.setData(toMap(phrase), forDocument: ref)
                return nil
            }
            return (true, ref.documentID)
        } catch {
            return (false, error.firestoreCode == .alreadyExists ? alreadySaved : error.message)
        }
    }

    /** Puts a deleted phrase back exactly as it was (same id, favorite and date) — for Undo. */
    static func restorePhrase(userId: String, phrase: Phrase) {
        guard !phrase.id.isBlank else { return }
        phrases(userId).document(phrase.id).setData(toMap(phrase))
    }

    static func deletePhrase(userId: String, phraseId: String) async -> (Bool, String?) {
        do {
            try await phrases(userId).document(phraseId).delete()
            return (true, nil)
        } catch {
            return (false, error.message)
        }
    }

    /**
     * Live view of the library: calls back with the current phrases and again after every save,
     * delete or favorite — including this device's own writes, immediately — so the Library
     * never needs a manual reload.
     */
    static func observePhrases(userId: String, onChange: @escaping (Result<[Phrase], Error>) -> Void) -> ListenerRegistration {
        phrases(userId).addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }
            onChange(.success((snapshot?.documents ?? []).map(toPhrase)))
        }
    }

    static func getPhrases(userId: String) async -> [Phrase] {
        do {
            return try await phrases(userId).getDocuments().documents.map(toPhrase)
        } catch {
            return []
        }
    }

    static func toggleFavorite(userId: String, phraseId: String, isFavorite: Bool) async -> (Bool, String?) {
        do {
            try await phrases(userId).document(phraseId).updateData(["isFavorite": isFavorite])
            return (true, nil)
        } catch {
            return (false, error.message)
        }
    }

    private static func toMap(_ phrase: Phrase) -> [String: Any] {
        [
            "original": phrase.original,
            "translated": phrase.translated,
            "romanized": phrase.romanized,
            "sourceLang": phrase.sourceLang,
            "targetLang": phrase.targetLang,
            "isFavorite": phrase.isFavorite,
            "timestamp": phrase.timestamp,
        ]
    }

    private static func toPhrase(_ doc: DocumentSnapshot) -> Phrase {
        let data = doc.data() ?? [:]
        return Phrase(
            id: doc.documentID,
            original: data.string("original").orEmpty,
            translated: data.string("translated").orEmpty,
            romanized: data.string("romanized").orEmpty,
            sourceLang: data.string("sourceLang").orEmpty,
            targetLang: data.string("targetLang").orEmpty,
            isFavorite: data.bool("isFavorite") ?? false,
            timestamp: data.int64("timestamp") ?? Phrase.nowMillis()
        )
    }
}
