import Foundation
import FirebaseAuth

/** Firebase Auth wrapper with the login screen's friendly messages (model/AuthManager.kt). */
enum AuthManager {
    private static var auth: Auth { Auth.auth() }

    static func signUp(email: String, password: String) async -> (Bool, String?) {
        do {
            _ = try await auth.createUser(withEmail: email, password: password)
            return (true, nil)
        } catch {
            return (false, friendlyError(error, signingUp: true))
        }
    }

    static func login(email: String, password: String) async -> (Bool, String?) {
        do {
            _ = try await auth.signIn(withEmail: email, password: password)
            return (true, nil)
        } catch {
            return (false, friendlyError(error, signingUp: false))
        }
    }

    /** Signs in (or creates the account) with Google tokens from GoogleSignInHelper. */
    static func signInWithGoogle(_ tokens: GoogleTokens) async -> (Bool, String?) {
        let credential = GoogleAuthProvider.credential(withIDToken: tokens.idToken, accessToken: tokens.accessToken)
        do {
            _ = try await auth.signIn(with: credential)
            return (true, nil)
        } catch {
            switch kind(of: error) {
            case .network: return (false, "You're offline. Try again when you reconnect.")
            case .collision:
                return (false, "This email already has a password account. Log in with your email and password.")
            default: return (false, "Couldn't sign in with Google. Please try again.")
            }
        }
    }

    /** True if the signed-in account uses Google sign-in rather than a password. */
    static func usesGoogle() -> Bool {
        let providers = auth.currentUser?.providerData.map(\.providerID) ?? []
        return providers.contains("google.com") && !providers.contains("password")
    }

    /**
     * Deletes the signed-in account. Firebase requires a fresh sign-in first, so pass the
     * password (email accounts) or new Google tokens (Google accounts). The onUserDeleted
     * Cloud Function then wipes the user's Firestore data.
     */
    static func deleteAccount(password: String?, google: GoogleTokens?) async -> (Bool, String?) {
        guard let user = auth.currentUser else { return (false, "You're not signed in.") }
        let credential: AuthCredential
        if let google {
            credential = GoogleAuthProvider.credential(withIDToken: google.idToken, accessToken: google.accessToken)
        } else if let password, let email = user.email {
            credential = EmailAuthProvider.credential(withEmail: email, password: password)
        } else {
            return (false, "Enter your password to confirm.")
        }
        do {
            _ = try await user.reauthenticate(with: credential)
            try await user.delete()
            return (true, nil)
        } catch {
            switch kind(of: error) {
            case .invalidCredentials: return (false, "That password isn't right.")
            case .invalidUser: return (false, "That Google account isn't the one you're signed in with.")
            case .network: return (false, "You're offline. Try again when you reconnect.")
            case .tooManyRequests: return (false, "Too many attempts. Wait a minute and try again.")
            default: return (false, "Couldn't delete your account. Please try again.")
            }
        }
    }

    /** Emails a password-reset link. Reports success even for unknown emails (Firebase does too). */
    static func sendPasswordReset(email: String) async -> (Bool, String?) {
        do {
            try await auth.sendPasswordReset(withEmail: email)
            return (true, nil)
        } catch {
            if kind(of: error) == .network {
                return (false, "You're offline. Try again when you reconnect.")
            }
            return (false, "Couldn't send the reset email. Check the address and try again.")
        }
    }

    /** Firebase's own messages are technical; these are what the login screen shows. */
    private static func friendlyError(_ error: Error, signingUp: Bool) -> String {
        switch kind(of: error) {
        case .weakPassword: return "Use a stronger password with at least 8 characters."
        case .collision: return "There's already an account with that email. Log in instead."
        case .invalidUser, .invalidCredentials:
            return signingUp
                ? "Enter a valid email address."
                : "That email and password don't match. Try again or reset your password."
        case .network: return "You're offline. Try again when you reconnect."
        case .tooManyRequests: return "Too many attempts. Wait a minute and try again."
        case .other:
            return signingUp ? "Couldn't create your account. Please try again." : "Couldn't log in. Please try again."
        }
    }

    /** The same buckets as Android's FirebaseAuth exception classes. */
    private enum ErrorKind {
        case weakPassword, collision, invalidUser, invalidCredentials, network, tooManyRequests, other
    }

    private static func kind(of error: Error) -> ErrorKind {
        let ns = error as NSError
        guard ns.domain == "FIRAuthErrorDomain", let code = AuthErrorCode(rawValue: ns.code) else { return .other }
        switch code {
        case .weakPassword: return .weakPassword
        case .emailAlreadyInUse, .credentialAlreadyInUse, .accountExistsWithDifferentCredential: return .collision
        case .userNotFound, .userDisabled, .userTokenExpired, .invalidUserToken, .userMismatch: return .invalidUser
        case .invalidEmail, .wrongPassword, .invalidCredential, .missingEmail: return .invalidCredentials
        case .networkError: return .network
        case .tooManyRequests: return .tooManyRequests
        default: return .other
        }
    }

    static func logout() {
        try? auth.signOut()
    }

    static func getCurrentUserId() -> String? { auth.currentUser?.uid }

    static func getCurrentUserEmail() -> String? { auth.currentUser?.email }
}
