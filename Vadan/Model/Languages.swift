import Foundation

/** A language the app can translate. Codes are what we send to `translate` and store on phrases. */
struct Language: Identifiable, Hashable {
    let name: String
    let code: String
    let nativeName: String
    var id: String { code }
}

/**
 * Every language Google Cloud Translation supports, A–Z by English name, with its name in that
 * language (model/Languages.kt on Android, generated from the same table). 192 languages.
 *
 * Codes are what we send to the `translate` function and store on phrases (`sourceLang` /
 * `targetLang`), so never change an existing code — add an alias in `aliases` instead.
 */
enum Languages {
    static let all: [Language] = [
        Language(name: "Abkhaz", code: "ab", nativeName: "аԥсуа"),
        Language(name: "Acehnese", code: "ace", nativeName: "Bahsa Acèh"),
        Language(name: "Acholi", code: "ach", nativeName: "Lwo"),
        Language(name: "Afrikaans", code: "af", nativeName: "Afrikaans"),
        Language(name: "Albanian", code: "sq", nativeName: "shqip"),
        Language(name: "Alur", code: "alz", nativeName: "Dho-Alur"),
        Language(name: "Amharic", code: "am", nativeName: "አማርኛ"),
        Language(name: "Arabic", code: "ar", nativeName: "العربية"),
        Language(name: "Armenian", code: "hy", nativeName: "հայերեն"),
        Language(name: "Assamese", code: "as", nativeName: "অসমীয়া"),
        Language(name: "Awadhi", code: "awa", nativeName: "अवधी"),
        Language(name: "Aymara", code: "ay", nativeName: "Aymar aru"),
        Language(name: "Azerbaijani", code: "az", nativeName: "azərbaycan"),
        Language(name: "Balinese", code: "ban", nativeName: "Basa Bali"),
        Language(name: "Bambara", code: "bm", nativeName: "bamanakan"),
        Language(name: "Bashkir", code: "ba", nativeName: "башҡорт"),
        Language(name: "Basque", code: "eu", nativeName: "euskara"),
        Language(name: "Batak Karo", code: "btx", nativeName: "Cakap Karo"),
        Language(name: "Batak Simalungun", code: "bts", nativeName: "Sahap Simalungun"),
        Language(name: "Batak Toba", code: "bbc", nativeName: "Hata Batak Toba"),
        Language(name: "Belarusian", code: "be", nativeName: "беларуская"),
        Language(name: "Bemba", code: "bem", nativeName: "Ichibemba"),
        Language(name: "Bengali", code: "bn", nativeName: "বাংলা"),
        Language(name: "Betawi", code: "bew", nativeName: "Betawi"),
        Language(name: "Bhojpuri", code: "bho", nativeName: "भोजपुरी"),
        Language(name: "Bikol", code: "bik", nativeName: "Bikol"),
        Language(name: "Bosnian", code: "bs", nativeName: "bosanski"),
        Language(name: "Breton", code: "br", nativeName: "brezhoneg"),
        Language(name: "Bulgarian", code: "bg", nativeName: "български"),
        Language(name: "Buryat", code: "bua", nativeName: "буряад"),
        Language(name: "Cantonese", code: "yue", nativeName: "粵語"),
        Language(name: "Catalan", code: "ca", nativeName: "català"),
        Language(name: "Cebuano", code: "ceb", nativeName: "Cebuano"),
        Language(name: "Chichewa", code: "ny", nativeName: "Chichewa"),
        Language(name: "Chinese (Simplified)", code: "zh-CN", nativeName: "中文（简体）"),
        Language(name: "Chinese (Traditional)", code: "zh-TW", nativeName: "中文（繁體）"),
        Language(name: "Chuvash", code: "cv", nativeName: "чӑвашла"),
        Language(name: "Corsican", code: "co", nativeName: "corsu"),
        Language(name: "Crimean Tatar", code: "crh", nativeName: "qırımtatar tili"),
        Language(name: "Croatian", code: "hr", nativeName: "hrvatski"),
        Language(name: "Czech", code: "cs", nativeName: "čeština"),
        Language(name: "Danish", code: "da", nativeName: "dansk"),
        Language(name: "Dinka", code: "din", nativeName: "Thuɔŋjäŋ"),
        Language(name: "Divehi", code: "dv", nativeName: "ދިވެހި"),
        Language(name: "Dogri", code: "doi", nativeName: "डोगरी"),
        Language(name: "Dombe", code: "dov", nativeName: "ChiDombe"),
        Language(name: "Dutch", code: "nl", nativeName: "Nederlands"),
        Language(name: "Dzongkha", code: "dz", nativeName: "རྫོང་ཁ"),
        Language(name: "English", code: "en", nativeName: "English"),
        Language(name: "Esperanto", code: "eo", nativeName: "esperanto"),
        Language(name: "Estonian", code: "et", nativeName: "eesti"),
        Language(name: "Ewe", code: "ee", nativeName: "Eʋegbe"),
        Language(name: "Fijian", code: "fj", nativeName: "Vosa Vakaviti"),
        Language(name: "Filipino", code: "tl", nativeName: "Filipino"),
        Language(name: "Finnish", code: "fi", nativeName: "suomi"),
        Language(name: "French", code: "fr", nativeName: "français"),
        Language(name: "French (Canada)", code: "fr-CA", nativeName: "français (Canada)"),
        Language(name: "Frisian", code: "fy", nativeName: "Frysk"),
        Language(name: "Fulfulde", code: "ff", nativeName: "Fulfulde"),
        Language(name: "Ga", code: "gaa", nativeName: "Gã"),
        Language(name: "Galician", code: "gl", nativeName: "galego"),
        Language(name: "Ganda", code: "lg", nativeName: "Luganda"),
        Language(name: "Georgian", code: "ka", nativeName: "ქართული"),
        Language(name: "German", code: "de", nativeName: "Deutsch"),
        Language(name: "Greek", code: "el", nativeName: "Ελληνικά"),
        Language(name: "Guarani", code: "gn", nativeName: "Avañe'ẽ"),
        Language(name: "Gujarati", code: "gu", nativeName: "ગુજરાતી"),
        Language(name: "Haitian Creole", code: "ht", nativeName: "Kreyòl ayisyen"),
        Language(name: "Hakha Chin", code: "cnh", nativeName: "Laiholh"),
        Language(name: "Hausa", code: "ha", nativeName: "Hausa"),
        Language(name: "Hawaiian", code: "haw", nativeName: "ʻŌlelo Hawaiʻi"),
        Language(name: "Hebrew", code: "he", nativeName: "עברית"),
        Language(name: "Hiligaynon", code: "hil", nativeName: "Ilonggo"),
        Language(name: "Hindi", code: "hi", nativeName: "हिंदी"),
        Language(name: "Hmong", code: "hmn", nativeName: "Hmoob"),
        Language(name: "Hungarian", code: "hu", nativeName: "magyar"),
        Language(name: "Hunsrik", code: "hrx", nativeName: "Hunsrik"),
        Language(name: "Icelandic", code: "is", nativeName: "íslenska"),
        Language(name: "Igbo", code: "ig", nativeName: "Igbo"),
        Language(name: "Iloko", code: "ilo", nativeName: "Ilokano"),
        Language(name: "Indonesian", code: "id", nativeName: "Bahasa Indonesia"),
        Language(name: "Irish", code: "ga", nativeName: "Gaeilge"),
        Language(name: "Italian", code: "it", nativeName: "italiano"),
        Language(name: "Japanese", code: "ja", nativeName: "日本語"),
        Language(name: "Javanese", code: "jv", nativeName: "Jawa"),
        Language(name: "Kannada", code: "kn", nativeName: "ಕನ್ನಡ"),
        Language(name: "Kapampangan", code: "pam", nativeName: "Kapampangan"),
        Language(name: "Kazakh", code: "kk", nativeName: "қазақ тілі"),
        Language(name: "Khmer", code: "km", nativeName: "ខ្មែរ"),
        Language(name: "Kiga", code: "cgg", nativeName: "Rukiga"),
        Language(name: "Kinyarwanda", code: "rw", nativeName: "Ikinyarwanda"),
        Language(name: "Kituba", code: "ktu", nativeName: "Kituba"),
        Language(name: "Konkani", code: "gom", nativeName: "कोंकणी"),
        Language(name: "Korean", code: "ko", nativeName: "한국어"),
        Language(name: "Krio", code: "kri", nativeName: "Krio"),
        Language(name: "Kurdish (Kurmanji)", code: "ku", nativeName: "Kurdî (Kurmancî)"),
        Language(name: "Kurdish (Sorani)", code: "ckb", nativeName: "کوردی (سۆرانی)"),
        Language(name: "Kyrgyz", code: "ky", nativeName: "кыргызча"),
        Language(name: "Lao", code: "lo", nativeName: "ລາວ"),
        Language(name: "Latgalian", code: "ltg", nativeName: "latgalīšu"),
        Language(name: "Latin", code: "la", nativeName: "Latina"),
        Language(name: "Latvian", code: "lv", nativeName: "latviešu"),
        Language(name: "Ligurian", code: "lij", nativeName: "Ligure"),
        Language(name: "Limburgish", code: "li", nativeName: "Limburgs"),
        Language(name: "Lingala", code: "ln", nativeName: "lingála"),
        Language(name: "Lithuanian", code: "lt", nativeName: "lietuvių"),
        Language(name: "Lombard", code: "lmo", nativeName: "Lombard"),
        Language(name: "Luo", code: "luo", nativeName: "Dholuo"),
        Language(name: "Luxembourgish", code: "lb", nativeName: "Lëtzebuergesch"),
        Language(name: "Macedonian", code: "mk", nativeName: "македонски"),
        Language(name: "Maithili", code: "mai", nativeName: "मैथिली"),
        Language(name: "Makassar", code: "mak", nativeName: "Basa Mangkasara"),
        Language(name: "Malagasy", code: "mg", nativeName: "Malagasy"),
        Language(name: "Malay", code: "ms", nativeName: "Bahasa Melayu"),
        Language(name: "Malay (Jawi)", code: "ms-Arab", nativeName: "بهاس ملايو"),
        Language(name: "Malayalam", code: "ml", nativeName: "മലയാളം"),
        Language(name: "Maltese", code: "mt", nativeName: "Malti"),
        Language(name: "Maori", code: "mi", nativeName: "Māori"),
        Language(name: "Marathi", code: "mr", nativeName: "मराठी"),
        Language(name: "Meadow Mari", code: "chm", nativeName: "олык марий"),
        Language(name: "Meiteilon (Manipuri)", code: "mni-Mtei", nativeName: "ꯃꯤꯇꯩꯂꯣꯟ"),
        Language(name: "Minang", code: "min", nativeName: "Baso Minang"),
        Language(name: "Mizo", code: "lus", nativeName: "Mizo ṭawng"),
        Language(name: "Mongolian", code: "mn", nativeName: "монгол"),
        Language(name: "Myanmar (Burmese)", code: "my", nativeName: "မြန်မာ"),
        Language(name: "Ndebele (South)", code: "nr", nativeName: "isiNdebele"),
        Language(name: "Nepal Bhasa (Newari)", code: "new", nativeName: "नेपाल भाषा"),
        Language(name: "Nepali", code: "ne", nativeName: "नेपाली"),
        Language(name: "Northern Sotho", code: "nso", nativeName: "Sesotho sa Leboa"),
        Language(name: "Norwegian", code: "no", nativeName: "norsk"),
        Language(name: "Nuer", code: "nus", nativeName: "Thok Naath"),
        Language(name: "Occitan", code: "oc", nativeName: "occitan"),
        Language(name: "Odia", code: "or", nativeName: "ଓଡ଼ିଆ"),
        Language(name: "Oromo", code: "om", nativeName: "Oromoo"),
        Language(name: "Pangasinan", code: "pag", nativeName: "Pangasinan"),
        Language(name: "Papiamento", code: "pap", nativeName: "Papiamento"),
        Language(name: "Pashto", code: "ps", nativeName: "پښتو"),
        Language(name: "Persian", code: "fa", nativeName: "فارسی"),
        Language(name: "Polish", code: "pl", nativeName: "polski"),
        Language(name: "Portuguese (Brazil)", code: "pt-BR", nativeName: "português (Brasil)"),
        Language(name: "Portuguese (Portugal)", code: "pt-PT", nativeName: "português (Portugal)"),
        Language(name: "Punjabi", code: "pa", nativeName: "ਪੰਜਾਬੀ"),
        Language(name: "Punjabi (Shahmukhi)", code: "pa-Arab", nativeName: "پنجابی"),
        Language(name: "Quechua", code: "qu", nativeName: "Runasimi"),
        Language(name: "Romani", code: "rom", nativeName: "romani ćhib"),
        Language(name: "Romanian", code: "ro", nativeName: "română"),
        Language(name: "Rundi", code: "rn", nativeName: "Ikirundi"),
        Language(name: "Russian", code: "ru", nativeName: "русский"),
        Language(name: "Samoan", code: "sm", nativeName: "Gagana Sāmoa"),
        Language(name: "Sango", code: "sg", nativeName: "Sängö"),
        Language(name: "Sanskrit", code: "sa", nativeName: "संस्कृतम्"),
        Language(name: "Scots Gaelic", code: "gd", nativeName: "Gàidhlig"),
        Language(name: "Serbian", code: "sr", nativeName: "српски"),
        Language(name: "Sesotho", code: "st", nativeName: "Sesotho"),
        Language(name: "Seychellois Creole", code: "crs", nativeName: "Kreol Seselwa"),
        Language(name: "Shan", code: "shn", nativeName: "လိၵ်ႈတႆး"),
        Language(name: "Shona", code: "sn", nativeName: "chiShona"),
        Language(name: "Sicilian", code: "scn", nativeName: "sicilianu"),
        Language(name: "Silesian", code: "szl", nativeName: "ślōnski"),
        Language(name: "Sindhi", code: "sd", nativeName: "سنڌي"),
        Language(name: "Sinhala", code: "si", nativeName: "සිංහල"),
        Language(name: "Slovak", code: "sk", nativeName: "slovenčina"),
        Language(name: "Slovenian", code: "sl", nativeName: "slovenščina"),
        Language(name: "Somali", code: "so", nativeName: "Soomaali"),
        Language(name: "Spanish", code: "es", nativeName: "español"),
        Language(name: "Sundanese", code: "su", nativeName: "Basa Sunda"),
        Language(name: "Swahili", code: "sw", nativeName: "Kiswahili"),
        Language(name: "Swati", code: "ss", nativeName: "siSwati"),
        Language(name: "Swedish", code: "sv", nativeName: "svenska"),
        Language(name: "Tajik", code: "tg", nativeName: "тоҷикӣ"),
        Language(name: "Tamil", code: "ta", nativeName: "தமிழ்"),
        Language(name: "Tatar", code: "tt", nativeName: "татар"),
        Language(name: "Telugu", code: "te", nativeName: "తెలుగు"),
        Language(name: "Tetum", code: "tet", nativeName: "Tetun"),
        Language(name: "Thai", code: "th", nativeName: "ไทย"),
        Language(name: "Tigrinya", code: "ti", nativeName: "ትግርኛ"),
        Language(name: "Tsonga", code: "ts", nativeName: "Xitsonga"),
        Language(name: "Tswana", code: "tn", nativeName: "Setswana"),
        Language(name: "Turkish", code: "tr", nativeName: "Türkçe"),
        Language(name: "Turkmen", code: "tk", nativeName: "türkmen dili"),
        Language(name: "Twi (Akan)", code: "ak", nativeName: "Akan"),
        Language(name: "Ukrainian", code: "uk", nativeName: "українська"),
        Language(name: "Urdu", code: "ur", nativeName: "اردو"),
        Language(name: "Uyghur", code: "ug", nativeName: "ئۇيغۇرچە"),
        Language(name: "Uzbek", code: "uz", nativeName: "o‘zbek"),
        Language(name: "Vietnamese", code: "vi", nativeName: "Tiếng Việt"),
        Language(name: "Welsh", code: "cy", nativeName: "Cymraeg"),
        Language(name: "Xhosa", code: "xh", nativeName: "IsiXhosa"),
        Language(name: "Yiddish", code: "yi", nativeName: "ייִדיש"),
        Language(name: "Yoruba", code: "yo", nativeName: "Èdè Yorùbá"),
        Language(name: "Yucatec Maya", code: "yua", nativeName: "Maaya t'aan"),
        Language(name: "Zulu", code: "zu", nativeName: "isiZulu"),
    ].sorted { $0.name.lowercased() < $1.name.lowercased() }

