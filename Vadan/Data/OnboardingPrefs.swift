import Foundation

/**
 * Remembers on this device whether the intro has been shown. Purely local: a reinstall
 * shows it again, which is fine for an intro.
 */
enum OnboardingPrefs {
    private static let keySeen = "onboarding.seen_v1"

    static func hasSeen() -> Bool { UserDefaults.standard.bool(forKey: keySeen) }

    static func markSeen() { UserDefaults.standard.set(true, forKey: keySeen) }
}

/** Whether someone has signed in on this device before, so Login can open on "Log in". */
enum AuthPrefs {
    private static let keyReturning = "auth.returning"

    static func isReturning() -> Bool { UserDefaults.standard.bool(forKey: keyReturning) }

    static func markReturning() { UserDefaults.standard.set(true, forKey: keyReturning) }
}
