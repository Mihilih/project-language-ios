import Foundation
import FirebaseFirestore
import FirebaseMessaging

/**
 * Keeps this device's push token on the signed-in account (model/FcmTokenRegistrar.kt).
 * On iOS the FCM token only exists once APNs is set up (paid Apple Developer account and the
 * Push Notifications capability); until then the token calls fail quietly and this does nothing.
 */
enum FcmTokenRegistrar {
    private static let unregisterTimeout: TimeInterval = 3

    static func syncCurrentToken() {
        guard let uid = AuthManager.getCurrentUserId() else { return }
        Messaging.messaging().token { token, _ in
            guard let token else { return }
            register(uid: uid, token: token)
        }
    }

    static func registerToken(_ token: String) {
        guard let uid = AuthManager.getCurrentUserId() else { return }
        register(uid: uid, token: token)
    }

    /**
     * Removes this device's token from the signed-in user's private account doc so the account
     * stops getting notifications here after logout. Always calls `onComplete` exactly once,
     * on the main thread, after at most 3 seconds (Firestore writes don't complete offline),
     * so a network problem never blocks logging out.
     */
    static func unregisterCurrentToken(_ onComplete: @escaping () -> Void) {
        var completed = false
        let lock = NSLock()
        let finish = {
            lock.lock()
            let first = !completed
            completed = true
            lock.unlock()
            if first { DispatchQueue.main.async { onComplete() } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + unregisterTimeout) { finish() }

        guard let uid = AuthManager.getCurrentUserId() else {
            finish()
            return
        }
        Messaging.messaging().token { token, _ in
            guard let token, !token.isBlank else {
                finish()
                return
            }
            // setData(merge) instead of updateData: update fails if the doc doesn't exist yet.
            accountDoc(uid).setData(["fcmTokens": FieldValue.arrayRemove([token])], merge: true) { _ in
                finish()
            }
        }
    }

    private static func register(uid: String, token: String) {
        guard !token.isBlank else { return }
        accountDoc(uid).setData(["fcmTokens": FieldValue.arrayUnion([token])], merge: true)
    }

    /**
     * Push tokens live in `users/{uid}/private/account`, which only the owner (and Cloud
     * Functions) can read — the public `users/{uid}` profile is readable by every signed-in user.
     */
    private static func accountDoc(_ uid: String) -> DocumentReference {
        Backend.db.collection("users").document(uid).collection("private").document("account")
    }
}