    private static let byCode: [String: Language] = Dictionary(
        all.map { ($0.code.lowercased(), $0) }, uniquingKeysWith: { first, _ in first }
    )

    /** Older or alternative codes for the same language (Google accepts both). */
    private static let aliases: [String: String] = [
        "zh": "zh-CN",
        "zh-hans": "zh-CN",
        "zh-hant": "zh-TW",
        "iw": "he",
        "jw": "jv",
        "fil": "tl",
        "pt": "pt-BR",
        "fr-fr": "fr",
        "mni": "mni-Mtei",
    ]

    /** The original five, kept one tap away for everyone who used the app before. */
    static let defaultFavorites: [String] = ["en", "si", "ta", "hi", "mr"]

    /**
     * Languages the `translate` function romanizes with Azure Translator (must match
     * AZURE_SCRIPTS in the functions repo's romanize.ts).
     */
    static let serverRomanized: Set<String> = [
        "ar", "as", "be", "bg", "bn", "el", "fa", "gom", "gu", "he", "hi", "ja",
        "kk", "kn", "ko", "ky", "mai", "mk", "ml", "mn", "mni-Mtei", "mr", "ne", "or",
        "pa", "ru", "sa", "sd", "si", "sr", "ta", "te", "tg", "th", "tt", "uk",
        "ur", "zh-CN", "zh-TW",
    ]

