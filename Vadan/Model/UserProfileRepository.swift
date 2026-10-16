import Foundation
import FirebaseFirestore

/**
 * Owns the public profile stored at `users/{uid}` and the username registry at
 * `usernames/{usernameLower}` (value: `{ uid, username }`) — model/UserProfileRepository.kt.
 *
 * The registry doc is what guarantees uniqueness: claiming a username creates it and writes
 * the profile in the same transaction, so two users can never end up with the same name.
 */
final class UserProfileRepository {
    static let shared = UserProfileRepository()

    static let minLength = 3
    static let maxLength = 20
    static let bioMaxLength = 160

    private static let users = "users"
    private static let usernames = "usernames"
    private static let claimErrorDomain = "UsernameClaim"

    /** Returns a user-facing message describing what's wrong, or nil if `username` is valid. */
    static func validateUsername(_ username: String) -> String? {
        let name = username.trimmed
        if name.count < minLength { return "Use at least \(minLength) characters" }
        if name.count > maxLength { return "Use at most \(maxLength) characters" }
        if name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_.]*$", options: .regularExpression) == nil {
            return "Use letters, numbers, underscores or periods, starting with a letter or number"
        }
        if name.contains("..") { return "Periods can't be next to each other" }
        if name.hasSuffix(".") { return "Usernames can't end with a period" }
        return nil
    }

    /** The current username for `uid` (blank if none yet), or an error message. */
    func fetchUsername(uid: String) async -> (String?, String?) {
        do {
            let doc = try await Backend.db.collection(Self.users).document(uid).getDocument()
            return ((doc.data()?.string("username")).orEmpty.trimmed, nil)
        } catch {
            return (nil, error.message)
        }
    }

    /** Loads `username`, `bio` (blank when unset) and `photo` (base64 JPEG or nil) for `uid`. */
    func fetchProfile(uid: String) async -> (username: String, bio: String, photo: String?) {
        do {
            let data = try await Backend.db.collection(Self.users).document(uid).getDocument().data() ?? [:]
            return (data.string("username").orEmpty.trimmed, data.string("bio").orEmpty.trimmed, data.string("photo"))
        } catch {
            return ("", "", nil)
        }
    }

    /** Sets the profile photo (a small base64 JPEG), or removes it when `photo` is nil. */
    func updatePhoto(_ photo: String?) async -> (Bool, String?) {
        guard let uid = AuthManager.getCurrentUserId() else { return (false, "You need to be signed in") }
        do {
            try await Backend.db.collection(Self.users).document(uid)
                .setData(["photo": photo.map { $0 as Any } ?? FieldValue.delete()], merge: true)
            return (true, nil)
        } catch {
            return (false, "Couldn't save your photo. Please try again.")
        }
    }

    /** Updates only the bio; username stays untouched so the rules' immutability check passes. */
    func updateBio(_ bio: String) async -> (Bool, String?) {
        guard let uid = AuthManager.getCurrentUserId() else { return (false, "You need to be signed in") }
        let cleaned = bio.trimmed.take(Self.bioMaxLength)
        do {
            try await Backend.db.collection(Self.users).document(uid).setData(["bio": cleaned], merge: true)
            return (true, nil)
        } catch {
            return (false, error.message.isBlank ? "Couldn't save bio" : error.message)
        }
    }

    /**
     * Whether `username` is free to claim: true / false, or nil if it couldn't check
     * (offline) — claiming still re-checks inside a transaction.
     */
    func isUsernameAvailable(_ username: String) async -> Bool? {
        let lower = username.trimmed.lowercased()
        let uid = AuthManager.getCurrentUserId()
        do {
            let snap = try await Backend.db.collection(Self.usernames).document(lower).getDocument()
            return !snap.exists || snap.data()?.string("uid") == uid
        } catch {
            return nil
        }
    }

    func claimUsername(_ username: String) async -> (Bool, String?) {
        guard let uid = AuthManager.getCurrentUserId() else { return (false, "You need to be signed in") }
        let cleaned = username.trimmed
        if let problem = Self.validateUsername(cleaned) { return (false, problem) }

        let lower = cleaned.lowercased()
        let userRef = Backend.db.collection(Self.users).document(uid)
        let nameRef = Backend.db.collection(Self.usernames).document(lower)

        do {
            _ = try await Backend.db.runTransaction { tx, errorPointer -> Any? in
                // All reads must happen before any writes in a Firestore transaction.
                let userSnap: DocumentSnapshot
                let claimSnap: DocumentSnapshot
                do {
                    userSnap = try tx.getDocument(userRef)
                    claimSnap = try tx.getDocument(nameRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                let existing = (userSnap.data()?.string("username")).orEmpty
                if existing.isNotBlank {
                    if existing.equalsIgnoreCase(cleaned) { return nil }
                    errorPointer?.pointee = Self.claimError("You already have the username @\(existing)")
                    return nil
                }

                let claimedBy = claimSnap.data()?.string("uid")
                if claimSnap.exists && claimedBy != uid {
                    errorPointer?.pointee = Self.claimError("@\(cleaned) is already taken")
                    return nil
                }

                if !claimSnap.exists {
                    tx.setData([
                        "uid": uid,
                        "username": cleaned,
                        "createdAt": FieldValue.serverTimestamp(),
                    ], forDocument: nameRef)
                }

                // Email is deliberately NOT stored here: this doc is readable by every signed-in
                // user. Email search uses Firebase Auth in the searchUsers Cloud Function instead.
                tx.setData([
                    "username": cleaned,
                    "usernameLower": lower,
                    "profileCreatedAt": FieldValue.serverTimestamp(),
                ], forDocument: userRef, merge: true)
                return nil
            }
            return (true, nil)
        } catch {
            let ns = error as NSError
            if ns.domain == Self.claimErrorDomain { return (false, ns.localizedDescription) }
            return (false, error.message.isBlank ? "Couldn't save username" : error.message)
        }
    }

    /**
     * Renames the signed-in user: claims `newName`, releases their old name and updates the
     * profile, all in one transaction. A change of case only keeps the same claim. Friend cards
     * pick up the new name through the onUsernameChanged Cloud Function.
     */
    func changeUsername(_ newName: String) async -> (Bool, String?) {
        guard let uid = AuthManager.getCurrentUserId() else { return (false, "You need to be signed in") }
        let cleaned = newName.trimmed
        if let problem = Self.validateUsername(cleaned) { return (false, problem) }
        let lower = cleaned.lowercased()
        let userRef = Backend.db.collection(Self.users).document(uid)
        let newRef = Backend.db.collection(Self.usernames).document(lower)

        do {
            _ = try await Backend.db.runTransaction { tx, errorPointer -> Any? in
                let userSnap: DocumentSnapshot
                let claimSnap: DocumentSnapshot
                do {
                    userSnap = try tx.getDocument(userRef)
                    claimSnap = try tx.getDocument(newRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                let current = (userSnap.data()?.string("username")).orEmpty
                let currentLower = (userSnap.data()?.string("usernameLower")).orEmpty
                if current == cleaned { return nil }
                if claimSnap.exists && claimSnap.data()?.string("uid") != uid {
                    errorPointer?.pointee = Self.claimError("@\(cleaned) is already taken")
                    return nil
                }
                let createdAt: Any = claimSnap.data()?.timestamp("createdAt") ?? FieldValue.serverTimestamp()
                tx.setData(["uid": uid, "username": cleaned, "createdAt": createdAt], forDocument: newRef)
                if currentLower.isNotBlank && currentLower != lower {
                    tx.deleteDocument(Backend.db.collection(Self.usernames).document(currentLower))
                }
                tx.setData(["username": cleaned, "usernameLower": lower], forDocument: userRef, merge: true)
                return nil
            }
            return (true, nil)
        } catch {
            let ns = error as NSError
            if ns.domain == Self.claimErrorDomain { return (false, ns.localizedDescription) }
            return (false, "Couldn't change your username. Please try again.")
        }
    }

    private static func claimError(_ message: String) -> NSError {
        NSError(domain: claimErrorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
