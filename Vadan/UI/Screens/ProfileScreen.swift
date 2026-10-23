import SwiftUI
import PhotosUI

/** The Profile tab (ProfileScreen.kt). */
struct ProfileScreen: View {
    /** True while this tab is showing; stats reload each time it comes into view. */
    let isActive: Bool
    let onLoggedOut: () -> Void

    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var feedbackViewModel = FeedbackViewModel()
    @StateObject private var toast = ToastState()
    @EnvironmentObject var dialogs: DialogHost

    @State private var editing = false
    @State private var showFeedback = false

    var body: some View {
        let uiState = viewModel.uiState
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileHeader {
                        viewModel.startEditing()
                        editing = true
                    }
                    Identity(uiState: uiState)
                    StreakCard(streak: uiState.currentStreak, week: uiState.week)

                    HStack(alignment: .top, spacing: 10) {
                        ProfileStatTile(
                            value: uiState.newPhrasesThisWeek,
                            label: uiState.newPhrasesThisWeek == 1 ? "New phrase this week" : "New phrases this week"
                        )
                        ProfileStatTile(
                            value: uiState.studiedThisWeek,
                            label: uiState.studiedThisWeek == 1 ? "Phrase studied this week" : "Phrases studied this week"
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    DailyActivity(week: uiState.week)
                    AllTimeStats(uiState: uiState)
                    Achievements(achievements: uiState.achievements)

                    Spacer().frame(height: 4)
                    OutlinePillButton(text: "Send feedback", icon: "bubble.left", fontSize: 14) {
                        showFeedback = true
                    }
                    OutlinePillButton(
                        text: "Log out",
                        icon: "rectangle.portrait.and.arrow.right",
                        enabled: !uiState.isLoggingOut,
                        loading: uiState.isLoggingOut,
                        fontSize: 14,
                        content: AppColor.error
                    ) {
                        confirmLogout()
                    }
                    if uiState.email.isNotBlank {
                        Text("Signed in as \(uiState.email)")
                            .font(AppFont.dmSans(13))
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    PlainTextButton(
                        text: "Delete account",
                        color: AppColor.textSecondary,
                        fontSize: 14,
                        weight: .bold,
                        enabled: !uiState.isLoggingOut
                    ) {
                        showDeleteDialog()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(AppColor.backgroundSecondary)

            AppToastHost(state: toast)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        // Reload stats whenever the tab comes back into view (e.g. after a study session).
        .onAppear { if isActive { viewModel.refreshStats() } }
        .onChange(of: isActive) { _, active in if active { viewModel.refreshStats() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if isActive { viewModel.refreshStats() }
        }
        .appSheet(isPresented: $showFeedback, dismissDisabled: feedbackViewModel.uiState.sending) {
            FeedbackSheet(viewModel: feedbackViewModel) {
                showFeedback = false
                toast.success("Thanks! Your feedback was sent.")
            }
        }
        .appSheet(isPresented: $editing, onDismiss: { viewModel.clearBioError() }) {
            EditProfileSheet(
                viewModel: viewModel,
                onDismiss: {
                    editing = false
                    viewModel.clearBioError()
                }
            )
        }
    }

    private func confirmLogout() {
        dialogs.show(onDismissRequest: { dialogs.dismiss() }) {
            AppDialog(title: "Log out?") {
                Text("You'll stop getting friend notifications on this device until you sign back in.")
            } buttons: {
                DialogButton(text: "Cancel") { dialogs.dismiss() }
                DialogButton(text: "Log out", color: AppColor.error) {
                    dialogs.dismiss()
                    viewModel.logout(onLoggedOut: onLoggedOut)
                }
            }
        }
    }

    private func showDeleteDialog() {
        let dismiss = {
            if !viewModel.uiState.isDeleting {
                dialogs.dismiss()
                viewModel.clearDeleteError()
            }
        }
        dialogs.show(onDismissRequest: dismiss) {
            DeleteAccountDialog(
                viewModel: viewModel,
                onDismiss: dismiss,
                onConfirmPassword: { password in
                    viewModel.deleteAccount(password: password, google: nil) {
                        dialogs.dismiss()
                        onLoggedOut()
                    }
                },
                onConfirmGoogle: {
                    viewModel.onDeleteStarted()
                    Task {
                        switch await GoogleSignInHelper.getTokens() {
                        case .success(let tokens):
                            viewModel.deleteAccount(password: nil, google: tokens) {
                                dialogs.dismiss()
                                onLoggedOut()
                            }
                        case .failure(let error):
                            viewModel.onDeleteFailed(error is GoogleSignInHelper.Cancelled ? nil : error.localizedDescription)
                        }
                    }
                }
            )
        }
    }
}

private struct ProfileHeader: View {
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Text("Profile")
                .screenTitleStyle()
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil").font(.system(size: 13, weight: .semibold))
                    Text("Edit profile").font(AppFont.dmSans(14, .bold))
                }
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Capsule().fill(AppColor.backgroundPrimary))
            }
            .buttonStyle(PressableStyle())
        }
    }
}

