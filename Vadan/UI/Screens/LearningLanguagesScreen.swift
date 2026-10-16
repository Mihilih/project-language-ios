import SwiftUI

/** Shown before a search, so most people can tap their language without typing. */
private let popular = ["si", "ta", "hi", "mr", "es", "fr", "ja", "ko", "zh-CN", "de", "it", "pt-BR", "ar", "ru"]
private let maxResults = 8

/**
 * "What are you learning?" — the last setup step for a new account, after the username. The
 * picked languages become the user's favorites (instead of the default five), and Translate
 * opens on them. Skipping keeps the defaults (LearningLanguagesScreen.kt).
 */
struct LearningLanguagesScreen: View {
    let onDone: () -> Void

    @StateObject private var viewModel = LearningLanguagesViewModel()
    @State private var selected: [String] = []
    @State private var query = ""

    private var options: [Language] {
        if query.isBlank { return popular.compactMap { Languages.find($0) } }
        return Array(Languages.search(query).filter { $0.code != "en" }.prefix(maxResults))
    }

    private func toggle(_ code: String) {
        if selected.contains(code) { selected.removeAll { $0 == code } } else { selected.append(code) }
    }

    var body: some View {
        AuthScaffold(
            title: "What are you learning?",
            subtitle: "Pick one or more. They'll sit at the top of your language list.",
            katoPose: .talk
        ) {
            if !selected.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(selected.compactMap { Languages.find($0) }) { language in
                        Button { toggle(language.code) } label: {
                            HStack(spacing: 6) {
                                Text(language.name).font(AppFont.dmSans(14, .semibold))
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(AppColor.textInverse)
                            .padding(.leading, 14)
                            .padding(.trailing, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(AppColor.secondary))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Remove \(language.name)")
                    }
                }
            }

            SearchBox(text: $query, placeholder: "Search 190+ languages")

            VStack(alignment: .leading, spacing: 8) {
                Text(query.isBlank ? "POPULAR" : "RESULTS").overlineStyle()
                if options.isEmpty {
                    Text("No languages match \"\(query.trimmed)\"")
                        .font(AppFont.dmSans(15))
                        .foregroundStyle(AppColor.textSecondary)
                }
                ForEach(options) { language in
                    LearningOption(language: language, selected: selected.contains(language.code)) {
                        toggle(language.code)
                    }
                }
            }

            VStack(spacing: 4) {
                AuthPrimaryButton(
                    text: {
                        switch selected.count {
                        case 0: return "Continue"
                        case 1: return "Continue with \(Languages.find(selected[0])?.name ?? "")"
                        default: return "Continue with \(selected.count) languages"
                        }
                    }(),
                    enabled: !selected.isEmpty
                ) {
                    viewModel.save(selected)
                    onDone()
                }
                PlainTextButton(text: "Skip for now", fullWidth: true, action: onDone)
            }
        }
    }
}

private struct LearningOption: View {
    let language: Language
    let selected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
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
                ZStack {
                    Circle().fill(selected ? AppColor.primary : AppColor.backgroundPrimary)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColor.textInverse)
                    } else {
                        Circle().strokeBorder(AppColor.neutral300, lineWidth: 1.5)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 56)
            .roundedBackground(selected ? AppColor.primarySoft : AppColor.backgroundPrimary, 14)
            .roundedBorder(selected ? AppColor.accent : AppColor.outline, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
