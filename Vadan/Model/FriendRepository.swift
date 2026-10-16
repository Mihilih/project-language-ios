import Foundation
import FirebaseFirestore

/** Friendships, friend requests and user search (model/FriendRepository.kt). */
final class FriendRepository {
    static let shared = FriendRepository()

    /** Live list of the signed-in user's friendships, newest first. Nil when signed out. */
    func myFriendships(onChange: @escaping (Result<[Friendship], Error>) -> Void) -> ListenerRegistration? {
        guard let currentUid = AuthManager.getCurrentUserId() else {
            onChange(.success([]))
            return nil
        }
        return Backend.db.collection("friendships")
            .whereField("users", arrayContains: currentUid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let items = (snapshot?.documents ?? []).map { doc -> Friendship in
                    let data = doc.data()
                    let users = data.stringList("users")
                    let profilesMap = data.map("userProfiles")
                    var profiles: [String: FriendProfile] = [:]
                    for uid in users {
                        let profile = profilesMap[uid] as? [String: Any] ?? [:]
                        profiles[uid] = FriendProfile(
                            uid: uid,
                            username: profile.string("username") ?? "",
                            currentStreak: profile.int("currentStreak") ?? 0,
                            learningLanguages: profile.stringList("learningLanguages")
                        )
                    }
                    return Friendship(
                        id: doc.documentID,
                        users: users,
                        userProfiles: profiles,
                        note: data.string("note"),
                        createdAt: data.timestamp("createdAt")
                    )
                }
                .sorted { ($0.createdAt?.millis ?? 0) > ($1.createdAt?.millis ?? 0) }
                onChange(.success(items))
            }
    }

    /** Pending requests sent to the signed-in user, newest first. */
    func incomingFriendRequests(onChange: @escaping (Result<[FriendRequest], Error>) -> Void) -> ListenerRegistration? {
        guard let currentUid = AuthManager.getCurrentUserId() else {
            onChange(.success([]))
            return nil
        }
        return Backend.db.collection("friendRequests")
            .whereField("toUid", isEqualTo: currentUid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let items = (snapshot?.documents ?? [])
                    .filter { ($0.data().string("status") ?? "").equalsIgnoreCase("pending") }
                    .map { doc -> FriendRequest in
                        let data = doc.data()
                        return FriendRequest(
                            id: doc.documentID,
                            fromUid: data.string("fromUid").orEmpty,
                            toUid: data.string("toUid").orEmpty,
                            status: data.string("status").orEmpty,
                            note: data.string("note"),
                            createdAt: data.timestamp("createdAt")
                        )
                    }
                    .sorted { ($0.createdAt?.millis ?? 0) > ($1.createdAt?.millis ?? 0) }
                onChange(.success(items))
            }
    }

    func respondToRequest(requestId: String, accept: Bool) async -> (Bool, String?) {
        do {
            let result = try await Backend.functions.httpsCallable("respondToFriendRequest")
                .call(["requestId": requestId, "accept": accept])
            let success = result.dict.bool("success") ?? false
            return (success, success ? nil : "Request failed")
        } catch {
            return (false, error.message)
        }
    }

    func searchUsers(query: String) async -> ([PublicUserSearchResult], String?) {
        let trimmed = query.trimmed
        if trimmed.isBlank { return ([], nil) }
        do {
            let result = try await Backend.functions.httpsCallable("searchUsers").call(["query": trimmed])
            let users = (result.dict["users"] as? [Any] ?? []).compactMap { item -> PublicUserSearchResult? in
                guard let map = item as? [String: Any], let uid = map.string("uid") else { return nil }
                return PublicUserSearchResult(uid: uid, username: map.string("username") ?? "")
            }
            return (users, nil)
        } catch {
            return ([], error.message)
        }
    }

    func sendFriendRequest(toUid: String, note: String? = nil) async -> (Bool, String?) {
        guard let currentUid = AuthManager.getCurrentUserId(), !currentUid.isBlank else {
            return (false, "Please sign in first")
        }
        var payload: [String: Any] = [
            "fromUid": currentUid,
            "toUid": toUid,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let noteValue = note?.trimmed ?? ""
        if noteValue.isNotBlank { payload["note"] = noteValue }
        do {
            _ = try await Backend.db.collection("friendRequests").addDocument(data: payload)
            return (true, nil)
        } catch {
            return (false, error.message)
        }
    }
}
