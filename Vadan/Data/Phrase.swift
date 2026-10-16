import Foundation

struct Phrase: Identifiable, Equatable, Hashable {
    var id: String = ""
    var original: String = ""
    var translated: String = ""
    var romanized: String = ""
    var sourceLang: String = ""
    var targetLang: String = ""
    var isFavorite: Bool = false
    /** Milliseconds since 1970, like Android's System.currentTimeMillis(). */
    var timestamp: Int64 = Phrase.nowMillis()

    static func nowMillis() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
