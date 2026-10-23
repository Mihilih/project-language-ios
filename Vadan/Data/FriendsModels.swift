import Foundation
import FirebaseFirestore

struct FriendRequest: Identifiable, Equatable {
    var id: String = ""
    var fromUid: String = ""
    var toUid: String = ""
    var status: String = ""
    var note: String? = nil
    var createdAt: Timestamp? = nil
}

struct Friendship: Identifiable, Equatable {
    var id: String = ""
    var users: [String] = []
    var userProfiles: [String: FriendProfile] = [:]
    var note: String? = nil
    var createdAt: Timestamp? = nil

    /** The other person in this friendship (Friendship.otherUid on Android). */
    func otherUid(_ currentUid: String?) -> String? {
        if users.isEmpty { return nil }
        guard let currentUid, !currentUid.isBlank else { return users.first }
        return users.first { $0 != currentUid } ?? users.first
    }
}

struct FriendProfile: Equatable {
    var uid: String = ""
    var username: String = ""
    var currentStreak: Int = 0
    var learningLanguages: [String] = []
}

struct PhraseSnapshot: Equatable {
    var id: String? = nil
    var original: String = ""
    var translated: String = ""
    var romanized: String = ""
    var sourceLang: String = ""
    var targetLang: String = ""
}

struct Suggestion: Identifiable, Equatable {
    var id: String = ""
    var fromUid: String = ""
    var toUid: String = ""
    var phraseSnapshot: PhraseSnapshot = PhraseSnapshot()
    var message: String? = nil
    var status: String = ""
    var createdAt: Timestamp? = nil
    var readAt: Timestamp? = nil
}

struct PublicUserSearchResult: Identifiable, Equatable {
    var uid: String = ""
    var username: String = ""
    var id: String { uid }
}

extension Phrase {
    func toSnapshot() -> PhraseSnapshot {
        PhraseSnapshot(
            id: id,
            original: original,
            translated: translated,
            romanized: romanized,
            sourceLang: sourceLang,
            targetLang: targetLang
        )
    }
}
