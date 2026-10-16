import Foundation
import Combine

enum AuthMode { case signUp, logIn }

struct LoginUiState {
    static let minPassword = 8

    var mode: AuthMode = .signUp
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String? = nil
    /** Confirmation after "Forgot password?" sends the reset email. */
    var infoMessage: String? = nil
    var isSendingReset = false
    var isGoogleLoading = false

    var passwordLongEnough: Bool { password.count >= Self.minPassword }

    /** Same pattern as Android's Patterns.EMAIL_ADDRESS. */
    var emailLooksValid: Bool {
        let pattern = "^[a-zA-Z0-9+._%\\-]{1,256}@[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\.[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+$"
        return email.trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    /** The hint under the password field while signing up, as in the design. */
    var passwordHint: String {
        if password.isEmpty { return "At least \(Self.minPassword) characters" }
        if !passwordLongEnough {
            let left = Self.minPassword - password.count
            return left == 1 ? "1 more character needed" : "\(left) more characters needed"
        }
        return "Looks good"
    }
}

@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var uiState = LoginUiState()

    private var modeChosen = false

    /** Opens on "Log in" for people who've signed in on this device before. Only applied once. */
    func setInitialMode(returning: Bool) {
        if modeChosen { return }
        modeChosen = true
        uiState.mode = returning ? .logIn : .signUp
    }

    func setMode(_ mode: AuthMode) {
        modeChosen = true
        uiState.mode = mode
        uiState.errorMessage = nil
        uiState.infoMessage = nil
    }

    func onEmailChange(_ value: String) {
        uiState.email = value
        uiState.errorMessage = nil
        uiState.infoMessage = nil
    }

    func onPasswordChange(_ value: String) {
        uiState.password = value
        uiState.errorMessage = nil
    }

    func submit(onSuccess: @escaping () -> Void) {
        let state = uiState
        if state.isLoading { return }
        let email = state.email.trimmed

        let problem: String?
        if email.isEmpty || state.password.isEmpty {
            problem = "Enter your email and password."
        } else if !state.emailLooksValid {
            problem = "Enter a valid email address."
        } else if state.mode == .signUp && !state.passwordLongEnough {
            problem = "Use a password with at least \(LoginUiState.minPassword) characters."
        } else {
            problem = nil
        }
        if let problem {
            uiState.errorMessage = problem
            uiState.infoMessage = nil
            return
        }

        uiState.isLoading = true
        uiState.errorMessage = nil
        uiState.infoMessage = nil
        Task {
            let (success, message) = state.mode == .signUp
                ? await AuthManager.signUp(email: email, password: state.password)
                : await AuthManager.login(email: email, password: state.password)
            uiState.isLoading = false
            uiState.errorMessage = success ? nil : message
            if success { onSuccess() }
        }
    }

    func onGoogleStarted() {
        uiState.isGoogleLoading = true
        uiState.errorMessage = nil
        uiState.infoMessage = nil
    }

    /** `error` is nil when the user just closed Google's sign-in screen. */
    func onGoogleFailed(_ error: String?) {
        uiState.isGoogleLoading = false
        uiState.errorMessage = error
    }

    func signInWithGoogle(_ tokens: GoogleTokens, onSuccess: @escaping () -> Void) {
        Task {
            let (success, message) = await AuthManager.signInWithGoogle(tokens)
            uiState.isGoogleLoading = false
            uiState.errorMessage = success ? nil : message
            if success { onSuccess() }
        }
    }

    func sendPasswordReset() {
        let state = uiState
        if state.isSendingReset { return }
        if !state.emailLooksValid {
            uiState.errorMessage = "Enter your email above, then tap “Forgot password?” again."
            uiState.infoMessage = nil
            return
        }
        let email = state.email.trimmed
        uiState.isSendingReset = true
        uiState.errorMessage = nil
        uiState.infoMessage = nil
        Task {
            let (success, message) = await AuthManager.sendPasswordReset(email: email)
            uiState.isSendingReset = false
            uiState.infoMessage = success
                ? "If there's an account for \(email), a reset link is on its way. Check your inbox."
                : nil
            uiState.errorMessage = success ? nil : message
        }
    }
}