private struct Identity: View {
    let uiState: ProfileUiState

    var body: some View {
        HStack(spacing: 16) {
            ProfileAvatar(username: uiState.username, size: 72, photo: uiState.photo)
            VStack(alignment: .leading, spacing: 4) {
                Text(uiState.username.isBlank ? "Your profile" : uiState.username)
                    .font(AppFont.poppins(22))
                    .foregroundStyle(AppColor.textPrimary)
                Text(uiState.bio.isBlank ? "Add a bio so friends know what you're learning." : uiState.bio)
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ProfileAvatar: View {
    let username: String
    let size: CGFloat
    var photo: String? = nil

    var body: some View {
        UserAvatar(
            name: username,
            size: size,
            background: AppColor.primary,
            initialColor: AppColor.textInverse,
            photo: photo.flatMap(UserPhotos.decode)
        )
    }
}

private struct StreakCard: View {
    let streak: Int
    let week: [DayActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(streak)")
                        .font(AppFont.poppins(68))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("day streak")
                        .font(AppFont.poppins(22))
                        .foregroundStyle(AppColor.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Kato celebrates the streak (and naps when there isn't one yet).
                Kato(pose: streak > 0 ? .celebrate : .sleep, width: 76, outline: true)
                    .offset(x: 4, y: 10)
            }
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                    let done = day.studied > 0
                    VStack(spacing: 6) {
                        ZStack {
                            if done {
                                Circle().fill(AppColor.secondary)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppColor.tertiary)
                            } else {
                                Circle().strokeBorder(
                                    AppColor.textSecondary.opacity(day.isFuture ? 0.25 : 0.45),
                                    style: StrokeStyle(lineWidth: 2, dash: [4, 3])
                                )
                            }
                        }
                        .frame(width: 34, height: 34)
                        Text(weekdaySymbol(day.date, narrow: true))
                            .font(AppFont.dmSans(12, .bold))
                            .fontWeight(day.isToday ? .heavy : .bold)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                    if index < week.count - 1 { Spacer(minLength: 0) }
                }
            }
        }
        .padding(20)
        .roundedBackground(AppColor.tertiary, 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day streak")
    }
}

private struct ProfileStatTile: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(AppFont.poppins(34))
                .foregroundStyle(AppColor.textPrimary)
            Text(label)
                .font(AppFont.dmSans(14))
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .roundedBackground(AppColor.backgroundPrimary, 20)
        .accessibilityElement(children: .combine)
    }
}

private struct DailyActivity: View {
    let week: [DayActivity]
    private let chartHeight: CGFloat = 100

