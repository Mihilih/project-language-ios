import SwiftUI

private struct SuggestTarget: Identifiable {
    let id: String
}

/** The Library tab (LibraryScreen.kt). */
struct LibraryScreen: View {
    /** Start a study session over exactly these phrase ids (the list as currently shown). */
    let onStudy: ([String]) -> Void

    @StateObject private var viewModel = LibraryViewModel()
    @StateObject private var toast = ToastState()
    @StateObject private var snackbar = SnackbarState()

    // Phrase being suggested to friends (by id).
    @State private var suggestTarget: SuggestTarget?

    @State private var showFilterSheet = false
    @State private var selectedLanguagesDraft: Set<String> = []
    @State private var favoritesOnlyDraft = false
    @State private var dateAddedDraft: DateAddedFilter = .allTime

    @State private var showExport = false
    @State private var exportScope: ExportScope = .all
    @State private var exportBusy = false
    /** Shared once the export sheet has closed (iOS can't present over a closing sheet). */
    @State private var pendingShare: ExportResult?

    var body: some View {
        let uiState = viewModel.uiState
        let filtersActive = hasActiveFilters(uiState)
        let searching = uiState.searchQuery.isNotBlank
        let countLabel = (searching || filtersActive)
            ? "\(phraseCount(uiState.phrases.count)) of \(uiState.allPhrases.count)"
            : phraseCount(uiState.allPhrases.count)

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                AppHeader(text: "Library", subtitle: (uiState.isLoading || uiState.loadFailed) ? nil : countLabel) {
                    if !uiState.allPhrases.isEmpty {
                        Button { showExport = true } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(AppColor.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(AppColor.backgroundPrimary))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Export phrases")
                    }
                }

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        LibrarySearchField(
                            value: uiState.searchQuery,
                            onValueChange: viewModel.onSearchQueryChange
                        )
                        FilterButton(active: filtersActive, count: activeFilterCount(uiState)) {
                            selectedLanguagesDraft = uiState.selectedLanguages
                            favoritesOnlyDraft = uiState.favoritesOnly
                            dateAddedDraft = uiState.dateAddedFilter
                            showFilterSheet = true
                        }
                    }

                    // Active filters as removable chips, with "Clear all" (from the design).
                    if filtersActive {
                        ActiveFilterChips(uiState: uiState) { langs, favs, date in
                            viewModel.updateFilters(selectedLanguages: langs, favoritesOnly: favs, dateAddedFilter: date)
                        }
                    }

