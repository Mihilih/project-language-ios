import SwiftUI

private let maxMessage = 200

/**
 * "Suggest to a friend" from Translate or Library: shows the phrase, lets you tick one or more
 * friends, add an optional message, and send. `onSent` gets the names it went to
 * (SuggestToFriendSheet.kt).
 */
struct SuggestToFriendSheet: View {
    let phrase: PhraseSnapshot
    let onSent: ([String]) -> Void
    var onError: (String) -> Void = { _ in }

    @StateObject private var viewModel = SuggestToFriendViewModel()
    @StateObject private var usernameResolver = UsernameResolver()
    @State private var picked = Set<String>()
    @State private var message = ""
    // Shown inside the sheet: a toast would sit behind the sheet.
    @State private var sendError: String?

    var body: some View {
        let uiState = viewModel.uiState
        let currentUid = AuthManager.getCurrentUserId()
        let friendUids = uiState.friendships.compactMap { friendship in
            friendship.users.first { $0 != currentUid }
        }.uniqued()
        var knownNames: [String: String] = [:]
        for profile in uiState.friendships.flatMap({ Array($0.userProfiles.values) }) where profile.username.isNotBlank {
            knownNames[profile.uid] = profile.username.trimmed
        }
        let usernames = usernameResolver.names(for: friendUids, known: knownNames)
        let nameFor: (String) -> String = { usernames[$0] ?? "Friend" }
        let pickedNames = friendUids.filter { picked.contains($0) }.map(nameFor)
        let sendLabel: String = uiState.isSending ? "Sending…" : (picked.count > 1 ? "Send to \(picked.count) friends" : "Send suggestion")

        return VStack(alignment: .leading, spacing: 16) {
            Text("Suggest to a friend")
                .font(AppFont.poppins(24))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.original)
                    .font(AppFont.dmSans(14))
                    .foregroundStyle(AppColor.textBody)
                Text(phrase.translated)
                    .font(AppFont.poppins(20))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .roundedBackground(AppColor.backgroundSecondary, 16)

            if uiState.isLoadingFriends {
                LoadingState().frame(minHeight: 60)
            } else if uiState.friendsError {
                Text("Couldn't load your friends. Check your connection and try again.")
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textSecondary)
            } else if friendUids.isEmpty {
                Text("You haven't added any friends yet. Add them from the Friends tab, then you can send them phrases.")
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(friendUids.enumerated()), id: \.element) { index, uid in
                        FriendPickRow(
                            name: nameFor(uid),
                            selected: picked.contains(uid),
                            altAvatar: index % 2 == 1
                        ) {
                            if picked.contains(uid) { picked.remove(uid) } else { picked.insert(uid) }
                            sendError = nil
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Add a message (optional)")
                    .font(AppFont.dmSans(13, .bold))
                    .foregroundStyle(AppColor.textBody)
                OutlinedField(
                    text: Binding(get: { message }, set: { message = $0.take(maxMessage) }),
                    placeholder: "e.g. Useful for the market!"
                )
            }

            if let sendError {
                Text(sendError)
                    .font(AppFont.dmSans(14, .semibold))
                    .foregroundStyle(AppColor.error)
            }

            PrimaryPillButton(text: sendLabel, enabled: !picked.isEmpty && !uiState.isSending) {
                sendError = nil
                let trimmed = message.trimmed
                viewModel.send(toUids: Array(picked), phrase: phrase, message: trimmed.isBlank ? nil : trimmed) { success, error in
                    if success {
                        onSent(pickedNames)
                    } else {
                        let friendly = friendlySendError(error)
                        sendError = friendly
                        onError(friendly)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

private struct FriendPickRow: View {
    let name: String
    let selected: Bool
    let altAvatar: Bool
    let onToggle: () -> Void

    var body: some View {
        let border = selected ? AppColor.accent : AppColor.outline
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(altAvatar ? AppColor.primarySoft : AppColor.tertiary)
                    Text(name.initial)
                        .font(AppFont.poppins(16))
                        .foregroundStyle(altAvatar ? AppColor.primaryDark : AppColor.textPrimary)
                }
                .frame(width: 36, height: 36)
                Text(name)
                    .font(AppFont.dmSans(16, .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().fill(selected ? AppColor.primary : Color.clear)
                    Circle().strokeBorder(border, lineWidth: 2)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColor.textInverse)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 14)
            .frame(height: 60)
            .roundedBackground(AppColor.backgroundPrimary, 16)
            .roundedBorder(border, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/** Joins names the way the design's toast does: "A", "A and B", "A, B and 2 more". */
func suggestedToText(_ names: [String]) -> String {
    switch names.count {
    case 0: return "Suggestion sent!"
    case 1: return "Suggested to \(names[0])!"
    case 2: return "Suggested to \(names[0]) and \(names[1])!"
    default: return "Suggested to \(names[0]), \(names[1]) and \(names.count - 2) more!"
    }
}

private func friendlySendError(_ error: String?) -> String {
    let e = (error ?? "").lowercased()
    if e.contains("network") || e.contains("unavailable") || e.contains("offline") {
        return "You're offline. Try again when you reconnect."
    }
    if e.contains("only suggest phrases to friends") { return "You can only suggest phrases to friends." }
    return "Couldn't send the suggestion. Please try again."
}
