import Foundation
import Combine

enum SessionState {
    case loading, signedOut, needsUsername, ready
}

/**
 * Decides where the app should open: login, username setup (signed in but no username yet),
 * or the main app (viewmodel/SessionViewModel.kt).
 */
@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var state: SessionState = .loading

    private let userProfileRepository = UserProfileRepository.shared
    private var recheckTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init() {
        refresh()
    }

    deinit {
        recheckTask?.cancel()
        refreshTask?.cancel()
    }

    /** Re-checks auth + profile. `onResolved` is called once the new state is known. */
    func refresh(onResolved: ((SessionState) -> Void)? = nil) {
        recheckTask?.cancel()
        guard let uid = AuthManager.getCurrentUserId() else {
            resolve(.signedOut, onResolved)
            return
        }
        state = .loading
        refreshTask = Task {
            let (username, error) = await userProfileRepository.fetchUsername(uid: uid)
            if error != nil {
                // Couldn't read the profile (offline, or the request was rejected). Don't lock
                // people out, but keep checking until we get a real answer.
                resolve(.ready, onResolved)
                scheduleRecheck(uid)
            } else {
                resolve(username.isNullOrBlank ? .needsUsername : .ready, onResolved)
            }
        }
    }

    /** Retries the username check in the background until it gets a real answer. */
    private func scheduleRecheck(_ uid: String) {
        recheckTask?.cancel()
        recheckTask = Task {
            var wait: UInt64 = 5_000
            while !Task.isCancelled && AuthManager.getCurrentUserId() == uid {
                try? await Task.sleep(nanoseconds: wait * 1_000_000)
                if Task.isCancelled { return }
                let (name, error) = await userProfileRepository.fetchUsername(uid: uid)
                if error == nil {
                    // The main screen sends the user to username setup when this flips.
                    if name.isNullOrBlank { state = .needsUsername }
                    return
                }
                wait = min(wait * 2, 60_000)
            }
        }
    }

    func onUsernameClaimed() {
        state = .ready
    }

    private func resolve(_ next: SessionState, _ onResolved: ((SessionState) -> Void)?) {
        state = next
        onResolved?(next)
    }
}
