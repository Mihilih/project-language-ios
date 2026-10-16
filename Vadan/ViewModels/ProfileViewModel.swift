import Foundation
import Combine

struct DayActivity: Equatable {
    let date: Date
    let studied: Int
    let isToday: Bool
    let isFuture: Bool
}

struct Achievement: Equatable {
    let title: String
    let detail: String
    let unlocked: Bool
}

struct ProfileUiState {
    var username = ""
    var email = ""
    var bio = ""
    /** Base64 JPEG, or nil for the initial-letter avatar. */
    var photo: String? = nil
    var isSavingPhoto = false
    var photoError: String? = nil
    var isLoggingOut = false
    var isDeleting = false
    var deleteError: String? = nil
    var isLoadingStats = true
    var isSavingBio = false
    var bioError: String? = nil
    /** Live check of the name typed in Edit profile (unknown while it's unchanged or invalid). */
    var usernameDraft = ""
    var usernameDraftProblem: String? = nil
    var usernameAvailability: UsernameAvailability = .unknown
    var currentStreak = 0
    /** Monday → Sunday of the current week. */
    var week: [DayActivity] = []
    var newPhrasesThisWeek = 0
    var studiedThisWeek = 0
    var totalPhrases = 0
    var favorites = 0
    var languagePairs = 0
    var achievements: [Achievement] = []
}

