import Foundation

/**
 * On-device romanization, used when the server didn't send one (model/RomanizationHelper.kt).
 * iOS ships the same ICU transliterators as Android, reached through StringTransform.
 */
struct RomanizationHelper {
    private let sinhalaRomanizer = SinhalaRomanizer()

    func romanize(_ text: String, sourceLanguage: String) -> String {
        switch sourceLanguage {
        case "si": return sinhalaRomanizer.romanize(text)
        case "ta": return transliterateWithICU(text, "Tamil-Latin")
        case "hi", "mr": return transliterateWithICU(text, "Devanagari-Latin")
        default: return romanizeAnyScript(text, sourceLanguage)
        }
    }

    /**
     * Fallback for when the server didn't send a romanization: ICU, only for the languages it
     * handles well (`Languages.deviceRomanized`). Everything else gets none rather than a
     * misleading one.
     */
    private func romanizeAnyScript(_ text: String, _ language: String) -> String {
        guard Languages.deviceRomanized.contains(language) else { return "" }
        let romanized = transliterateWithICU(text, "Any-Latin; Latin-ASCII")
        return romanized == text ? "" : romanized
    }

    private func transliterateWithICU(_ text: String, _ transliteratorId: String) -> String {
        text.applyingTransform(StringTransform(rawValue: transliteratorId), reverse: false) ?? text
    }
}

/**
 * Sinhala → ISO 15919-style Latin, character by character. Works on Unicode scalars (not
 * Swift Characters) because a consonant and its vowel sign form one Character in Swift but
 * are separate chars in Kotlin, and the rules below look at them one at a time.
 */
struct SinhalaRomanizer {
    private let vowels: [Unicode.Scalar: String] = [
        "අ": "a", "ආ": "ā", "ඇ": "æ", "ඈ": "ǣ",
        "ඉ": "i", "ඊ": "ī", "උ": "u", "ඌ": "ū",
        "ඍ": "r̥", "ඎ": "r̥̄", "ඏ": "l̥", "ඐ": "l̥̄",
        "එ": "e", "ඒ": "ē", "ඓ": "ai",
        "ඔ": "o", "ඕ": "ō", "ඖ": "au",
    ]

    private let consonants: [Unicode.Scalar: String] = [
        "ක": "ka", "ඛ": "kha", "ග": "ga", "ඝ": "gha", "ඞ": "ṅa",
        "ච": "ca", "ඡ": "cha", "ජ": "ja", "ඣ": "jha", "ඤ": "ña",
        "ට": "ṭa", "ඨ": "ṭha", "ඩ": "ḍa", "ඪ": "ḍha", "ණ": "ṇa",
        "ත": "ta", "ථ": "tha", "ද": "da", "ධ": "dha", "න": "na",
        "ප": "pa", "ඵ": "pha", "බ": "ba", "භ": "bha", "ම": "ma",
        "ය": "ya", "ර": "ra", "ල": "la", "ව": "va",
        "ශ": "śa", "ෂ": "ṣa", "ස": "sa", "හ": "ha",
        "ළ": "ḷa", "ෆ": "fa",
    ]

    private let vowelSigns: [Unicode.Scalar: String] = [
        "\u{0DCF}": "ā", "\u{0DD0}": "æ", "\u{0DD1}": "ǣ",
        "\u{0DD2}": "i", "\u{0DD3}": "ī", "\u{0DD4}": "u", "\u{0DD6}": "ū",
        "\u{0DD8}": "r̥", "\u{0DF2}": "r̥̄", "\u{0DDF}": "l̥", "\u{0DF3}": "l̥̄",
        "\u{0DD9}": "e", "\u{0DDA}": "ē", "\u{0DDB}": "ai",
        "\u{0DDC}": "o", "\u{0DDD}": "ō", "\u{0DDE}": "au",
    ]

    private static let halKirima: Unicode.Scalar = "\u{0DCA}" // virama: removes the inherent vowel

    private let specialSigns: [Unicode.Scalar: String] = [
        "\u{0DCA}": "", // hal kirīma
        "\u{0D82}": "ṁ", // anusvara
        "\u{0D83}": "ḥ", // visarga
    ]

    func romanize(_ text: String) -> String {
        let chars = Array(text.unicodeScalars)
        var result = ""
        var i = 0
        while i < chars.count {
            let char = chars[i]
            if let vowel = vowels[char] {
                result += vowel
                i += 1
            } else if var consonant = consonants[char] {
                i += 1
                if i < chars.count {
                    let next = chars[i]
                    if next == Self.halKirima {
                        consonant = String(consonant.dropLast())
                        i += 1
                    } else if let sign = vowelSigns[next] {
                        consonant = String(consonant.dropLast()) + sign
                        i += 1
                    } else if let special = specialSigns[next] {
                        consonant += special
                        i += 1
                    }
                }
                result += consonant
            } else if let special = specialSigns[char] {
                result += special
                i += 1
            } else {
                // Punctuation, numbers, etc. stay as they are.
                result.unicodeScalars.append(char)
                i += 1
            }
        }
        return result
    }
}