    var body: some View {
        let maxStudied = max(week.map(\.studied).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text("Daily activity")
                    .font(AppFont.dmSans(16, .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Phrases studied")
                    .font(AppFont.dmSans(13))
                    .foregroundStyle(AppColor.textSecondary)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        if day.studied > 0 {
                            Text("\(day.studied)")
                                .font(AppFont.dmSans(12, .bold))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(day.studied == 0 ? AppColor.neutral200 : (day.isToday ? AppColor.secondary : AppColor.primary))
                            .frame(height: day.studied > 0 ? chartHeight * CGFloat(day.studied) / CGFloat(maxStudied) : 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: chartHeight + 22)
            HStack(spacing: 10) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    Text(weekdaySymbol(day.date, narrow: false))
                        .font(AppFont.dmSans(12, .semibold))
                        .foregroundStyle(day.isToday ? AppColor.textPrimary : AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .roundedBackground(AppColor.backgroundPrimary, 24)
        .accessibilityElement(children: .combine)
    }
}

private struct AllTimeStats: View {
    let uiState: ProfileUiState

    var body: some View {
        HStack(spacing: 0) {
            AllTimeStat(value: uiState.totalPhrases, label: "Total phrases")
            Rectangle().fill(AppColor.neutral200).frame(width: 1, height: 40)
            AllTimeStat(value: uiState.favorites, label: "Favorites")
            Rectangle().fill(AppColor.neutral200).frame(width: 1, height: 40)
            AllTimeStat(value: uiState.languagePairs, label: "Language pairs")
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .roundedBackground(AppColor.backgroundPrimary, 24)
    }
}

private struct AllTimeStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(AppFont.poppins(28))
                .foregroundStyle(AppColor.textPrimary)
            Text(label)
                .font(AppFont.dmSans(13))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct Achievements: View {
    let achievements: [Achievement]

    var body: some View {
        if !achievements.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Achievements")
                    .font(AppFont.dmSans(16, .bold))
                    .foregroundStyle(AppColor.textPrimary)
                HStack(alignment: .top, spacing: 10) {
                    ForEach(achievements, id: \.title) { achievement in
                        VStack(spacing: 8) {
                            Image(systemName: "medal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(achievement.unlocked ? AppColor.textPrimary : AppColor.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(achievement.unlocked ? AppColor.tertiary : AppColor.backgroundSecondary))
                            Text(achievement.title)
                                .font(AppFont.dmSans(13, .semibold))
                                .foregroundStyle(achievement.unlocked ? AppColor.textPrimary : AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                            if !achievement.unlocked {
                                Text(achievement.detail)
                                    .font(AppFont.dmSans(11))
                                    .foregroundStyle(AppColor.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .roundedBackground(AppColor.backgroundPrimary, 20)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(achievement.title), " + (achievement.unlocked ? "unlocked" : "locked: \(achievement.detail)"))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct EditProfileSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onDismiss: () -> Void

    @State private var bio = ""
    @State private var bioLoaded = false
    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        let uiState = viewModel.uiState
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Edit profile")
                    .font(AppFont.poppins(24))
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PlainTextButton(text: "Cancel", color: AppColor.textBody, weight: .bold, action: onDismiss)
            }

            HStack(spacing: 16) {
                ProfileAvatar(username: uiState.username, size: 80, photo: uiState.photo)
                VStack(alignment: .leading, spacing: 4) {
                    // System photo picker: no photo library permission needed.
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        HStack(spacing: 8) {
                            if uiState.isSavingPhoto {
                                ProgressView().tint(AppColor.textPrimary).controlSize(.small)
                            } else {
                                Image(systemName: "camera").font(.system(size: 15, weight: .medium))
                            }
                            Text("Change photo").font(AppFont.dmSans(14, .bold))
                        }
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Capsule().fill(AppColor.backgroundPrimary))
                        .overlay(Capsule().strokeBorder(AppColor.neutral300, lineWidth: 1.5))
                    }
                    .disabled(uiState.isSavingPhoto)
                    if uiState.photo != nil && !uiState.isSavingPhoto {
                        PlainTextButton(text: "Remove photo", color: AppColor.textSecondary, fontSize: 13, weight: .bold) {
                            viewModel.savePhoto(nil)
                        }
                    }
                }
            }
            if let photoError = uiState.photoError {
                Text(photoError).font(AppFont.dmSans(14)).foregroundStyle(AppColor.error)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(AppFont.dmSans(13, .bold))
                    .foregroundStyle(AppColor.textSecondary)
                OutlinedField(
                    text: Binding(get: { viewModel.uiState.usernameDraft }, set: viewModel.onUsernameDraftChange),
                    prefix: "@",
                    isError: uiState.usernameDraftProblem != nil || uiState.usernameAvailability == .taken,
                    keyboard: .asciiCapable,
                    autocapitalization: .never,
                    autocorrection: false
                )
                let name = uiState.usernameDraft
                let hint: (text: String, color: Color) = {
                    if let problem = uiState.usernameDraftProblem { return (problem, AppColor.error) }
                    switch uiState.usernameAvailability {
                    case .checking: return ("Checking @\(name)…", AppColor.textSecondary)
                    case .taken: return ("@\(name) is taken", AppColor.error)
                    case .available: return ("@\(name) is available", AppColor.success)
                    case .checkFailed: return ("Couldn't check right now. We'll check when you save.", AppColor.textSecondary)
                    case .unknown: return ("If you change it, your old username becomes free for others to take.", AppColor.textSecondary)
                    }
                }()
                Text(hint.text).font(AppFont.dmSans(12)).foregroundStyle(hint.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Bio")
                    .font(AppFont.dmSans(13, .bold))
                    .foregroundStyle(AppColor.textSecondary)
                OutlinedField(
                    text: Binding(get: { bio }, set: { if $0.count <= UserProfileRepository.bioMaxLength { bio = $0 } }),
                    placeholder: "Tell others about your language learning journey…",
                    minLines: 3,
                    maxLines: 5
                )
                Text("\(bio.count)/\(UserProfileRepository.bioMaxLength)")
                    .font(AppFont.dmSans(12))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let bioError = uiState.bioError {
                Text(bioError).font(AppFont.dmSans(14)).foregroundStyle(AppColor.error)
            }

            PrimaryPillButton(
                text: uiState.isSavingBio ? "Saving…" : "Save changes",
                enabled: !uiState.isSavingBio &&
                    uiState.usernameAvailability != .checking &&
                    uiState.usernameAvailability != .taken &&
                    uiState.usernameDraftProblem == nil
            ) {
                viewModel.saveProfile(bio: bio, onSaved: onDismiss)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .onAppear {
            if !bioLoaded {
                bioLoaded = true
                bio = viewModel.uiState.bio
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            pickedPhoto = nil
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                let encoded = await Task.detached { data.flatMap(UserPhotos.encode) }.value
                if let encoded { viewModel.savePhoto(encoded) } else { viewModel.onPhotoUnreadable() }
            }
        }
    }
}

/**
 * Confirms account deletion. Firebase needs a fresh sign-in to delete an account, so email
 * accounts re-enter their password and Google accounts pick their Google account again.
 */
private struct DeleteAccountDialog: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onDismiss: () -> Void
    let onConfirmPassword: (String) -> Void
    let onConfirmGoogle: () -> Void

    @State private var password = ""

    var body: some View {
        let usesGoogle = viewModel.usesGoogle
        let deleting = viewModel.uiState.isDeleting
        AppDialog(title: "Delete your account?") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This permanently deletes your account, username, saved phrases, study history, friends and suggestions. It can't be undone.")
                if !usesGoogle {
                    DialogTextField(label: "Password", text: $password, secure: true, enabled: !deleting)
                } else {
                    Text("You'll confirm with your Google account.")
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textSecondary)
                }
                if let error = viewModel.uiState.deleteError {
                    Text(error)
                        .font(AppFont.dmSans(14, .semibold))
                        .foregroundStyle(AppColor.error)
                }
            }
        } buttons: {
            DialogButton(text: "Cancel", enabled: !deleting, action: onDismiss)
            DialogButton(
                text: "Delete account",
                color: AppColor.error,
                enabled: !deleting && (usesGoogle || !password.isEmpty),
                loading: deleting
            ) {
                if usesGoogle { onConfirmGoogle() } else { onConfirmPassword(password) }
            }
        }
    }
}

/** "M" (narrow) or "Mon" (short) in the phone's language. */
private func weekdaySymbol(_ date: Date, narrow: Bool) -> String {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date) - 1
    let symbols = narrow ? calendar.veryShortWeekdaySymbols : calendar.shortWeekdaySymbols
    return symbols[weekday]
}
