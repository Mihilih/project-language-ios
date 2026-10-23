import SwiftUI
import FirebaseFirestore

/** Suggestion statuses that still belong in the inbox (saved / dismissed ones leave it). */
private let inboxStatuses: Set<String> = ["pending", "read", "replied"]

/** The Friends tab (FriendsScreen.kt). */
struct FriendsScreen: View {
    @StateObject private var viewModel = FriendsViewModel()
    @StateObject private var toast = ToastState()
    @StateObject private var usernameResolver = UsernameResolver()
    @ObservedObject private var notificationRouter = NotificationRouter.shared
    @EnvironmentObject var dialogs: DialogHost

    @State private var showAddFriendSheet = false
    @State private var friendNote = ""

    // Friends tab
    @State private var friendQuery = ""
    @State private var openFriendUid: String?

    // Suggestions tab
    @State private var unreadOnly = false
    @State private var openSuggestionId: String?
    @State private var savedFromName: String?

    var body: some View {
        let uiState = viewModel.uiState
        let currentUid = AuthManager.getCurrentUserId()

        // One username lookup shared by friend cards, suggestion senders and friend requests.
        let friendUids = uiState.friendships.compactMap { $0.otherUid(currentUid) }
        let senderUids = uiState.suggestions.map(\.fromUid) + uiState.incomingRequests.map(\.fromUid)
        let knownNames = Self.knownNames(uiState.friendships)
        let usernames = usernameResolver.names(for: (friendUids + senderUids).uniqued(), known: knownNames)
        let nameFor: (String) -> String = { uid in usernames[uid] ?? "Friend \(shortId(uid))" }

        let openSuggestion = openSuggestionId.flatMap { id in uiState.suggestions.first { $0.id == id } }
        let showingDetail = uiState.activeTab == .suggestions && openSuggestion != nil
        // Only while still friends: if the friendship goes away (removed here or by them), the
        // profile closes on its own.
        let openFriendship = openFriendUid.flatMap { uid in
            uiState.friendships.first { $0.otherUid(currentUid) == uid }
        }
        let showingFriend = uiState.activeTab == .friends && openFriendship != nil

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if showingFriend, let friendship = openFriendship, let friendUid = openFriendUid {
                    let friendName = nameFor(friendUid)
                    FriendProfileView(
                        friendUid: friendUid,
                        friendName: friendName,
                        friendship: friendship,
                        received: uiState.suggestions.filter { $0.fromUid == friendUid },
                        busySuggestionIds: uiState.pendingSuggestionIds,
                        removing: uiState.removingFriendUids.contains(friendUid),
                        onBack: { openFriendUid = nil },
                        onSave: { saveSuggestion($0, nameFor) },
                        onRemove: { confirmRemove(friendUid: friendUid, name: friendName) }
                    )
                    .id(friendUid)
                } else if showingDetail, let suggestion = openSuggestion {
                    SuggestionDetail(
                        suggestion: suggestion,
                        senderName: nameFor(suggestion.fromUid),
                        busy: uiState.pendingSuggestionIds.contains(suggestion.id),
                        onBack: { openSuggestionId = nil },
                        onSave: { saveSuggestion(suggestion, nameFor) },
                        onDismiss: { dismissSuggestion(suggestion) }
                    )
                } else {
                    FriendsHeader { showAddFriendSheet = true }
                    Spacer().frame(height: 14)
                    FriendsTabs(uiState: uiState, onTabSelected: viewModel.setActiveTab)
                    Spacer().frame(height: 14)

                    switch uiState.activeTab {
                    case .friends:
                        FriendsListTab(
                            friendships: uiState.friendships,
                            currentUid: currentUid,
                            query: $friendQuery,
                            nameFor: nameFor,
                            onFindFriends: { showAddFriendSheet = true },
                            onOpenFriend: { openFriendUid = $0 },
                            loaded: uiState.friendsLoaded
                        )
                    case .suggestions:
                        if !uiState.suggestionsLoaded {
                            LoadingState()
                            Spacer(minLength: 0)
                        } else {
                            SuggestionsTab(
                                suggestions: uiState.suggestions,
                                unreadOnly: $unreadOnly,
                                savedFromName: savedFromName,
                                busyIds: uiState.pendingSuggestionIds,
                                nameFor: nameFor,
                                onOpen: { suggestion in
                                    if suggestion.status.equalsIgnoreCase("pending") {
                                        viewModel.updateSuggestionStatus(suggestion.id, status: "read")
                                    }
                                    openSuggestionId = suggestion.id
                                },
                                onSave: { saveSuggestion($0, nameFor) },
                                onDismiss: dismissSuggestion
                            )
                        }
                    case .requests:
                        if !uiState.requestsLoaded {
                            LoadingState()
                            Spacer(minLength: 0)
                        } else {
                            RequestsTab(
                                uiState: uiState,
                                nameFor: nameFor,
                                onAcceptRequest: { viewModel.respondToRequest($0, accept: true) },
                                onDeclineRequest: { viewModel.respondToRequest($0, accept: false) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Errors from actions on the main screen (the Add Friend sheet shows its own inline).
            AppToastHost(state: toast)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(AppColor.backgroundSecondary)
        .onChange(of: uiState.errorMessage, initial: false) { _, _ in showErrorIfNeeded() }
        .onChange(of: showAddFriendSheet) { _, _ in showErrorIfNeeded() }
        // Opened from a notification: jump to its section (and suggestion, if any), then clear it.
        .onChange(of: notificationRouter.pending, initial: true) { _, target in
            guard let target else { return }
            viewModel.setActiveTab(target.tab)
            openSuggestionId = target.suggestionId
            notificationRouter.consume()
        }
        .task(id: savedFromName) {
            if savedFromName != nil {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if !Task.isCancelled { savedFromName = nil }
            }
        }
        .appSheet(isPresented: $showAddFriendSheet, onDismiss: { viewModel.clearError() }) {
            AddFriendSheet(
                viewModel: viewModel,
                currentUid: currentUid,
                onSendFriendRequest: { uid in
                    viewModel.sendFriendRequest(toUid: uid, note: friendNote) { success, _ in
                        if success {
                            showAddFriendSheet = false
                            friendNote = ""
                            toast.success("Friend request sent")
                        }
                    }
                }
            )
        }
    }

    private func showErrorIfNeeded() {
        if let error = viewModel.uiState.errorMessage, !showAddFriendSheet {
            toast.error(error)
            viewModel.clearError()
        }
    }

    private static func knownNames(_ friendships: [Friendship]) -> [String: String] {
        var names: [String: String] = [:]
        for profile in friendships.flatMap({ Array($0.userProfiles.values) }) where profile.username.isNotBlank {
            names[profile.uid] = profile.username.trimmed
        }
        return names
    }

    private func saveSuggestion(_ suggestion: Suggestion, _ nameFor: (String) -> String) {
        let sender = nameFor(suggestion.fromUid)
        viewModel.saveSuggestionToLibrary(suggestion) { success, _ in
            if success { savedFromName = sender }
        }
        openSuggestionId = nil
    }

    private func dismissSuggestion(_ suggestion: Suggestion) {
        viewModel.updateSuggestionStatus(suggestion.id, status: "dismissed")
        openSuggestionId = nil
    }

    private func confirmRemove(friendUid: String, name: String) {
        dialogs.show(onDismissRequest: { dialogs.dismiss() }) {
            AppDialog(title: "Remove \(name)?") {
                Text("You won't be able to send each other phrases until you're friends again. Phrases you've already shared stay where they are.")
            } buttons: {
                DialogButton(text: "Cancel") { dialogs.dismiss() }
                DialogButton(text: "Remove", color: AppColor.error) {
                    dialogs.dismiss()
                    viewModel.removeFriend(friendUid) { success in
                        if success {
                            openFriendUid = nil
                            toast.success("Removed \(name)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Header + tabs

private struct FriendsHeader: View {
    let onAddFriend: () -> Void

    var body: some View {
        HStack {
            Text("Friends")
                .screenTitleStyle()
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onAddFriend) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColor.textInverse)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppColor.primary))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Add friend")
        }
        .padding(.top, 16)
    }
}

private struct FriendsTabs: View {
    let uiState: FriendsUiState
    let onTabSelected: (FriendsTab) -> Void

    var body: some View {
        HStack(spacing: 4) {
            SegmentTab(label: "Friends", count: uiState.friendships.count, selected: uiState.activeTab == .friends) {
                onTabSelected(.friends)
            }
            SegmentTab(label: "Suggestions", count: uiState.pendingSuggestions.count, selected: uiState.activeTab == .suggestions) {
                onTabSelected(.suggestions)
            }
            SegmentTab(label: "Requests", count: uiState.incomingRequests.count, selected: uiState.activeTab == .requests) {
                onTabSelected(.requests)
            }
        }
        .padding(4)
        .roundedBackground(AppColor.backgroundPrimary, 16)
    }
}

private struct SegmentTab: View {
    let label: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(AppFont.dmSans(13, .bold))
                    .foregroundStyle(selected ? AppColor.textInverse : AppColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if count > 0 {
                    Text("\(count)")
                        .font(AppFont.dmSans(11, .bold))
                        .foregroundStyle(selected ? AppColor.textPrimary : AppColor.primaryDark)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(selected ? AppColor.backgroundPrimary : AppColor.primarySoft))
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AppColor.secondary : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Friends tab

private struct FriendsListTab: View {
    let friendships: [Friendship]
    let currentUid: String?
    @Binding var query: String
    let nameFor: (String) -> String
    let onFindFriends: () -> Void
    let onOpenFriend: (String) -> Void
    let loaded: Bool

    var body: some View {
        if !loaded {
            VStack(spacing: 0) {
                LoadingState()
                Spacer(minLength: 0)
            }
        } else {
            let q = query.trimmed
            let visible = friendships.filter { friendship in
                guard let uid = friendship.otherUid(currentUid) else { return false }
                return q.isEmpty || nameFor(uid).containsIgnoreCase(q)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    if !friendships.isEmpty {
                        FriendsSearchField(value: $query, placeholder: "Search friends")
                    }
                    ForEach(visible) { friendship in
                        if let uid = friendship.otherUid(currentUid) {
                            Button { onOpenFriend(uid) } label: {
                                FriendCard(name: nameFor(uid), friendship: friendship, friendUid: uid)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityHint("Opens their profile")
                        }
                    }
                    if !friendships.isEmpty && visible.isEmpty {
                        Text("No friends match “\(q)”.")
                            .font(AppFont.dmSans(15))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                    }
                    FindFriendsCard(onFindFriends: onFindFriends)
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct FriendsSearchField: View {
    @Binding var value: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 18, height: 18)
            ZStack(alignment: .leading) {
                if value.isEmpty {
                    Text(placeholder)
                        .font(AppFont.dmSans(16))
                        .foregroundStyle(AppColor.textTertiary)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextField("", text: $value)
                    .font(AppFont.dmSans(16))
                    .foregroundStyle(AppColor.textPrimary)
                    .tint(AppColor.accent)
                    .accessibilityLabel(placeholder)
            }
            if !value.isEmpty {
                Button { value = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, value.isEmpty ? 14 : 0)
        .frame(height: 48)
        .roundedBackground(AppColor.backgroundPrimary, 16)
    }
}

private struct FriendCard: View {
    let name: String
    let friendship: Friendship
    let friendUid: String

    var body: some View {
        let profile = friendship.userProfiles[friendUid]
        let streak = profile?.currentStreak ?? 0
        let languageCount = profile?.learningLanguages.count ?? 0
        let note = (friendship.note ?? "").trimmed
        var meta = streak > 0 ? "\(streak)-day streak" : "No streak yet"
        if languageCount > 0 {
            meta += " · " + (languageCount == 1 ? "1 language" : "\(languageCount) languages")
        }
        return HStack(spacing: 14) {
            FriendAvatar(name: name, size: 52, tinted: false, uid: friendUid)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(AppFont.dmSans(17, .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !note.isEmpty {
                    Text("“\(note)”")
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textBody)
                        .slanted()
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.accent)
                    Text(meta)
                        .font(AppFont.dmSans(13, .semibold))
                        .foregroundStyle(AppColor.textBody)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .contentShape(Rectangle())
        .roundedBackground(AppColor.backgroundPrimary, 20)
        .accessibilityElement(children: .combine)
    }
}

private struct FindFriendsCard: View {
    let onFindFriends: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Kato waving in the corner of the card, as in the design (text keeps clear of him).
            Kato(pose: .wave, width: 72, outline: true)
                .padding(.trailing, 14)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Learn together with friends")
                        .font(AppFont.poppins(18))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Find friends by their username to swap useful phrases and keep each other going.")
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Button(action: onFindFriends) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .semibold))
                        Text("Find friends").font(AppFont.dmSans(14, .bold))
                    }
                    .foregroundStyle(AppColor.textInverse)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(AppColor.primary))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.leading, 18)
            .padding(.vertical, 18)
            .padding(.trailing, 104)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DashedRoundedBorder(color: AppColor.neutral400, radius: 20))
    }
}

// MARK: - Friend profile (tap a friend card)

/** One phrase in "Suggestions between you": sent to me by the friend, or sent by me. */
private struct SharedSuggestion: Identifiable {
    let suggestion: Suggestion
    let fromFriend: Bool
    var id: String { suggestion.id }
}

private struct FriendProfileView: View {
    let friendUid: String
    let friendName: String
    let friendship: Friendship
    let received: [Suggestion]
    let busySuggestionIds: Set<String>
    let removing: Bool
    let onBack: () -> Void
    let onSave: (Suggestion) -> Void
    let onRemove: () -> Void

    @StateObject private var sent = SentSuggestionsModel()
    @State private var bio = ""

    var body: some View {
        let profile = friendship.userProfiles[friendUid]
        let streak = profile?.currentStreak ?? 0
        let languages = profile?.learningLanguages ?? []
        let since = formatDate(friendship.createdAt, "MMMM d, yyyy")
        let shared = (received.map { SharedSuggestion(suggestion: $0, fromFriend: true) } +
            sent.items.map { SharedSuggestion(suggestion: $0, fromFriend: false) })
            .sorted { ($0.suggestion.createdAt?.millis ?? 0) > ($1.suggestion.createdAt?.millis ?? 0) }

        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium))
                    Text("Friends").font(AppFont.dmSans(16, .bold))
                }
                .foregroundStyle(AppColor.textPrimary)
                .padding(.trailing, 12)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            ScrollView {
                VStack(spacing: 12) {
                    // Who they are
                    VStack(spacing: 6) {
                        FriendAvatar(name: friendName, size: 88, tinted: false, uid: friendUid)
                            .padding(.bottom, 4)
                        Text(friendName)
                            .font(AppFont.poppins(26))
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        if !bio.isEmpty {
                            Text(bio)
                                .font(AppFont.dmSans(15))
                                .foregroundStyle(AppColor.textBody)
                                .multilineTextAlignment(.center)
                        }
                        if !since.isEmpty {
                            Text("Friends since \(since)")
                                .font(AppFont.dmSans(13, .semibold))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Streak + languages
                    HStack(spacing: 10) {
                        ProfileStat(value: "\(streak)", label: "day streak", icon: "flame.fill")
                        ProfileStat(value: "\(languages.count)", label: languages.count == 1 ? "language" : "languages")
                    }
                    if !languages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LEARNING").overlineStyle()
                            FlowLayout(spacing: 8, lineSpacing: 8) {
                                ForEach(languages, id: \.self) { code in
                                    Text(Languages.displayName(code))
                                        .font(AppFont.dmSans(14, .semibold))
                                        .foregroundStyle(AppColor.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(AppColor.backgroundSecondary))
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .roundedBackground(AppColor.backgroundPrimary, 20)
                    }

                    // Suggestions between you
                    Text("SUGGESTIONS BETWEEN YOU")
                        .overlineStyle()
                        .accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                    if shared.isEmpty {
                        Text("No phrases shared yet. Send \(friendName) one from Translate or your Library.")
                            .font(AppFont.dmSans(15))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    ForEach(shared) { item in
                        SharedSuggestionCard(
                            item: item,
                            friendName: friendName,
                            busy: busySuggestionIds.contains(item.id),
                            onSave: { onSave(item.suggestion) }
                        )
                    }

                    // Remove friend
                    Button(action: onRemove) {
                        HStack(spacing: 8) {
                            if removing {
                                ProgressView().tint(AppColor.error).controlSize(.small)
                            } else {
                                Image(systemName: "person.badge.minus").font(.system(size: 15, weight: .semibold))
                                Text("Remove friend").font(AppFont.dmSans(15, .bold))
                            }
                        }
                        .foregroundStyle(AppColor.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(AppColor.backgroundPrimary))
                        .overlay(Capsule().strokeBorder(AppColor.neutral300, lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(removing)
                    .padding(.top, 12)
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 8)
        .task {
            sent.start(friendUid: friendUid)
            bio = await UserProfileRepository.shared.fetchProfile(uid: friendUid).bio
        }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.accent)
                }
                Text(value)
                    .font(AppFont.poppins(30))
                    .foregroundStyle(AppColor.textPrimary)
            }
            Text(label)
                .font(AppFont.dmSans(14))
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedBackground(AppColor.backgroundPrimary, 20)
        .accessibilityElement(children: .combine)
    }
}

private struct SharedSuggestionCard: View {
    let item: SharedSuggestion
    let friendName: String
    let busy: Bool
    let onSave: () -> Void

    var body: some View {
        let suggestion = item.suggestion
        let phrase = suggestion.phraseSnapshot
        let date = formatDate(suggestion.createdAt, "MMM d")
        let status = suggestion.status.lowercased()
        let who = item.fromFriend ? "From \(friendName)" : "You sent"
        // What happened to it: for theirs, whether I kept it; for mine, whether they did.
        let outcome: String? = {
            if status == "saved" { return "Saved" }
            if status == "dismissed" { return "Dismissed" }
            if !item.fromFriend { return status == "pending" ? "Not opened yet" : "Seen" }
            return nil
        }()
        let canSave = item.fromFriend && inboxStatuses.contains(status)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(date.isEmpty ? who : "\(who) · \(date)")
                    .font(AppFont.dmSans(13, .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let outcome {
                    Text(outcome)
                        .font(AppFont.dmSans(13, .bold))
                        .foregroundStyle(status == "saved" ? AppColor.accent : AppColor.textSecondary)
                }
            }
            Text(phrase.original)
                .font(AppFont.dmSans(14))
                .foregroundStyle(AppColor.textBody)
            Text(phrase.translated)
                .phraseTextStyle()
            if phrase.romanized.isNotBlank {
                Text(phrase.romanized)
                    .font(AppFont.dmSans(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .slanted()
            }
            if canSave {
                PillButton(text: busy ? "Saving…" : "Save to library", enabled: !busy, filled: true, action: onSave)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roundedBackground(AppColor.backgroundPrimary, 20)
    }
}

// MARK: - Suggestions tab

private struct SuggestionsTab: View {
    let suggestions: [Suggestion]
    @Binding var unreadOnly: Bool
    let savedFromName: String?
    let busyIds: Set<String>
    let nameFor: (String) -> String
    let onOpen: (Suggestion) -> Void
    let onSave: (Suggestion) -> Void
    let onDismiss: (Suggestion) -> Void

    var body: some View {
        let inbox = suggestions.filter { inboxStatuses.contains($0.status.lowercased()) }
        let unread = inbox.filter { $0.status.equalsIgnoreCase("pending") }
        let visible = unreadOnly ? unread : inbox
        ScrollView {
            LazyVStack(spacing: 12) {
                if let savedFromName {
                    StatusBanner(text: "Saved to your library. \(savedFromName) will be notified.")
                }
                if !inbox.isEmpty {
                    HStack(spacing: 8) {
                        FilterPill(text: "All (\(inbox.count))", selected: !unreadOnly) { unreadOnly = false }
                        FilterPill(text: "Unread (\(unread.count))", selected: unreadOnly) { unreadOnly = true }
                        Spacer(minLength: 0)
                    }
                }
                if visible.isEmpty {
                    EmptySuggestions(
                        title: inbox.isEmpty ? "No suggestions yet" : "You're all caught up",
                        message: inbox.isEmpty ? "When friends send you phrases, they'll show up here." : "No unread suggestions right now."
                    )
                }
                ForEach(visible) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        senderName: nameFor(suggestion.fromUid),
                        busy: busyIds.contains(suggestion.id),
                        onDetails: { onOpen(suggestion) },
                        onSave: { onSave(suggestion) },
                        onDismiss: { onDismiss(suggestion) }
                    )
                }
            }
            .padding(.bottom, 16)
        }
    }
}

private struct FilterPill: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(AppFont.dmSans(14, .semibold))
                .foregroundStyle(selected ? AppColor.textInverse : AppColor.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(selected ? AppColor.secondary : AppColor.backgroundPrimary))
                .overlay(Capsule().strokeBorder(selected ? AppColor.secondary : AppColor.neutral300, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct SuggestionCard: View {
    let suggestion: Suggestion
    let senderName: String
    let busy: Bool
    let onDetails: () -> Void
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let phrase = suggestion.phraseSnapshot
        let isUnread = suggestion.status.equalsIgnoreCase("pending")
        let date = formatDate(suggestion.createdAt, "MMM d")
        let message = (suggestion.message ?? "").trimmed
        let pair = languagePair(phrase.sourceLang, phrase.targetLang, languageCode)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                FriendAvatar(name: senderName, size: 40, tinted: false, uid: suggestion.fromUid)
                VStack(alignment: .leading, spacing: 0) {
                    Text(senderName)
                        .font(AppFont.dmSans(15, .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                    Text(date.isEmpty ? "Suggested a phrase" : "Suggested a phrase · \(date)")
                        .font(AppFont.dmSans(13))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isUnread {
                    Circle()
                        .fill(AppColor.primary)
                        .frame(width: 10, height: 10)
                        .accessibilityLabel("Unread")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if !pair.isEmpty {
                    Text(pair)
                        .font(AppFont.dmSans(11, .bold))
                        .tracking(0.66)
                        .foregroundStyle(AppColor.textBody)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .roundedBackground(AppColor.backgroundPrimary, 6)
                }
                Text(phrase.original)
                    .font(AppFont.dmSans(14))
                    .foregroundStyle(AppColor.textBody)
                Text(phrase.translated)
                    .phraseTextStyle()
                if phrase.romanized.isNotBlank {
                    Text(phrase.romanized)
                        .font(AppFont.dmSans(13))
                        .foregroundStyle(AppColor.textSecondary)
                        .slanted()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .roundedBackground(AppColor.backgroundSecondary, 16)

            if !message.isEmpty {
                Text("“\(message)”")
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textBody)
                    .slanted()
            }

            HStack(spacing: 8) {
                PillButton(text: "Dismiss", enabled: !busy, filled: false, action: onDismiss)
                PillButton(text: "Details", enabled: !busy, filled: false, action: onDetails)
                PillButton(text: "Save", enabled: !busy, filled: true, action: onSave)
            }
        }
        .padding(16)
        .roundedBackground(AppColor.backgroundPrimary, 24)
    }
}

private struct SuggestionDetail: View {
    let suggestion: Suggestion
    let senderName: String
    let busy: Bool
    let onBack: () -> Void
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let phrase = suggestion.phraseSnapshot
        let date = formatDate(suggestion.createdAt, "MMMM d")
        let message = (suggestion.message ?? "").trimmed
        let pair = languagePair(phrase.sourceLang, phrase.targetLang, Languages.displayName).uppercased()

        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium))
                    Text("Suggestions").font(AppFont.dmSans(16, .bold))
                }
                .foregroundStyle(AppColor.textPrimary)
                .padding(.trailing, 12)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            Spacer().frame(height: 8)

            ScrollView {
                VStack(spacing: 14) {
                    // Phrase hero card
                    VStack(alignment: .leading, spacing: 10) {
                        if !pair.isEmpty {
                            Text(pair)
                                .font(AppFont.dmSans(11, .bold))
                                .tracking(1.1)
                                .foregroundStyle(AppColor.textOnDark)
                        }
                        Text(phrase.original)
                            .font(AppFont.dmSans(17))
                            .foregroundStyle(AppColor.textOnDarkMuted)
                        Text(phrase.translated)
                            .font(AppFont.poppins(36))
                            .tracking(-0.36)
                            .foregroundStyle(AppColor.textInverse)
                        if phrase.romanized.isNotBlank {
                            Text(phrase.romanized)
                                .font(AppFont.dmSans(15))
                                .foregroundStyle(AppColor.textOnDark)
                                .slanted()
                        }
                        SpeakButton(text: phrase.translated, language: phrase.targetLang, tint: AppColor.textInverse)
                            .offset(x: -10)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .roundedBackground(AppColor.secondary, 28)

                    // Sender + note
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            FriendAvatar(name: senderName, size: 44, tinted: false, uid: suggestion.fromUid)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Suggested by")
                                    .font(AppFont.dmSans(13))
                                    .foregroundStyle(AppColor.textSecondary)
                                Text(date.isEmpty ? senderName : "\(senderName) · \(date)")
                                    .font(AppFont.dmSans(16, .bold))
                                    .foregroundStyle(AppColor.textPrimary)
                            }
                        }
                        if !message.isEmpty {
                            Text("“\(message)”")
                                .font(AppFont.dmSans(16))
                                .foregroundStyle(AppColor.textPrimary)
                                .slanted()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16)
                                        .fill(AppColor.neutral100)
                                )
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .roundedBackground(AppColor.backgroundPrimary, 20)
                }
            }

            Spacer().frame(height: 12)
            PrimaryPillButton(text: busy ? "Saving…" : "Save to library", icon: "bookmark.fill", enabled: !busy, action: onSave)
            Spacer().frame(height: 10)
            PillButton(text: "Dismiss", enabled: !busy, filled: false, height: 50, action: onDismiss)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

private struct EmptySuggestions: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            // Kato napping while the inbox is empty, as in the design.
            Kato(pose: .sleep, width: 104, outline: true)
            Text(title)
                .font(AppFont.poppins(22))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppFont.dmSans(15))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }
}

// MARK: - Requests tab

private struct RequestsTab: View {
    let uiState: FriendsUiState
    let nameFor: (String) -> String
    let onAcceptRequest: (String) -> Void
    let onDeclineRequest: (String) -> Void

    var body: some View {
        if uiState.incomingRequests.isEmpty {
            Text("No pending friend requests")
                .font(AppFont.dmSans(16))
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("RECEIVED · \(uiState.incomingRequests.count)")
                        .font(AppFont.dmSans(12, .bold))
                        .tracking(1.2)
                        .foregroundStyle(AppColor.textSecondary)
                    ForEach(uiState.incomingRequests) { request in
                        FriendRequestCard(
                            request: request,
                            senderName: nameFor(request.fromUid),
                            onAccept: onAcceptRequest,
                            onDecline: onDeclineRequest,
                            pending: uiState.pendingRequestIds.contains(request.id)
                        )
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
}

/** Streak + languages from a user's public profile (users/{uid}); nil until loaded. */
private struct PublicStats {
    let currentStreak: Int
    let learningLanguages: [String]
}

private struct FriendRequestCard: View {
    let request: FriendRequest
    let senderName: String
    let onAccept: (String) -> Void
    let onDecline: (String) -> Void
    let pending: Bool

    @State private var stats: PublicStats?

    var body: some View {
        let note = (request.note ?? "").trimmed
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                FriendAvatar(name: senderName, size: 56, tinted: true, uid: request.fromUid)
                VStack(alignment: .leading, spacing: 2) {
                    Text(senderName)
                        .font(AppFont.dmSans(17, .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                    if !note.isEmpty {
                        Text("“\(note)”")
                            .font(AppFont.dmSans(14))
                            .foregroundStyle(AppColor.textBody)
                            .slanted()
                            .lineLimit(3)
                    } else {
                        Text("wants to learn with you")
                            .font(AppFont.dmSans(14))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Streak + languages, when the sender has any (read from their public profile).
            if let stats, stats.currentStreak > 0 || !stats.learningLanguages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if stats.currentStreak > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill").font(.system(size: 12))
                                Text("\(stats.currentStreak)-day streak").font(AppFont.dmSans(13, .semibold))
                            }
                            .foregroundStyle(AppColor.primaryDark)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .roundedBackground(AppColor.primarySoft, 8)
                        }
                        ForEach(stats.learningLanguages, id: \.self) { code in
                            Text(Languages.displayName(code))
                                .font(AppFont.dmSans(13, .semibold))
                                .foregroundStyle(AppColor.textBody)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .roundedBackground(AppColor.backgroundSecondary, 8)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                PillButton(text: "Decline", enabled: !pending, filled: false, height: 48) { onDecline(request.id) }
                PillButton(text: pending ? "Working…" : "Accept", enabled: !pending, filled: true, height: 48) { onAccept(request.id) }
            }
        }
        .padding(18)
        .roundedBackground(AppColor.backgroundPrimary, 24)
        .task(id: request.fromUid) {
            guard !request.fromUid.isBlank else { return }
            if let data = try? await Backend.db.collection("users").document(request.fromUid).getDocument().data() {
                stats = PublicStats(
                    currentStreak: data.int("currentStreak") ?? 0,
                    learningLanguages: data.stringList("learningLanguages")
                )
            }
        }
    }
}

// MARK: - Add Friend sheet

private struct AddFriendSheet: View {
    @ObservedObject var viewModel: FriendsViewModel
    let currentUid: String?
    let onSendFriendRequest: (String) -> Void

    var body: some View {
        let uiState = viewModel.uiState
        let searchQuery = uiState.searchQuery
        let friendUids = Set(uiState.friendships.compactMap { $0.otherUid(currentUid) })
        let incomingByUid = Dictionary(uiState.incomingRequests.map { ($0.fromUid, $0) }, uniquingKeysWith: { first, _ in first })
        let searchedEmail: String? = searchQuery.trimmed.contains("@") ? searchQuery.trimmed : nil

        VStack(alignment: .leading, spacing: 12) {
            Text("Add Friend")
                .font(AppFont.poppins(24))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            DialogTextField(
                label: "Search by username or email",
                text: Binding(get: { viewModel.uiState.searchQuery }, set: viewModel.onSearchQueryChange)
            )
            PrimaryPillButton(
                text: uiState.isSearchLoading ? "Searching..." : "Search",
                icon: "magnifyingglass",
                enabled: !uiState.isSearchLoading,
                height: 50,
                fontSize: 14,
                action: viewModel.searchUsers
            )
            ForEach(uiState.searchResults) { result in
                let incomingId = incomingByUid[result.uid]?.id
                SearchResultRow(
                    result: result,
                    isFriend: friendUids.contains(result.uid),
                    incomingRequestId: incomingId,
                    searchedEmail: searchedEmail,
                    sending: uiState.pendingOutgoingRequests.contains(result.uid),
                    accepting: incomingId.map { uiState.pendingRequestIds.contains($0) } ?? false,
                    onAdd: { onSendFriendRequest(result.uid) },
                    onAccept: { viewModel.respondToRequest($0, accept: true) }
                )
            }
            if let searched = uiState.searchedQuery, !uiState.isSearchLoading,
               searched == searchQuery.trimmed, uiState.searchResults.isEmpty {
                NoSearchResults(query: searched)
            }
            if let error = uiState.errorMessage {
                Text(error)
                    .font(AppFont.dmSans(14, .semibold))
                    .foregroundStyle(AppColor.error)
            }
            Spacer().frame(height: 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

/** Shown when a search comes back empty, instead of nothing at all. */
private struct NoSearchResults: View {
    let query: String

    var body: some View {
        VStack(spacing: 4) {
            Text("No one found for “\(query)”")
                .font(AppFont.dmSans(15, .bold))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(query.contains("@")
                 ? "Check the email, or ask them for their username."
                 : "Check the spelling, or search by their email instead.")
                .font(AppFont.dmSans(14))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .roundedBackground(AppColor.backgroundSecondary, 16)
    }
}

/**
 * One person in the Add Friend search results: avatar, username, and a readable status line
 * (never their internal user ID) with the action that fits — Add, Accept, or "Friends".
 */
private struct SearchResultRow: View {
    let result: PublicUserSearchResult
    let isFriend: Bool
    let incomingRequestId: String?
    let searchedEmail: String?
    let sending: Bool
    let accepting: Bool
    let onAdd: () -> Void
    let onAccept: (String) -> Void

    var body: some View {
        let name = result.username.isBlank ? "Unnamed user" : result.username.trimmed
        let status: String? = isFriend ? "Already friends" : (incomingRequestId != nil ? "Sent you a request" : searchedEmail)
        HStack(spacing: 0) {
            FriendAvatar(name: name, size: 36, tinted: false, uid: result.uid)
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(AppFont.dmSans(15, .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                if let status {
                    Text(status)
                        .font(AppFont.dmSans(13))
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 8)
            if isFriend {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                    Text("Friends").font(AppFont.dmSans(13, .bold))
                }
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Capsule().fill(AppColor.neutral100))
            } else if let incomingRequestId {
                PillButton(text: accepting ? "Accepting…" : "Accept", enabled: !accepting, filled: true, height: 40) {
                    onAccept(incomingRequestId)
                }
                .frame(minWidth: 76)
                .fixedSize()
            } else {
                PillButton(
                    text: sending ? "Sending…" : "Add",
                    enabled: !sending,
                    filled: true,
                    icon: sending ? nil : "person.badge.plus",
                    height: 40,
                    action: onAdd
                )
                .frame(minWidth: 76)
                .fixedSize()
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .roundedBackground(AppColor.backgroundSecondary, 16)
    }
}

// MARK: - Shared bits

/** Shows the person's profile photo when they have one (loaded by uid). */
private struct FriendAvatar: View {
    let name: String
    let size: CGFloat
    let tinted: Bool
    var uid: String? = nil

    var body: some View {
        UserAvatar(
            name: name,
            size: size,
            background: tinted ? AppColor.primarySoft : AppColor.tertiary,
            initialColor: tinted ? AppColor.primaryDark : AppColor.textPrimary,
            uid: uid
        )
    }
}

private struct PillButton: View {
    let text: String
    let enabled: Bool
    let filled: Bool
    var icon: String? = nil
    var height: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(text).font(AppFont.dmSans(14, .bold)).lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(
                filled
                    ? (enabled ? AppColor.textInverse : AppColor.textPrimary.opacity(0.38))
                    : (enabled ? AppColor.textPrimary : AppColor.textPrimary.opacity(0.38))
            )
            .background(
                Capsule().fill(
                    filled
                        ? (enabled ? AppColor.primary : AppColor.textPrimary.opacity(0.12))
                        : AppColor.backgroundPrimary
                )
            )
            .overlay {
                if !filled { Capsule().strokeBorder(AppColor.neutral300, lineWidth: 1.5) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

private struct StatusBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.accent)
            Text(text)
                .font(AppFont.dmSans(14, .semibold))
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .roundedBackground(AppColor.neutral100, 16)
    }
}

private func formatDate(_ timestamp: Timestamp?, _ pattern: String) -> String {
    guard let date = timestamp?.dateValue() else { return "" }
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.dateFormat = pattern
    return formatter.string(from: date)
}

private func languagePair(_ source: String, _ target: String, _ label: (String) -> String) -> String {
    let from = source.trimmed
    let to = target.trimmed
    if !from.isEmpty && !to.isEmpty { return "\(label(from)) → \(label(to))" }
    if !to.isEmpty { return label(to) }
    return ""
}

/** "es" → "ES"; anything longer is assumed to already be a display name. */
private func languageCode(_ code: String) -> String { code.count <= 3 ? code.uppercased() : code }

private func shortId(_ uid: String) -> String {
    uid.count <= 10 ? uid : "\(uid.prefix(4))…\(uid.suffix(4))"
}
