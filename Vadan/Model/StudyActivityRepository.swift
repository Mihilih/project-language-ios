import Foundation
import FirebaseFirestore

/**
 * Per-day study log at `users/{uid}/studyDays/{yyyy-MM-dd}` = `{ date, count }`
 * (model/StudyActivityRepository.kt). `count` is the number of cards studied that day; it
 * powers the profile streak and daily activity chart.
 */
enum StudyActivityRepository {
    /** ISO yyyy-MM-dd in the phone's time zone, like Java's LocalDate.toString(). */
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    static func logStudied(cards: Int) {
        guard let uid = AuthManager.getCurrentUserId(), cards > 0 else { return }
        let today = dayString(Date()) // sorts lexicographically
        Backend.db.collection("users").document(uid)
            .collection("studyDays").document(today)
            .setData([
                "date": today,
                "count": FieldValue.increment(Int64(cards)),
                "updatedAt": FieldValue.serverTimestamp(),
            ], merge: true)
    }

    /** Cards studied per day since `from` (inclusive), keyed by yyyy-MM-dd. */
    static func studyDaysSince(uid: String, from: Date) async -> [String: Int] {
        do {
            let snapshot = try await Backend.db.collection("users").document(uid)
                .collection("studyDays")
                .whereField("date", isGreaterThanOrEqualTo: dayString(from))
                .getDocuments()
            var days: [String: Int] = [:]
            for doc in snapshot.documents {
                let data = doc.data()
                let raw = data.string("date") ?? doc.documentID
                // Only well-formed dates count (Android parses them with LocalDate).
                guard let date = dayFormatter.date(from: raw) else { continue }
                days[dayString(date)] = data.int("count") ?? 0
            }
            return days
        } catch {
            return [:]
        }
    }
}
