import Foundation

/**
 * A study session to open (Android's "study/session?filter=…&lang=…" route). `filter` is one
 * of all / favorites / this_week / this_month / language / selection.
 */
struct StudyRoute: Identifiable, Equatable {
    let id = UUID()
    let filter: String
    var lang: String = ""
}

/**
 * The exact phrases the Library's "Study N Phrases" button hands to a study session (whatever
 * search and filters are applied there). Kept in memory rather than in the route, like Android.
 * If it's empty, the session falls back to the whole library.
 */
enum StudySelection {
    static let filter = "selection"

    private(set) static var phraseIds: [String] = []

    static func set(_ ids: [String]) { phraseIds = ids }

    /** Route for a study session over `ids`. */
    static func route(_ ids: [String]) -> StudyRoute {
        set(ids)
        return StudyRoute(filter: filter, lang: "")
    }
}
