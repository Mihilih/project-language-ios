import Foundation
import Combine

/** Where a tapped notification should take the user. */
struct NotificationTarget: Equatable {
    let tab: FriendsTab
    /** Opens this suggestion's detail view when set. */
    var suggestionId: String? = nil
}

/**
 * Holds the destination of the notification that opened (or resumed) the app until the UI is
 * ready to show it — e.g. after the session check, or once the user has signed in
 * (notifications/NotificationRouter.kt).
 *
 * The `type` values match what the Cloud Functions send in the FCM data payload.
 */
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    static let extraType = "type"
    static let extraSuggestionId = "suggestionId"

    @Published private(set) var pending: NotificationTarget?

    /** Reads a tapped notification's payload. Returns true if it came from one of ours. */
    @discardableResult
    func handle(userInfo: [AnyHashable: Any]) -> Bool {
        guard let target = Self.targetFor(
            type: userInfo[Self.extraType] as? String,
            suggestionId: userInfo[Self.extraSuggestionId] as? String
        ) else { return false }
        pending = target
        return true
    }

    func consume() {
        pending = nil
    }

    static func targetFor(type: String?, suggestionId: String?) -> NotificationTarget? {
        switch type {
        case "friend_request": return NotificationTarget(tab: .requests)
        case "friend_accepted": return NotificationTarget(tab: .friends)
        case "suggestion":
            return NotificationTarget(tab: .suggestions, suggestionId: suggestionId.flatMap { $0.isBlank ? nil : $0 })
        case "suggestion_saved": return NotificationTarget(tab: .suggestions)
        default: return nil
        }
    }
}
