import Foundation
import UIKit
import FirebaseCore
import GoogleSignIn

/** The Google tokens Firebase Auth signs in with. */
struct GoogleTokens {
    let idToken: String
    let accessToken: String
}

/**
 * Shows Google's sign-in screen and returns tokens Firebase Auth can sign in with
 * (model/GoogleSignIn.kt on Android).
 *
 * Needs, in the Firebase console: Authentication → Sign-in method → Google enabled, and a
 * GoogleService-Info.plist downloaded after that (it carries the CLIENT_ID and the
 * REVERSED_CLIENT_ID URL scheme; see scripts/setup.sh).
 */
@MainActor
enum GoogleSignInHelper {
    /** The user backed out — not an error worth showing. */
    struct Cancelled: Error {}

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func getTokens() async -> Result<GoogleTokens, Error> {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            return .failure(Failure(message: "Google sign-in isn't set up for this app yet."))
        }
        guard let presenter = topViewController() else {
            return .failure(Failure(message: "Couldn't sign in with Google. Please try again."))
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                return .failure(Failure(message: "Couldn't sign in with Google. Please try again."))
            }
            return .success(GoogleTokens(idToken: idToken, accessToken: result.user.accessToken.tokenString))
        } catch {
            if let signInError = error as? GIDSignInError, signInError.code == .canceled {
                return .failure(Cancelled())
            }
            return .failure(Failure(message: "Couldn't sign in with Google. Please try again."))
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ??
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
