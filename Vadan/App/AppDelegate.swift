import UIKit
import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCrashlytics
import GoogleSignIn

/** App start-up (ProjectLanguage.kt + MainActivity.onCreate on Android). */
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Attest every Firebase call (Firestore, Functions) so only this app can use the backend.
        // Must be installed before FirebaseApp.configure().
        AppCheckSetup.install()
        FirebaseApp.configure()
        CrashReporting.install()
        AppNotifications.shared.install()
        AppNotifications.shared.registerIfAuthorized()
        FcmTokenRegistrar.syncCurrentToken()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let host = RootHostingController(rootView: AppRootView())
        host.view.backgroundColor = UIColor(named: "LaunchBackground")
        StatusBarController.shared.host = host
        window.rootViewController = host
        window.tintColor = UIColor(named: "AccentColor")
        self.window = window
        window.makeKeyAndVisible()

        // Opened by tapping a notification while the app wasn't running.
        if let response = connectionOptions.notificationResponse {
            NotificationRouter.shared.handle(userInfo: response.notification.request.content.userInfo)
        }
        handle(connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handle(URLContexts)
    }

    /** Google Sign-In returns to the app through its URL scheme. */
    private func handle(_ contexts: Set<UIOpenURLContext>) {
        for context in contexts {
            _ = GIDSignIn.sharedInstance.handle(context.url)
        }
    }
}

/**
 * App Check: debug builds (the Simulator and Xcode installs) use the debug provider with the
 * token from Config/AppCheck.xcconfig, which must also be registered in Firebase console →
 * App Check → Apps → Vadan (iOS) → Manage debug tokens.
 * Release builds use App Attest (needs a paid Apple Developer account and the App Attest
 * capability), falling back to DeviceCheck.
 */
enum AppCheckSetup {
    static func install() {
        #if DEBUG
        useRegisteredDebugToken()
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(VadanAppCheckProviderFactory())
        #endif
    }

    #if DEBUG
    /**
     * The debug provider uses the scheme's FIRAAppCheckDebugToken environment variable, but
     * Xcode only passes that when it launches the app — opening Vadan from the home screen, or
     * after setup.sh rebuilt the scheme, falls back to a random token that Firebase rejects
     * (translation, audio, friends and Firestore all fail). So the registered token is also
     * baked into the debug build (Config/AppCheck.xcconfig → Info.plist) and stored where the
     * provider looks when there's no environment variable.
     */
    private static func useRegisteredDebugToken() {
        let fromEnvironment = ProcessInfo.processInfo.environment["FIRAAppCheckDebugToken"]
        let fromBuild = (Bundle.main.object(forInfoDictionaryKey: "AppCheckDebugToken") as? String)?
            .trimmingCharacters(in: .whitespaces)
        let token = [fromEnvironment, fromBuild].compactMap { $0 }.first { !$0.isEmpty && !$0.hasPrefix("$(") }
        guard let token else {
            print("⚠️ App Check: no debug token set. Add it to Config/AppCheck.xcconfig (see README), or translation and friends will be rejected.")
            return
        }
        // Older and newer SDKs read different keys; set both.
        for key in ["GACAppCheckDebugToken", "FIRAAppCheckDebugToken"] {
            UserDefaults.standard.set(token, forKey: key)
        }
        print("App Check: using debug token …\(token.suffix(6))")
    }
    #endif
}

final class VadanAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if let provider = AppAttestProvider(app: app) { return provider }
        return DeviceCheckProvider(app: app)
    }
}

/**
 * Crashlytics setup. Crashes are reported automatically once the SDK is in the app; this adds
 * context to each report (CrashReporting.kt):
 *  - the signed-in user's Firebase uid (no email or username);
 *  - whether it came from a debug build, so test crashes can be filtered out.
 */
enum CrashReporting {
    private static var authHandle: AuthStateDidChangeListenerHandle?

    static func install() {
        let crashlytics = Crashlytics.crashlytics()
        #if DEBUG
        crashlytics.setCustomValue(true, forKey: "debug_build")
        #else
        crashlytics.setCustomValue(false, forKey: "debug_build")
        #endif
        authHandle = Auth.auth().addStateDidChangeListener { _, user in
            crashlytics.setUserID(user?.uid ?? "")
        }
    }
}
