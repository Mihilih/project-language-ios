import SwiftUI

/** Below this height the done screen uses a smaller score circle and tighter spacing. */
private let compactHeight: CGFloat = 700

/** A flashcard session over a set of phrases (StudySessionScreen.kt). Full screen, no tab bar. */
struct StudySessionScreen: View {
    let route: StudyRoute
    let onClose: () -> Void

    @StateObject private var viewModel = LibraryViewModel()

    // A session runs over a deck of phrase ids: the chosen set at first, then the same deck
    // again (Restart) or just the missed cards (Review missed).
    @State private var deckIds: [String]?
    @State private var round = 0
    @State private var index = 0
    @State private var showAnswer = false
    @State private var gotCount = 0
    @State private var missedIds: [String] = []
    @State private var startTime = Date()
    @State private var loggedRound = -1

    private func phrases(_ uiState: LibraryUiState) -> [Phrase] {
        let now = Phrase.nowMillis()
        let weekCutoff = now - 7 * 24 * 60 * 60 * 1000
        let monthCutoff = now - 30 * 24 * 60 * 60 * 1000
        switch route.filter {
        case "favorites": return uiState.allPhrases.filter(\.isFavorite)
        case "this_week": return uiState.allPhrases.filter { $0.timestamp >= weekCutoff }
        case "this_month": return uiState.allPhrases.filter { $0.timestamp >= monthCutoff }
        case "language":
            return uiState.allPhrases.filter { $0.sourceLang.equalsIgnoreCase(route.lang) || $0.targetLang.equalsIgnoreCase(route.lang) }
        case StudySelection.filter:
            // Same phrases, in the same order, as the Library list the user started from.
            let byId = Dictionary(uiState.allPhrases.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let picked = StudySelection.phraseIds.compactMap { byId[$0] }
            return picked.isEmpty ? uiState.allPhrases : picked
        default: return uiState.allPhrases
        }
    }

    var body: some View {
        let uiState = viewModel.uiState
        ZStack {
            if uiState.isLoading {
                // Don't flash "No cards available" while the library is still loading.
                LoadingState(text: "Loading cards…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColor.backgroundSecondary.ignoresSafeArea())
            } else {
                let byId = Dictionary(uiState.allPhrases.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let deck = deckIds?.compactMap { byId[$0] } ?? phrases(uiState)
                if deck.isEmpty {
                    emptyView
                } else if index >= deck.count {
                    doneView(deck: deck)
                } else {
                    cardView(deck: deck)
                }
            }
        }
        // Freeze the first round's cards once the library has loaded, so a sync mid-session
        // (a phrase added or deleted elsewhere) can't shift which card is shown or skip one.
        .onChange(of: uiState.isLoading, initial: true) { _, loading in
            if !loading && deckIds == nil { deckIds = phrases(viewModel.uiState).map(\.id) }
        }
        // Audio stops when the session goes away (SpeechViewModel.onCleared on Android).
        .onDisappear { SpeechRepository.shared.stop() }
    }

    private func begin(_ ids: [String]) {
        deckIds = ids
        round += 1
        index = 0
        showAnswer = false
        gotCount = 0
        missedIds = []
        startTime = Date()
    }

    private var emptyView: some View {
        VStack(spacing: 0) {
            Kato(pose: .sleep, width: 104, outline: true)
            Spacer().frame(height: 8)
            Text("No cards available for this session")
                .font(AppFont.poppins(20))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 16)
            Button(action: onClose) {
                Text("Back")
                    .font(AppFont.dmSans(14, .bold))
                    .foregroundStyle(AppColor.textInverse)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(Capsule().fill(AppColor.primary))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.backgroundSecondary.ignoresSafeArea())
    }

    private func doneView(deck: [Phrase]) -> some View {
        let elapsedSec = Int(Date().timeIntervalSince(startTime))
        let score = (gotCount * 100) / deck.count
        let toReview = missedIds.count
        return GeometryReader { proxy in
            let compact = proxy.size.height < compactHeight
            // Scrolls on short phones (or with large text) so the buttons are always reachable;
            // on taller ones the spacer still pins them to the bottom.
            ScrollView {
                VStack(spacing: compact ? 14 : 22) {
                    ZStack(alignment: .bottomTrailing) {
                        VStack(spacing: 0) {
                            Text("\(score)%")
                                .font(AppFont.poppins(compact ? 44 : 58))
                                .tracking(compact ? -0.88 : -1.16)
                                .foregroundStyle(AppColor.textPrimary)
                            Text("SCORE").overlineStyle(size: 13, color: AppColor.textPrimary)
                        }
                        .frame(width: compact ? 132 : 176, height: compact ? 132 : 176)
                        .background(Circle().fill(AppColor.tertiary))
                        // Kato celebrating beside the score, as in the design.
                        Kato(pose: .celebrate, width: 96, outline: false)
                            .offset(x: 80, y: 14)
                    }
                    VStack(spacing: 6) {
                        Text("Session complete")
                            .font(AppFont.poppins(compact ? 30 : 36))
                            .tracking(compact ? -0.6 : -0.72)
                            .foregroundStyle(AppColor.textInverse)
                            .multilineTextAlignment(.center)
                        Text("You got \(gotCount) of \(deck.count) right.")
                            .font(AppFont.dmSans(17))
                            .foregroundStyle(AppColor.textOnDarkMuted)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            DoneStatTile(value: "\(elapsedSec)s", label: "Time spent")
                            DoneStatTile(value: "\(deck.count)", label: "Cards studied")
                        }
                        HStack(spacing: 10) {
                            DoneStatTile(value: "\(gotCount)", label: "Got right")
                            DoneStatTile(value: "\(toReview)", label: "To review")
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        PrimaryPillButton(
                            text: "Done",
                            height: 56,
                            container: AppColor.tertiary,
                            content: AppColor.textPrimary,
                            action: onClose
                        )
                        HStack(spacing: 10) {
                            if toReview > 0 {
                                DoneOutlineButton(text: "Review missed (\(toReview))") { begin(missedIds) }
                            }
                            DoneOutlineButton(text: "Restart session") { begin(deck.map(\.id)) }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, compact ? 20 : 48)
                .padding(.bottom, 24)
                .frame(minHeight: proxy.size.height)
            }
        }
        .background(AppColor.doneBackground.ignoresSafeArea())
        // Record each finished session once so the profile streak / activity chart update.
        .onAppear {
            if loggedRound != round {
                loggedRound = round
                StudyActivityRepository.logStudied(cards: deck.count)
            }
        }
    }

    private func cardView(deck: [Phrase]) -> some View {
        let current = deck[index]
        let sourceLabel = formatLanguageName(current.sourceLang)
        let targetLabel = formatLanguageName(current.targetLang)
        let position = index + 1

        func rate(_ got: Bool) {
            if got { gotCount += 1 } else { missedIds.append(current.id) }
            index += 1
            showAnswer = false
        }

        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppColor.backgroundPrimary))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("End session")

                GeometryReader { bar in
                    let progress = CGFloat(showAnswer ? position : index) / CGFloat(deck.count)
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColor.trackGray)
                        Capsule().fill(AppColor.primary).frame(width: bar.size.width * progress)
                    }
                }
                .frame(height: 8)
                .animation(.easeOut(duration: 0.25), value: showAnswer)
                .animation(.easeOut(duration: 0.25), value: index)
                .accessibilityElement()
                .accessibilityLabel("Progress")
                .accessibilityValue("\(showAnswer ? position : index) of \(deck.count)")

                Text("\(position) / \(deck.count)")
                    .font(AppFont.dmSans(15, .bold))
                    .foregroundStyle(AppColor.textPrimary)
            }

            // The card takes whatever height is left after the buttons. Its content scrolls when
            // the phrase and answer don't fit, and stays centred when they do.
            GeometryReader { cardProxy in
                let compactCard = cardProxy.size.height < 360
                ScrollView {
                    VStack(spacing: compactCard ? 10 : 14) {
                        CardLabel(text: sourceLabel.uppercased(), background: AppColor.backgroundSecondary, color: AppColor.textBody)
                        Text(current.original)
                            .font(AppFont.poppins(compactCard ? 28 : 36))
                            .tracking(compactCard ? -0.28 : -0.36)
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        if showAnswer {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(AppColor.neutral200)
                                .frame(width: 64, height: 2)
                                .padding(.vertical, compactCard ? 4 : 10)
                            CardLabel(text: targetLabel.uppercased(), background: AppColor.primarySoft, color: AppColor.primaryDark)
                            Text(current.translated)
                                .font(AppFont.poppins(compactCard ? 26 : 32))
                                .foregroundStyle(AppColor.primaryDark)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                            if current.romanized.isNotBlank {
                                Text(current.romanized)
                                    .font(AppFont.dmSans(15))
                                    .foregroundStyle(AppColor.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            SpeakButton(text: current.translated, language: current.targetLang, tint: AppColor.primaryDark)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, compactCard ? 18 : 28)
                    .frame(maxWidth: .infinity, minHeight: cardProxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppColor.backgroundPrimary)
                    .shadow(color: AppColor.secondary.opacity(0.18), radius: 16, y: 8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .onTapGesture { if !showAnswer { showAnswer = true } }
            .accessibilityAction(named: "Reveal translation") { if !showAnswer { showAnswer = true } }

            if !showAnswer {
                // The design reveals first, then asks how it went.
                PrimaryPillButton(
                    text: "Reveal translation",
                    height: 60,
                    fontSize: 17,
                    container: AppColor.secondary,
                    content: AppColor.textInverse
                ) { showAnswer = true }
            } else {
                VStack(spacing: 10) {
                    Text("How did you do?")
                        .font(AppFont.dmSans(14, .semibold))
                        .foregroundStyle(AppColor.textBody)
                        .frame(maxWidth: .infinity)
                    // Same height for all three, even if one label wraps.
                    HStack(spacing: 8) {
                        StudyActionButton(
                            text: "Didn't get it", icon: "xmark",
                            container: AppColor.backgroundPrimary, content: AppColor.textPrimary,
                            border: AppColor.neutral400
                        ) { rate(false) }
                        StudyActionButton(
                            text: "Unsure", icon: "questionmark.circle",
                            container: AppColor.tertiary, content: AppColor.textPrimary
                        ) { rate(false) }
                        StudyActionButton(
                            text: "Got it", icon: "checkmark",
                            container: AppColor.primary, content: AppColor.textInverse
                        ) { rate(true) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(AppColor.primarySoft.ignoresSafeArea())
    }
}

private struct DoneOutlineButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(AppFont.dmSans(15, .bold))
                .foregroundStyle(AppColor.textInverse)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                // Grows instead of clipping when the label doesn't fit.
                .frame(maxWidth: .infinity, minHeight: 52, maxHeight: .infinity)
                .overlay(Capsule().strokeBorder(AppColor.textInverse.opacity(0.35), lineWidth: 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

private struct StudyActionButton: View {
    let text: String
    let icon: String
    let container: Color
    let content: Color
    var border: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(text)
                    .font(AppFont.dmSans(14, .bold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(content)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 72, maxHeight: .infinity)
            .roundedBackground(container, 20)
            .overlay {
                if let border { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(border, lineWidth: 1.5) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

private struct CardLabel: View {
    let text: String
    let background: Color
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFont.dmSans(11, .bold))
            .tracking(1.1)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .roundedBackground(background, 6)
    }
}

private struct DoneStatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppFont.poppins(28))
                .foregroundStyle(AppColor.textInverse)
                .lineLimit(1)
            Text(label)
                .font(AppFont.dmSans(14))
                .foregroundStyle(AppColor.textOnDarkMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedBackground(AppColor.textInverse.opacity(0.08), 18)
    }
}

private func formatLanguageName(_ raw: String) -> String {
    raw.isBlank ? "English" : Languages.displayName(raw)
}