/** The Profile tab (viewmodel/ProfileViewModel.kt). */
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var uiState = ProfileUiState(email: AuthManager.getCurrentUserEmail() ?? "")

    private let repository = UserProfileRepository.shared
    private var phrases: [Phrase]?
    private var studyDays: [String: Int]?
    private var statsGeneration = 0
    private var usernameCheck: Task<Void, Never>?

    init() {
        if let uid = AuthManager.getCurrentUserId() {
            Task {
                let profile = await repository.fetchProfile(uid: uid)
                uiState.username = profile.username
                uiState.bio = profile.bio
                uiState.photo = profile.photo
                UserPhotos.shared.set(uid, profile.photo)
            }
        }
        // Stats load from the screen's appear effect, so they refresh after a study session.
    }

    /** Reloads phrases + study log; call when the screen is shown so new study sessions appear. */
    func refreshStats() {
        guard let uid = AuthManager.getCurrentUserId() else {
            uiState.isLoadingStats = false
            return
        }
        phrases = nil
        studyDays = nil
        statsGeneration += 1
        let generation = statsGeneration
        Task {
            let result = await PhraseRepository.getPhrases(userId: uid)
            guard generation == statsGeneration else { return }
            phrases = result
            publishStats()
        }
        Task {
            // 60 days is enough to show a long streak without reading the whole history.
            let from = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
            let result = await StudyActivityRepository.studyDaysSince(uid: uid, from: from)
            guard generation == statsGeneration else { return }
            studyDays = result
            publishStats()
        }
    }

    /** Edit profile opened: start the username field from the current name. */
    func startEditing() {
        usernameCheck?.cancel()
        uiState.usernameDraft = uiState.username
        uiState.usernameDraftProblem = nil
        uiState.usernameAvailability = .unknown
        uiState.bioError = nil
    }

    func onUsernameDraftChange(_ value: String) {
        let cleaned = UsernameSetupViewModel.clean(value)
        let unchanged = cleaned == uiState.username
        let problem = (unchanged || cleaned.isEmpty) ? nil : UserProfileRepository.validateUsername(cleaned)
        // Only the capitalisation changed: it's still their own claim, no need to look it up.
        let sameName = cleaned.equalsIgnoreCase(uiState.username)
        uiState.usernameDraft = cleaned
        uiState.usernameDraftProblem = problem
        if unchanged || cleaned.isEmpty || problem != nil {
            uiState.usernameAvailability = .unknown
        } else if sameName {
            uiState.usernameAvailability = .available
        } else {
            uiState.usernameAvailability = .checking
        }
        uiState.bioError = nil
        usernameCheck?.cancel()
        if uiState.usernameAvailability != .checking { return }
        usernameCheck = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            let available = await repository.isUsernameAvailable(cleaned)
            if Task.isCancelled || uiState.usernameDraft != cleaned { return }
            uiState.usernameAvailability = UsernameSetupViewModel.availability(available)
        }
    }

    /** Saves the bio and, if it was edited, the new username (which frees the old one). */
    func saveProfile(bio: String, onSaved: @escaping () -> Void) {
        let state = uiState
        let newName = state.usernameDraft.trimmed
        let renaming = !newName.isEmpty && newName != state.username
        if renaming {
            let problem = UserProfileRepository.validateUsername(newName)
            if problem != nil || state.usernameAvailability == .taken {
                uiState.bioError = problem ?? "@\(newName) is already taken"
                return
            }
        }
        uiState.isSavingBio = true
        uiState.bioError = nil
        if !renaming { return saveBio(bio, onSaved) }
        Task {
            let (success, error) = await repository.changeUsername(newName)
            if !success {
                uiState.isSavingBio = false
                uiState.bioError = error
                if error?.contains("taken") == true { uiState.usernameAvailability = .taken }
                return
            }
            uiState.username = newName
            uiState.usernameDraft = newName
            saveBio(bio, onSaved)
        }
    }

    private func saveBio(_ bio: String, _ onSaved: @escaping () -> Void) {
        if bio.trimmed == uiState.bio {
            uiState.isSavingBio = false
            return onSaved()
        }
        uiState.isSavingBio = true
        uiState.bioError = nil
        Task {
            let (success, error) = await repository.updateBio(bio)
            uiState.isSavingBio = false
            if success { uiState.bio = bio.trimmed.take(UserProfileRepository.bioMaxLength) }
            uiState.bioError = success ? nil : error
            if success { onSaved() }
        }
    }

    /** Saves a new photo (already encoded) or removes it (`photo` = nil). */
    func savePhoto(_ photo: String?) {
        guard let uid = AuthManager.getCurrentUserId() else { return }
        uiState.isSavingPhoto = true
        uiState.photoError = nil
        Task {
            let (success, error) = await repository.updatePhoto(photo)
            uiState.isSavingPhoto = false
            if success { uiState.photo = photo }
            uiState.photoError = success ? nil : error
            if success { UserPhotos.shared.set(uid, photo) }
        }
    }

    func onPhotoUnreadable() {
        uiState.photoError = "Couldn't use that image. Try another one."
    }

    func clearBioError() { uiState.bioError = nil }

    private func publishStats() {
        guard let phrases, let days = studyDays else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date())
        // Monday of this week (ISO weeks start on Monday, like Android's DayOfWeek.MONDAY).
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday … 7 = Saturday
        let daysSinceMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!

        func studied(_ date: Date) -> Int { days[StudyActivityRepository.dayString(date)] ?? 0 }

        let week = (0..<7).map { offset -> DayActivity in
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            return DayActivity(date: date, studied: studied(date), isToday: date == today, isFuture: date > today)
        }

        // Streak counts back from today; if today isn't done yet, yesterday still keeps it alive.
        var cursor = studied(today) > 0 ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var streak = 0
        while studied(cursor) > 0 {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }

        let mondayMillis = Int64(monday.timeIntervalSince1970 * 1000)
        let newThisWeek = phrases.filter { $0.timestamp >= mondayMillis }.count
        let total = phrases.count
        let pairs = Set(
            phrases
                .filter { $0.sourceLang.isNotBlank && $0.targetLang.isNotBlank }
                .map { "\($0.sourceLang.lowercased())|\($0.targetLang.lowercased())" }
        ).count

        uiState.isLoadingStats = false
        uiState.currentStreak = streak
        uiState.week = week
        uiState.newPhrasesThisWeek = newThisWeek
        uiState.studiedThisWeek = week.reduce(0) { $0 + $1.studied }
        uiState.totalPhrases = total
        uiState.favorites = phrases.filter(\.isFavorite).count
        uiState.languagePairs = pairs
        uiState.achievements = [
            Achievement(title: "First phrase", detail: "Save your first phrase", unlocked: total >= 1),
            Achievement(title: "Collector", detail: "Save 25 phrases", unlocked: total >= 25),
            Achievement(title: "On a roll", detail: "Reach a 7-day streak", unlocked: streak >= 7),
        ]
    }

    /** Google accounts confirm deletion with Google instead of a password. */
    var usesGoogle: Bool { AuthManager.usesGoogle() }

    func onDeleteStarted() {
        uiState.isDeleting = true
        uiState.deleteError = nil
    }

    func onDeleteFailed(_ error: String?) {
        uiState.isDeleting = false
        uiState.deleteError = error
    }

    func clearDeleteError() { uiState.deleteError = nil }

    /**
     * Deletes the account after re-checking the password / Google sign-in. The backend's
     * onUserDeleted trigger removes the user's data; `onDeleted` restarts the app.
     */
    func deleteAccount(password: String?, google: GoogleTokens?, onDeleted: @escaping () -> Void) {
        uiState.isDeleting = true
        uiState.deleteError = nil
        Task {
            let (success, message) = await AuthManager.deleteAccount(password: password, google: google)
            uiState.isDeleting = false
            uiState.deleteError = success ? nil : message
            if success { onDeleted() }
        }
    }

    func logout(onLoggedOut: @escaping () -> Void) {
        if uiState.isLoggingOut { return }
        uiState.isLoggingOut = true
        // Unregister this device's push token while we're still signed in (Firestore rules need
        // the auth), then sign out.
        FcmTokenRegistrar.unregisterCurrentToken { [weak self] in
            AuthManager.logout()
            self?.uiState.isLoggingOut = false
            onLoggedOut()
        }
    }
}
