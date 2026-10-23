import SwiftUI

/**
 * Resolves usernames for uids, starting from names already known (e.g. friendship profiles)
 * and fetching the rest from `users/{uid}` once each (rememberUsernames in Usernames.kt).
 * Each screen owns one with @StateObject.
 */
@MainActor
final class UsernameResolver: ObservableObject {
    @Published private(set) var fetched: [String: String] = [:]
    private var requested = Set<String>()

    /** Known names merged with fetched ones; starts fetching any that are missing. */
    func names(for uids: [String], known: [String: String]) -> [String: String] {
        let missing = uids.filter { !$0.isBlank && known[$0] == nil && fetched[$0] == nil && !requested.contains($0) }
        if !missing.isEmpty {
            // Fetch after this render pass (publishing during a view update isn't allowed).
            DispatchQueue.main.async { [weak self] in self?.fetch(missing) }
        }
        return known.merging(fetched) { knownName, _ in knownName }
    }

    private func fetch(_ uids: [String]) {
        for uid in uids where !requested.contains(uid) {
            requested.insert(uid)
            Backend.db.collection("users").document(uid).getDocument { [weak self] doc, _ in
                let username = (doc?.data()?.string("username")).orEmpty.trimmed
                Task { @MainActor in
                    if !username.isBlank { self?.fetched[uid] = username }
                }
            }
        }
    }
}
