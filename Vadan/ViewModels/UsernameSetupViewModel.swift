import Foundation
import Combine

enum UsernameAvailability { case unknown, checking, available, taken, checkFailed }

struct UsernameSetupUiState {
    var username = ""
    var isSaving = false
    /** What's wrong with the format, once something's typed. */
    var validationMessage: String? = nil
    var availability: UsernameAvailability = .unknown
    /** Free alternatives shown under "AVAILABLE INSTEAD" when the name is taken. */
    var alternatives: [String] = []
    /** Error from the server (e.g. taken by someone in the last second). */
    var errorMessage: String? = nil

    /** Offline checks don't block: the claim transaction is the real check. */
    var canSubmit: Bool {
        !isSaving && !username.isBlank && validationMessage == nil &&
            (availability == .available || availability == .checkFailed)
    }
}

/** "Pick a username" (viewmodel/UsernameSetupViewModel.kt). */
@MainActor
final class UsernameSetupViewModel: ObservableObject {
    private static let checkPauseNanos: UInt64 = 350_000_000

    @Published private(set) var uiState = UsernameSetupUiState()

    private let repository = UserProfileRepository.shared
    private var checkTask: Task<Void, Never>?

    /** Usernames never contain whitespace or a leading @; drop them as the user types. */
    static func clean(_ value: String) -> String {
        let withoutAt = value.hasPrefix("@") ? String(value.dropFirst()) : value
        return String(withoutAt.filter { !$0.isWhitespace }).take(UserProfileRepository.maxLength)
    }

    func onUsernameChange(_ value: String) {
        let cleaned = Self.clean(value)
        let problem = cleaned.isEmpty ? nil : UserProfileRepository.validateUsername(cleaned)
        uiState.username = cleaned
        uiState.validationMessage = problem
        uiState.availability = (cleaned.isEmpty || problem != nil) ? .unknown : .checking
        uiState.alternatives = []
        uiState.errorMessage = nil
        checkTask?.cancel()
        if cleaned.isEmpty || problem != nil { return }

        checkTask = Task {
            try? await Task.sleep(nanoseconds: Self.checkPauseNanos)
            if Task.isCancelled { return }
            let available = await repository.isUsernameAvailable(cleaned)
            if Task.isCancelled || uiState.username != cleaned { return }
            uiState.availability = Self.availability(available)
            if available == false {
                var free: [String] = []
                for candidate in candidates(cleaned) where free.count < 3 {
                    if await repository.isUsernameAvailable(candidate) == true { free.append(candidate) }
                }
                if !Task.isCancelled && uiState.username == cleaned {
                    uiState.alternatives = free
                }
            }
        }
    }

    func submit(onSuccess: @escaping () -> Void) {
        let state = uiState
        guard state.canSubmit else { return }
        uiState.isSaving = true
        uiState.errorMessage = nil
        Task {
            let (success, message) = await repository.claimUsername(state.username)
            uiState.isSaving = false
            uiState.errorMessage = success ? nil : message
            if !success && message?.contains("taken") == true { uiState.availability = .taken }
            if success { onSuccess() }
        }
    }

    /** true / false / couldn't check → the availability shown under the field. */
    static func availability(_ available: Bool?) -> UsernameAvailability {
        switch available {
        case .some(true): return .available
        case .some(false): return .taken
        case .none: return .checkFailed
        }
    }

    /** A few variations on `name` that are still valid usernames, like the design suggests. */
    private func candidates(_ name: String) -> [String] {
        var base = name
        while let last = base.last, last == "." || last == "_" { base.removeLast() }
        if base.isEmpty { base = "learner" }
        return [
            "\(base)2",
            base.contains("_") ? base.replacingOccurrences(of: "_", with: ".") : "\(base)_learns",
            "\(base).lang",
            "\(base)\(Int.random(in: 10...99))",
        ]
        .map { $0.take(UserProfileRepository.maxLength) }
        .filter { $0 != name && UserProfileRepository.validateUsername($0) == nil }
        .uniqued()
    }
}