    /**
     * Non-Latin languages the built-in ICU transliterator romanizes acceptably. Used when the
     * server has no romanization. Same list as Android (iOS uses the same ICU transforms).
     */
    static let deviceRomanized: Set<String> = [
        "am", "as", "awa", "be", "bg", "bho", "bn", "bua", "chm", "cv", "doi", "dv",
        "el", "gom", "gu", "hi", "hy", "ka", "kn", "ko", "ky", "mai", "mk", "ml",
        "mn", "mr", "my", "ne", "new", "or", "pa", "ru", "sa", "si", "sr", "ta",
        "te", "ti", "tt", "uk", "zh-CN", "zh-TW",
    ]

    /** Whether translations into `code` come with a romanization (the "Aa" badge). */
    static func hasRomanization(_ code: String) -> Bool {
        serverRomanized.contains(code) || deviceRomanized.contains(code)
    }

    static var english: Language { byCode["en"]! }
    static var sinhala: Language { byCode["si"]! }

    static func find(_ code: String?) -> Language? {
        guard let key = code?.trimmed.lowercased(), !key.isEmpty else { return nil }
        if let language = byCode[key] { return language }
        if let alias = aliases[key] { return byCode[alias.lowercased()] }
        return nil
    }

    /** "si" → "Sinhala". Unknown codes fall back to what iOS knows, then the code itself. */
    static func displayName(_ code: String) -> String {
        if let language = find(code) { return language.name }
        let trimmed = code.trimmed
        let name = Locale(identifier: "en").localizedString(forIdentifier: trimmed) ?? ""
        return (name.isBlank || name.equalsIgnoreCase(trimmed)) ? trimmed.uppercased() : name
    }

    /**
     * Languages matching a search, best first: name or native name starting with the query,
     * then a word in the name starting with it, then the exact code, then (for 3+ letters)
     * anywhere in the name.
     */
    static func search(_ query: String, in languages: [Language] = all) -> [Language] {
        let q = query.trimmed.lowercased()
        if q.isEmpty { return languages }
        func rank(_ language: Language) -> Int? {
            let name = language.name.lowercased()
            let native = language.nativeName.lowercased()
            if name.hasPrefix(q) || native.hasPrefix(q) { return 0 }
            let words = name.split(whereSeparator: { " ()-".contains($0) })
            if words.contains(where: { $0.hasPrefix(q) }) { return 1 }
            if language.code.lowercased() == q { return 2 }
            if q.count >= 3 && (name.contains(q) || native.contains(q)) { return 3 }
            return nil
        }
        // Stable sort by rank, keeping A–Z order within a rank (like Kotlin's sortedBy).
        return languages.enumerated()
            .compactMap { index, language in rank(language).map { (index, language, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 < $1.2 : $0.0 < $1.0 }
            .map { $0.1 }
    }
}
