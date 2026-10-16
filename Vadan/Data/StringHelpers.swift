import Foundation

// Small helpers so the Swift code can read like the Kotlin it mirrors.

extension String {
    /** Kotlin's trim(): drops leading and trailing whitespace. */
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /** Kotlin's isBlank(): empty or only whitespace. */
    var isBlank: Bool { trimmed.isEmpty }

    /** Kotlin's isNotBlank(). */
    var isNotBlank: Bool { !isBlank }

    /** Kotlin's take(n): the first n characters. */
    func take(_ n: Int) -> String { String(prefix(max(0, n))) }

    /** Kotlin's equals(other, ignoreCase = true). */
    func equalsIgnoreCase(_ other: String?) -> Bool {
        guard let other else { return false }
        return caseInsensitiveCompare(other) == .orderedSame
    }

    /** Kotlin's contains(other, ignoreCase = true). */
    func containsIgnoreCase(_ other: String) -> Bool {
        other.isEmpty || range(of: other, options: .caseInsensitive) != nil
    }

    /** The first character upper-cased, or "?" (avatar initials). */
    var initial: String {
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}

extension Optional where Wrapped == String {
    /** Kotlin's orEmpty(). */
    var orEmpty: String { self ?? "" }

    /** Kotlin's isNullOrBlank(). */
    var isNullOrBlank: Bool { self?.isBlank ?? true }
}

/** "1 phrase" / "N phrases". */
func phraseCount(_ n: Int) -> String { n == 1 ? "1 phrase" : "\(n) phrases" }
