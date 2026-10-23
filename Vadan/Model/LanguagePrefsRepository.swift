import Foundation
import Combine
import FirebaseFirestore

/** The user's language picker state: starred languages, recently used ones, and the last pair. */
struct LanguagePrefs: Equatable {
    var favorites: [String] = Languages.defaultFavorites
    var recents: [String] = []
    var lastSource: String = "en"
    var lastTarget: String = "si"
}

/**
 * Keeps `LanguagePrefs` on the device (so Translate opens on the right pair instantly) and in
 * `users/{uid}/private/languages` (so favorites follow the user to a new phone). The device
 * copy shows first; the Firestore copy replaces it once it arrives (LanguagePrefsRepository.kt).
 *
 * Someone who has never set anything gets the original five languages as favorites.
 */
@MainActor
final class LanguagePrefsRepository: ObservableObject {
    static let shared = LanguagePrefsRepository()

    private static let filePrefix = "language_prefs."
    private static let maxRecents = 5

    @Published private(set) var prefs = LanguagePrefs()

    private var boundUid: String?
    /** Whether the user changed something before Firestore answered (then theirs wins). */
    private var changedLocally = false
    private let local = UserDefaults.standard

    /**
     * Load prefs for `uid` (or for signed-out use when nil). Cheap to call again for the same
     * user — Translate calls it every time it opens.
     */
    func bind(_ uid: String?) {
        if uid == boundUid && uid != nil { return }
        boundUid = uid
        changedLocally = false
        prefs = readLocal(uid) ?? LanguagePrefs()
        guard let uid else { return }

        doc(uid).getDocument { [weak self] snap, error in
            Task { @MainActor in
                guard let self, self.boundUid == uid else { return }
                if let error {
                    print("LanguagePrefs: couldn't load language prefs: \(error)")
                    return
                }
                let remote = (snap?.exists == true) ? self.fromMap(snap?.data() ?? [:]) : nil
                if self.changedLocally || remote == nil {
                    self.save(uid, self.prefs)
                } else if let remote {
                    self.prefs = remote
                    self.writeLocal(uid, remote)
                }
            }
        }
    }

    func toggleFavorite(_ code: String) {
        update { prefs in
            var next = prefs
            if prefs.favorites.contains(code) {
                next.favorites.removeAll { $0 == code }
            } else {
                next.favorites.append(code)
            }
            return next
        }
    }

    /** Remember the pair the user is on, and move both languages to the front of Recent. */
    func usePair(source: String, target: String) {
        update { prefs in
            var next = prefs
            next.lastSource = source
            next.lastTarget = target
            next.recents = Array(([target, source] + prefs.recents).uniqued().prefix(Self.maxRecents))
            return next
        }
    }

    /**
     * From the "What are you learning?" setup step: those languages (plus the phone's own
     * language, which is usually the one they translate from) become the favorites, replacing
     * the default five, and Translate opens on phone language → first learning language.
     */
    func setLearningLanguages(_ codes: [String], deviceLanguage: String?) {
        update { prefs in
            let learning = codes.compactMap { Languages.find($0)?.code }.uniqued()
            guard let firstLearning = learning.first else { return prefs }
            // "si-LK" → Sinhala, "zh-TW" → Chinese (Traditional), "en-US" → English.
            let device = Languages.find(deviceLanguage) ??
                Languages.find(deviceLanguage.map { String($0.split(separator: "-").first ?? "") })
            let home: String
            if let code = device?.code, !learning.contains(code) {
                home = code
            } else if !learning.contains("en") {
                home = "en"
            } else {
                home = Languages.all.first { !learning.contains($0.code) }!.code
            }
            return LanguagePrefs(favorites: [home] + learning, recents: [], lastSource: home, lastTarget: firstLearning)
        }
    }

    private func update(_ change: (LanguagePrefs) -> LanguagePrefs) {
        let next = change(prefs)
        if next == prefs { return }
        prefs = next
        changedLocally = true
        writeLocal(boundUid, next)
        if let uid = boundUid { save(uid, next) }
    }

    private func save(_ uid: String, _ prefs: LanguagePrefs) {
        doc(uid).setData([
            "favorites": prefs.favorites,
            "recents": prefs.recents,
            "lastSource": prefs.lastSource,
            "lastTarget": prefs.lastTarget,
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true) { error in
            if let error { print("LanguagePrefs: couldn't save language prefs: \(error)") }
        }
    }

    private func readLocal(_ uid: String?) -> LanguagePrefs? {
        let prefix = keyPrefix(uid)
        guard let favorites = local.string(forKey: prefix + "favorites") else { return nil }
        func list(_ raw: String?) -> [String] { (raw ?? "").split(separator: ",").map(String.init).filter { !$0.isBlank } }
        return clean(LanguagePrefs(
            favorites: list(favorites),
            recents: list(local.string(forKey: prefix + "recents")),
            lastSource: local.string(forKey: prefix + "lastSource") ?? "en",
            lastTarget: local.string(forKey: prefix + "lastTarget") ?? "si"
        ))
    }

    private func writeLocal(_ uid: String?, _ prefs: LanguagePrefs) {
        let prefix = keyPrefix(uid)
        local.set(prefs.favorites.joined(separator: ","), forKey: prefix + "favorites")
        local.set(prefs.recents.joined(separator: ","), forKey: prefix + "recents")
        local.set(prefs.lastSource, forKey: prefix + "lastSource")
        local.set(prefs.lastTarget, forKey: prefix + "lastTarget")
    }

    private func fromMap(_ data: [String: Any]) -> LanguagePrefs {
        clean(LanguagePrefs(
            favorites: (data["favorites"] as? [Any])?.compactMap { $0 as? String } ?? Languages.defaultFavorites,
            recents: data.stringList("recents"),
            lastSource: data.string("lastSource") ?? "en",
            lastTarget: data.string("lastTarget") ?? "si"
        ))
    }

    /** Drop codes the app no longer knows and map old aliases (e.g. "iw") to current codes. */
    private func clean(_ prefs: LanguagePrefs) -> LanguagePrefs {
        func codes(_ list: [String]) -> [String] { list.compactMap { Languages.find($0)?.code }.uniqued() }
        return LanguagePrefs(
            favorites: codes(prefs.favorites),
            recents: Array(codes(prefs.recents).prefix(Self.maxRecents)),
            lastSource: Languages.find(prefs.lastSource)?.code ?? "en",
            lastTarget: Languages.find(prefs.lastTarget)?.code ?? "si"
        )
    }

    private func keyPrefix(_ uid: String?) -> String { Self.filePrefix + (uid ?? "signed_out") + ":" }

    private func doc(_ uid: String) -> DocumentReference {
        Backend.db.collection("users").document(uid).collection("private").document("languages")
    }
}

extension Array where Element: Hashable {
    /** Kotlin's distinct(): first occurrence of each element, in order. */
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
