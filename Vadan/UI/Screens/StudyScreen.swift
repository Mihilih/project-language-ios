import SwiftUI

/** One choosable set on the Study tab, and the session route it starts. */
private struct StudySet: Identifiable, Equatable {
    let key: String
    let title: String
    let count: Int
    let filter: String
    var lang: String = ""
    var code: String? = nil
    var id: String { key }
}

/**
 * Study, as in the design: pick a set (radio list + language cards), then
 * "Start session · N cards". Empty sets are greyed out and can't be picked (StudyScreen.kt).
 */
struct StudyScreen: View {
    let onStartSession: (StudyRoute) -> Void

    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedKey = "all"

    var body: some View {
        let uiState = viewModel.uiState
        let now = Phrase.nowMillis()
        let weekCutoff = now - 7 * 24 * 60 * 60 * 1000
        let monthCutoff = now - 30 * 24 * 60 * 60 * 1000

        let collections = [
            StudySet(key: "all", title: "All phrases", count: uiState.allPhrases.count, filter: "all"),
            StudySet(key: "favorites", title: "Favorites", count: uiState.allPhrases.filter(\.isFavorite).count, filter: "favorites"),
            StudySet(key: "this_week", title: "Added this week", count: uiState.allPhrases.filter { $0.timestamp >= weekCutoff }.count, filter: "this_week"),
            StudySet(key: "this_month", title: "Added this month", count: uiState.allPhrases.filter { $0.timestamp >= monthCutoff }.count, filter: "this_month"),
        ]
        let languageSets = Self.languageSets(uiState)
        let all = collections + languageSets
        let selected = all.first { $0.key == selectedKey && $0.count > 0 }

        VStack(spacing: 0) {
            AppHeader(text: "Study", subtitle: "Pick a set to practise") {
                // Kato sitting by the title, as in the design.
                Kato(pose: .sit, width: 58, outline: true).offset(y: 6)
            }

            if uiState.isLoading {
                LoadingState(text: "Loading your phrases…")
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "COLLECTIONS")
                        ForEach(collections) { set in
                            StudyTile(
                                title: set.title,
                                subtitle: phraseCount(set.count),
                                selected: set.key == selected?.key,
                                enabled: set.count > 0
                            ) { selectedKey = set.key }
                        }

                        if !languageSets.isEmpty {
                            SectionLabel(text: "BY LANGUAGE").padding(.top, 8)
                            // Two language cards per row, as in the design, both the same height.
                            ForEach(Array(stride(from: 0, to: languageSets.count, by: 2)), id: \.self) { start in
                                HStack(alignment: .top, spacing: 8) {
                                    ForEach(languageSets[start..<min(start + 2, languageSets.count)]) { set in
                                        LanguageTile(
                                            code: set.code ?? "",
                                            title: set.title,
                                            subtitle: phraseCount(set.count),
                                            selected: set.key == selected?.key
                                        ) { selectedKey = set.key }
                                    }
                                    if start + 1 >= languageSets.count { Color.clear.frame(maxWidth: .infinity) }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                }

                PrimaryPillButton(
                    text: selected.map { "Start session · \(cardCountLabel($0.count))" } ?? "Save phrases to start studying",
                    trailingIcon: selected == nil ? nil : "arrow.right",
                    enabled: selected != nil,
                    height: 56,
                    disabledContainer: AppColor.trackGray,
                    disabledContent: AppColor.textSecondary
                ) {
                    if let selected { onStartSession(StudyRoute(filter: selected.filter, lang: selected.lang)) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .background(AppColor.backgroundSecondary)
        // If the picked set empties (or disappears), fall back to the first one with cards.
        .onChange(of: all.map { "\($0.key):\($0.count)" }, initial: true) { _, _ in
            if !all.contains(where: { $0.key == selectedKey && $0.count > 0 }),
               let first = all.first(where: { $0.count > 0 }) {
                selectedKey = first.key
            }
        }
    }

    /** Phrases per language, most first (counted in a single pass). */
    private static func languageSets(_ uiState: LibraryUiState) -> [StudySet] {
        var countsByLang: [String: Int] = [:]
        for phrase in uiState.allPhrases {
            for lang in Set([phrase.sourceLang.lowercased(), phrase.targetLang.lowercased()]) {
                countsByLang[lang, default: 0] += 1
            }
        }
        // Stable: equal counts keep the A–Z order of availableLanguages (like Kotlin's sortedBy).
        return uiState.availableLanguages.enumerated()
            .map { (index: $0.offset, code: $0.element, count: countsByLang[$0.element.lowercased()] ?? 0) }
            .filter { $0.count > 0 }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.index < $1.index }
            .map { item in
                StudySet(
                    key: "lang:\(item.code)",
                    title: Languages.displayName(item.code),
                    count: item.count,
                    filter: "language",
                    lang: item.code,
                    code: item.code.uppercased()
                )
            }
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View { Text(text).overlineStyle(size: 12).accessibilityAddTraits(.isHeader) }
}

/** Clay ring + check when picked, grey ring otherwise (the design's radio). */
struct RadioDot: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle().fill(selected ? AppColor.primary : Color.clear)
            Circle().strokeBorder(selected ? AppColor.accent : AppColor.outline, lineWidth: 2)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColor.textInverse)
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct StudyTile: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.dmSans(16, .bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(enabled ? subtitle : "Nothing yet")
                        .font(AppFont.dmSans(13))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RadioDot(selected: selected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .roundedBackground(AppColor.backgroundPrimary, 18)
            .overlay {
                if selected { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppColor.primary, lineWidth: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct LanguageTile: View {
    let code: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Grows with its text instead of a fixed height, so names never clip.
            VStack(alignment: .leading, spacing: 10) {
                Text(code)
                    .font(AppFont.dmSans(11, .bold))
                    .tracking(11 * 0.06)
                    .foregroundStyle(selected ? AppColor.textInverse : AppColor.textBody)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .roundedBackground(selected ? AppColor.primary : AppColor.backgroundSecondary, 6)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(AppFont.dmSans(16, .bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(subtitle)
                        .font(AppFont.dmSans(13))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88, maxHeight: .infinity, alignment: .topLeading)
            .roundedBackground(AppColor.backgroundPrimary, 18)
            .overlay {
                if selected { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppColor.primary, lineWidth: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

private func cardCountLabel(_ count: Int) -> String { count == 1 ? "1 card" : "\(count) cards" }