                    if uiState.isLoading {
                        LoadingState(text: "Loading your phrases…")
                        Spacer(minLength: 0)
                    } else if uiState.loadFailed {
                        ErrorState(
                            title: "Couldn't load your library",
                            message: "Check your connection and try again.",
                            onRetry: viewModel.retry
                        )
                        Spacer(minLength: 0)
                    } else if uiState.phrases.isEmpty {
                        VStack(spacing: 6) {
                            Kato(pose: .read, width: 92, outline: true)
                            Text(uiState.allPhrases.isEmpty ? "No phrases yet" : "No phrases match")
                                .font(AppFont.poppins(20))
                                .foregroundStyle(AppColor.textPrimary)
                            Text(uiState.allPhrases.isEmpty
                                 ? "No phrases saved yet. Start translating!"
                                 : "No phrases match your search or filters.")
                                .font(AppFont.dmSans(15))
                                .foregroundStyle(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 40)
                        Spacer(minLength: 0)
                    } else {
                        phraseList(uiState.phrases)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            if !uiState.isLoading && !uiState.phrases.isEmpty {
                PrimaryPillButton(
                    text: uiState.phrases.count == 1 ? "Study 1 Phrase" : "Study \(uiState.phrases.count) Phrases",
                    icon: "rectangle.on.rectangle.angled",
                    height: 56
                ) {
                    onStudy(uiState.phrases.map(\.id))
                }
                .shadow(color: AppColor.primary.opacity(0.35), radius: 10, y: 6)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // Errors (favorite failed, etc.) float above the Study button, like the Undo snackbar.
            AppToastHost(state: toast)
                .padding(.horizontal, 20)
                .padding(.bottom, 84)

            // Sits just above the floating Study button.
            SnackbarHost(state: snackbar)
                .padding(.horizontal, 12)
                .padding(.bottom, 80)
        }
        .background(AppColor.backgroundSecondary)
        .onChange(of: uiState.errorMessage) { _, message in
            if let message {
                toast.error(message)
                viewModel.clearError()
            }
        }
        .appSheet(item: $suggestTarget) { target in
            if let phrase = viewModel.uiState.allPhrases.first(where: { $0.id == target.id }) {
                SuggestToFriendSheet(phrase: phrase.toSnapshot()) { names in
                    suggestTarget = nil
                    toast.success(suggestedToText(names))
                }
            }
        }
        .appSheet(isPresented: $showFilterSheet) {
            LibraryFilterSheet(
                availableLanguages: viewModel.uiState.availableLanguages,
                selectedLanguages: $selectedLanguagesDraft,
                favoritesOnly: $favoritesOnlyDraft,
                dateAddedFilter: $dateAddedDraft,
                onApply: {
                    viewModel.updateFilters(
                        selectedLanguages: selectedLanguagesDraft,
                        favoritesOnly: favoritesOnlyDraft,
                        dateAddedFilter: dateAddedDraft
                    )
                    showFilterSheet = false
                }
            )
        }
        .appSheet(isPresented: $showExport, dismissDisabled: exportBusy, onDismiss: {
            if let share = pendingShare {
                pendingShare = nil
                ShareSheet.share(share)
            }
        }) {
            exportSheet
        }
    }

    private func phraseList(_ phrases: [Phrase]) -> some View {
        List {
            ForEach(phrases) { phrase in
                // Swipe left to delete; VoiceOver users get the same as an action.
                SwipeToDelete(onDelete: { deletePhrase(phrase) }) {
                    PhraseCard(
                        phrase: phrase,
                        onFavoriteToggle: viewModel.toggleFavorite,
                        onSuggest: { suggestTarget = SuggestTarget(id: phrase.id) }
                    )
                }
                .id(phrase.id)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityAction(named: "Delete \(phrase.original)") { deletePhrase(phrase) }
            }
            // Leave room for the floating study button.
            Color.clear
                .frame(height: 92)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollDismissesKeyboard(.interactively)
    }

    private func deletePhrase(_ phrase: Phrase) {
        viewModel.deletePhrase(phrase) { success in
            snackbar.dismiss()
            if success {
                snackbar.show("Phrase deleted", actionLabel: "Undo") { viewModel.undoDelete() }
            } else {
                snackbar.show("Couldn't delete phrase")
            }
        }
    }

    // Export sheet (Phase 6). "Current results" only appears while a search/filter is on.
    private var exportSheet: some View {
        let uiState = viewModel.uiState
        var options = [
            ExportOption(scope: .all, label: "All phrases", count: uiState.allPhrases.count),
            ExportOption(scope: .favorites, label: "Favorites only", count: uiState.allPhrases.filter(\.isFavorite).count),
        ]
        if uiState.searchQuery.isNotBlank || hasActiveFilters(uiState) {
            options.append(ExportOption(scope: .current, label: "Current results", count: uiState.phrases.count))
        }
        let scope = options.contains { $0.scope == exportScope } ? exportScope : .all
        let finish: (ExportResult?) -> Void = { result in
            exportBusy = false
            if let result {
                pendingShare = result
                showExport = false
            } else {
                toast.error("Couldn't export your phrases. Please try again.")
            }
        }
        return ExportPhrasesSheet(
            options: options,
            selected: scope,
            busy: exportBusy,
            onSelect: { exportScope = $0 },
            onExportPdf: {
                exportBusy = true
                viewModel.exportPdf(scope, onResult: finish)
            },
            onShareText: {
                exportBusy = true
                viewModel.exportText(scope, onResult: finish)
            }
        )
    }
}

private func hasActiveFilters(_ uiState: LibraryUiState) -> Bool {
    !uiState.selectedLanguages.isEmpty || uiState.favoritesOnly || uiState.dateAddedFilter != .allTime
}

private func activeFilterCount(_ uiState: LibraryUiState) -> Int {
    var count = 0
    if !uiState.selectedLanguages.isEmpty { count += 1 }
    if uiState.favoritesOnly { count += 1 }
    if uiState.dateAddedFilter != .allTime { count += 1 }
    return count
}

private func dateFilterLabel(_ filter: DateAddedFilter) -> String {
    switch filter {
    case .allTime: return "All time"
    case .thisWeek: return "This week"
    case .thisMonth: return "This month"
    }
}

private struct LibrarySearchField: View {
    let value: String
    let onValueChange: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 18, height: 18)
            ZStack(alignment: .leading) {
                if value.isEmpty {
                    Text("Search phrases")
                        .font(AppFont.dmSans(16))
                        .foregroundStyle(AppColor.textTertiary)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextField("", text: Binding(get: { value }, set: onValueChange))
                    .font(AppFont.dmSans(16, value.isNotBlank ? .semibold : .regular))
                    .foregroundStyle(AppColor.textPrimary)
                    .tint(AppColor.accent)
                    .submitLabel(.search)
                    .accessibilityLabel("Search phrases")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .roundedBackground(AppColor.backgroundPrimary, 16)
    }
}

private struct FilterButton: View {
    let active: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(active ? AppColor.textInverse : AppColor.textPrimary)
                .frame(width: 48, height: 48)
                .roundedBackground(active ? AppColor.secondary : AppColor.backgroundPrimary, 16)
        }
        .buttonStyle(PressableStyle())
        .overlay(alignment: .topTrailing) {
            if active {
                Text("\(count)")
                    .font(AppFont.dmSans(11, .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(AppColor.tertiary))
                    .overlay(Capsule().strokeBorder(AppColor.backgroundSecondary, lineWidth: 2))
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(active ? "Filter (\(count))" : "Filter")
    }
}

/** The Library's filter sheet: languages, favorites only, date added (LibraryFilterBottomSheet). */
private struct LibraryFilterSheet: View {
    let availableLanguages: [String]
    @Binding var selectedLanguages: Set<String>
    @Binding var favoritesOnly: Bool
    @Binding var dateAddedFilter: DateAddedFilter
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Filters")
                    .font(AppFont.poppins(24))
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                PlainTextButton(text: "Clear all", color: AppColor.accent, weight: .bold) {
                    selectedLanguages = []
                    favoritesOnly = false
                    dateAddedFilter = .allTime
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("LANGUAGE").overlineStyle(size: 12)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(availableLanguages, id: \.self) { code in
                        let selected = selectedLanguages.contains(code)
                        Button {
                            if selected { selectedLanguages.remove(code) } else { selectedLanguages.insert(code) }
                        } label: {
                            Text(Languages.displayName(code))
                                .font(AppFont.dmSans(15, .semibold))
                                .foregroundStyle(selected ? AppColor.textInverse : AppColor.textPrimary)
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .roundedBackground(selected ? AppColor.secondary : AppColor.backgroundPrimary, 20)
                                .roundedBorder(selected ? AppColor.secondary : AppColor.neutral300, 20)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    }
                }
            }

            // Whole row is one switch for VoiceOver ("Favorites only, switch, on").
            Toggle(isOn: $favoritesOnly) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorites only")
                        .font(AppFont.dmSans(16, .bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Show only favorites")
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .tint(AppColor.primary)

            VStack(alignment: .leading, spacing: 10) {
                Text("DATE ADDED").overlineStyle(size: 12)
                HStack(spacing: 4) {
                    ForEach(DateAddedFilter.allCases, id: \.self) { filter in
                        let selected = dateAddedFilter == filter
                        Button { dateAddedFilter = filter } label: {
                            Text(dateFilterLabel(filter))
                                .font(AppFont.dmSans(14, selected ? .bold : .medium))
                                .foregroundStyle(AppColor.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selected ? AppColor.backgroundPrimary : Color.clear)
                                        .shadow(color: .black.opacity(selected ? 0.12 : 0), radius: 2, y: 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(4)
                .roundedBackground(AppColor.backgroundSecondary, 14)
            }

            PrimaryPillButton(text: "Apply Filters", action: onApply)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }
}

private struct ActiveFilterChips: View {
    let uiState: LibraryUiState
    let onChange: (Set<String>, Bool, DateAddedFilter) -> Void

    var body: some View {
        let langs = uiState.selectedLanguages
        let favs = uiState.favoritesOnly
        let date = uiState.dateAddedFilter
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(langs.sorted(), id: \.self) { code in
                RemovableChip(label: Languages.displayName(code)) {
                    var next = langs
                    next.remove(code)
                    onChange(next, favs, date)
                }
            }
            if favs {
                RemovableChip(label: "Favorites") { onChange(langs, false, date) }
            }
            if date != .allTime {
                RemovableChip(label: date == .thisWeek ? "This week" : "This month") {
                    onChange(langs, favs, .allTime)
                }
            }
            Button { onChange([], false, .allTime) } label: {
                Text("Clear all")
                    .font(AppFont.dmSans(14, .bold))
                    .foregroundStyle(AppColor.accent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/** Ink pill with an x; tapping anywhere on it removes that filter. */
private struct RemovableChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Text(label).font(AppFont.dmSans(14, .semibold))
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(AppColor.textInverse)
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .background(Capsule().fill(AppColor.secondary))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Remove filter \(label)")
    }
}

/**
 * Swipe left to delete, drawn like Android's SwipeToDismissBox: a clay panel the full size of the
 * card, reading "Delete" with a bin, appears behind it. (iOS's own swipe actions show a small
 * button in the middle of the row instead.) Past 40% of the width, or a quick flick, deletes.
 */
struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    /** Locked on the first movement, so vertical scrolling never drags the card sideways. */
    @State private var horizontal: Bool? = nil
    @State private var deleting = false
    /** True while a finger is down; resets by itself even if scrolling cancels the drag. */
    @GestureState private var dragging = false

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Text("Delete")
                    .font(AppFont.dmSans(15, .bold))
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(AppColor.textInverse)
            .padding(.trailing, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppColor.primary))
            .opacity(offset < 0 ? 1 : 0)
            // Only seen mid-swipe; VoiceOver users get the "Delete …" action instead.
            .accessibilityHidden(true)

            content()
                .offset(x: offset)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            }
        )
        // A drag that ends without onEnded (the list took over to scroll) springs back.
        .onChange(of: dragging) { _, isDragging in
            guard !isDragging else { return }
            DispatchQueue.main.async {
                horizontal = nil
                if !deleting && offset != 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .updating($dragging) { _, state, _ in state = true }
                .onChanged { value in
                    if horizontal == nil {
                        horizontal = abs(value.translation.width) > abs(value.translation.height)
                    }
                    guard horizontal == true else { return }
                    offset = min(0, value.translation.width)
                }
                .onEnded { value in
                    defer { horizontal = nil }
                    guard horizontal == true, width > 0 else { return }
                    let farEnough = -value.translation.width > width * 0.4
                    let flicked = value.predictedEndTranslation.width < -width * 0.8
                    if farEnough || flicked {
                        deleting = true
                        withAnimation(.easeOut(duration: 0.18)) { offset = -width }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            onDelete()
                            // The phrase leaves the list on its own; reset in case Undo
                            // brings this card back.
                            offset = 0
                            deleting = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
                    }
                }
        )
    }
}
