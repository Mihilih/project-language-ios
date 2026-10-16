import SwiftUI

/** The FROM / TO chip on the Translate screen. Tapping it opens LanguagePickerSheet. */
struct LanguagePickerButton: View {
    let selectedLanguage: Language
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    if !label.isEmpty {
                        Text(label).overlineStyle(size: 10)
                    }
                    Text(selectedLanguage.name)
                        .font(AppFont.dmSans(16, .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .roundedBackground(AppColor.backgroundSecondary, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Change language")
    }
}

/** Extras a language comes with, shown as small badges in the picker. */
enum LanguageFeature: CaseIterable {
    case audio, romanization

    var description: String {
        switch self {
        case .audio: return "Listen to translations"
        case .romanization: return "Pronunciation in English letters"
        }
    }

    /** `audioLanguages` comes from the server's voice list (SpeechRepository.supported). */
    func supports(_ code: String, audioLanguages: Set<String>) -> Bool {
        switch self {
        case .audio: return audioLanguages.contains(code)
        case .romanization: return Languages.hasRomanization(code)
        }
    }
}

/**
 * Full-height sheet for choosing a language out of ~190: a search box, then Favorites, Recent,
 * and every language A–Z. Search matches the English name, the native name (so "සිංහල" finds
 * Sinhala) or the code ("si"). The star on each row adds or removes a favorite without closing
 * the sheet (LanguagePicker.kt).
 */
struct LanguagePickerSheet: View {
    let title: String
    let selected: Language
    let favorites: [String]
    let recents: [String]
    var languages: [Language] = Languages.all
    let onSelect: (Language) -> Void
    let onToggleFavorite: (String) -> Void

    @ObservedObject private var speech = SpeechRepository.shared
    @State private var query = ""

    private struct PickerSection: Identifiable {
        let title: String
        let languages: [Language]
        var id: String { title }
    }

    private var sections: [PickerSection] {
        if query.isNotBlank {
            return [PickerSection(title: "Results", languages: Languages.search(query, in: languages))]
        }
        let favoriteSet = Set(favorites)
        let favoriteLanguages = favorites.compactMap { Languages.find($0) }
        // Recent languages that are already starred show only under Favorites.
        let recentLanguages = recents.filter { !favoriteSet.contains($0) }.compactMap { Languages.find($0) }
        var result: [PickerSection] = []
        if !favoriteLanguages.isEmpty { result.append(PickerSection(title: "Favorites", languages: favoriteLanguages)) }
        if !recentLanguages.isEmpty { result.append(PickerSection(title: "Recent", languages: recentLanguages)) }
        result.append(PickerSection(title: "All languages", languages: languages))
        return result
    }

    var body: some View {
        let favoriteSet = Set(favorites)
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.poppins(24))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            SearchBox(text: $query, placeholder: "Search languages")
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            FeatureLegend()
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        Color.clear.frame(height: 0).id("top")
                        ForEach(sections) { section in
                            Text(section.title.uppercased())
                                .overlineStyle()
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                                .accessibilityAddTraits(.isHeader)
                            if section.languages.isEmpty {
                                Text("No languages match \"\(query.trimmed)\"")
                                    .font(AppFont.dmSans(15))
                                    .foregroundStyle(AppColor.textSecondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                            }
                            ForEach(section.languages) { language in
                                LanguageRow(
                                    language: language,
                                    selected: language.code == selected.code,
                                    favorite: favoriteSet.contains(language.code),
                                    features: LanguageFeature.allCases.filter { $0.supports(language.code, audioLanguages: speech.supported) },
                                    onClick: { onSelect(language) },
                                    onToggleFavorite: { onToggleFavorite(language.code) }
                                )
                                .id("\(section.title):\(language.code)")
                            }
                        }
                        Spacer().frame(height: 12)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: query) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
        }
        .onAppear { speech.refreshSupported() }
    }
}

/** Outlined search field with a magnifier and a clear button (picker and setup screens). */
struct SearchBox: View {
    @Binding var text: String
    let placeholder: String

    @FocusState var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 48)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppFont.dmSans(16))
                        .foregroundStyle(AppColor.textTertiary)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextField("", text: $text)
                    .font(AppFont.dmSans(16))
                    .foregroundStyle(AppColor.textPrimary)
                    .tint(AppColor.accent)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .accessibilityLabel(placeholder)
            }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Clear search")
            } else {
                Spacer().frame(width: 16)
            }
        }
        .frame(height: 56)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColor.backgroundPrimary))
        .roundedBorder(focused ? AppColor.accent : AppColor.outline, 14, width: focused ? 2 : 1)
    }
}

private struct LanguageRow: View {
    let language: Language
    let selected: Bool
    let favorite: Bool
    let features: [LanguageFeature]
    let onClick: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onClick) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(language.name)
                            .font(AppFont.dmSans(16, .bold))
                            .foregroundStyle(AppColor.textPrimary)
                        if !language.nativeName.equalsIgnoreCase(language.name) {
                            Text(language.nativeName)
                                .font(AppFont.dmSans(14))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(features, id: \.self) { FeatureBadge(feature: $0) }
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColor.accent)
                            .frame(width: 20, height: 20)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)

            Button(action: onToggleFavorite) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(favorite ? AppColor.accent : AppColor.textTertiary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(favorite ? "Remove \(language.name) from favorites" : "Add \(language.name) to favorites")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .background(selected ? AppColor.primarySoft : AppColor.backgroundPrimary)
    }
}

struct FeatureBadge: View {
    let feature: LanguageFeature

    var body: some View {
        Group {
            switch feature {
            case .audio:
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColor.textBody)
                    .frame(width: 14, height: 14)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
            case .romanization:
                Text("Aa")
                    .font(AppFont.dmSans(11, .bold))
                    .foregroundStyle(AppColor.textBody)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
        }
        .roundedBackground(AppColor.tertiary, 6)
        .accessibilityElement()
        .accessibilityLabel(feature.description)
    }
}

/** One line per badge explaining it, under the search box. */
private struct FeatureLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(LanguageFeature.allCases, id: \.self) { feature in
                HStack(spacing: 8) {
                    FeatureBadge(feature: feature)
                    Text(feature.description)
                        .font(AppFont.dmSans(13))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }
}
