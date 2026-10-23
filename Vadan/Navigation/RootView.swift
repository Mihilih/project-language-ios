import SwiftUI

/** Where the app is, outside the tabs (the NavHost routes before "translation" on Android). */
enum AppRoute: Equatable {
    case onboarding, login, usernameSetup, learningLanguages, main
}

/**
 * Restarts the whole UI on log out, the equivalent of Android relaunching MainActivity: every
 * view model (and Firestore listener) from the old account goes away with it.
 */
@MainActor
final class AppRestarter: ObservableObject {
    static let shared = AppRestarter()
    @Published private(set) var generation = 0

    func restart() {
        SpeechRepository.shared.stop()
        generation += 1
    }
}

/** Top of the view tree: dialogs and the system toast sit above everything. */
struct AppRootView: View {
    @ObservedObject private var restarter = AppRestarter.shared
    @StateObject private var dialogs = DialogHost()
    @StateObject private var systemToast = SystemToast()

    var body: some View {
        MainScreen()
            .id(restarter.generation)
            .environmentObject(dialogs)
            .environmentObject(systemToast)
            .modifier(DialogOverlay(host: dialogs))
            .modifier(SystemToastOverlay(toast: systemToast))
            .onChange(of: restarter.generation) { _, _ in dialogs.dismiss() }
    }
}

/**
 * Decides where the app opens and moves between onboarding, login, setup and the tabs
 * (MainScreen in MainActivity.kt + NavGraph.kt).
 */
struct MainScreen: View {
    @StateObject private var session = SessionViewModel()
    /** Picked once, after the first auth/profile check; later changes navigate explicitly. */
    @State private var route: AppRoute?

    var body: some View {
        ZStack {
            switch route {
            case nil:
                // Same as the launch screen: stays up until we know where the app should open.
                SplashView()
            case .onboarding:
                OnboardingScreen {
                    OnboardingPrefs.markSeen()
                    // Same routing as a normal launch, now that the intro is out of the way.
                    switch session.state {
                    case .ready: go(.main)
                    case .needsUsername: go(.usernameSetup)
                    default: go(.login)
                    }
                }
            case .login:
                LoginScreen {
                    FcmTokenRegistrar.syncCurrentToken()
                    // New sign-ups (and older accounts without a username) go to setup first.
                    session.refresh { state in
                        go(state == .needsUsername ? .usernameSetup : .main)
                    }
                }
            case .usernameSetup:
                UsernameSetupScreen(
                    onUsernameClaimed: {
                        session.onUsernameClaimed()
                        // New account: ask what they're learning before the first Translate.
                        go(.learningLanguages)
                    },
                    // Back = "not this account": sign out and return to Login.
                    onBack: {
                        FcmTokenRegistrar.unregisterCurrentToken {
                            AuthManager.logout()
                            go(.login)
                        }
                    }
                )
            case .learningLanguages:
                LearningLanguagesScreen { go(.main) }
            case .main:
                MainTabsView(
                    onLoggedOut: {
                        // Start the app over instead of just navigating to Login, so nothing
                        // from the old account lingers for the next person who signs in.
                        AppRestarter.shared.restart()
                    }
                )
            }
        }
        .onChange(of: session.state, initial: true) { _, state in
            if route == nil && state != .loading {
                // First launch on this device: show the intro, which then routes like below.
                if !OnboardingPrefs.hasSeen() {
                    route = .onboarding
                } else {
                    switch state {
                    case .signedOut: route = .login
                    case .needsUsername: route = .usernameSetup
                    default: route = .main
                    }
                }
            } else if state == .needsUsername && route == .main {
                // The username check can only succeed late (it failed at launch, e.g.
                // offline). If this account has no username, send them to pick one.
                go(.usernameSetup)
            }
        }
    }

    private func go(_ next: AppRoute) {
        withAnimation(.easeInOut(duration: 0.25)) { route = next }
    }
}

/** The launch screen recreated in SwiftUI (cat mark on deep clay). */
struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchLogo")
        }
        .accessibilityHidden(true)
    }
}

/** The tabs, the offline banner, the Friends badge and study sessions. */
struct MainTabsView: View {
    let onLoggedOut: () -> Void

    @StateObject private var badges = BadgeViewModel()
    @ObservedObject private var network = NetworkMonitor.shared
    @ObservedObject private var keyboard = KeyboardObserver.shared
    @ObservedObject private var notificationRouter = NotificationRouter.shared
    @EnvironmentObject var systemToast: SystemToast

    @State private var selected: AppTab = .translation
    /** Tabs are created the first time they're opened, then kept (Android restores their state). */
    @State private var visited: Set<AppTab> = [.translation]
    @State private var studyRoute: StudyRoute?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases) { tab in
                    if visited.contains(tab) {
                        tabContent(tab)
                            .opacity(selected == tab ? 1 : 0)
                            .allowsHitTesting(selected == tab)
                            .accessibilityHidden(selected != tab)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The keyboard covers the tab bar (as on Android) rather than pushing it up.
            if !keyboard.isVisible {
                OfflineBanner(offline: !network.isOnline)
                BottomNavigationBar(selected: $selected, badges: [.friends: badges.friendsBadge])
            }
        }
        .background(AppColor.backgroundSecondary.ignoresSafeArea())
        .onChange(of: selected) { _, tab in
            visited.insert(tab)
            // Hidden tabs stay alive, so a field on the old tab would keep the keyboard up.
            KeyboardObserver.dismiss()
        }
        // A study session is full screen (like the design), without the tab bar.
        .fullScreenCover(item: $studyRoute) { route in
            StudySessionScreen(route: route) { studyRoute = nil }
                // The root overlay sits under full-screen covers, so speech errors show here.
                .modifier(SystemToastOverlay(toast: systemToast))
        }
        .task {
            // Which languages can be read aloud (Android loads this with the first speaker button).
            SpeechRepository.shared.refreshSupported()
            // Ask for notification permission once, the first time the user reaches the main
            // app. After that it's up to them in Settings.
            guard !NotificationPrefs.hasAsked() else { return }
            let allowed = await AppNotifications.shared.canPost()
            if !allowed {
                NotificationPrefs.markAsked()
                AppNotifications.shared.requestPermission()
            }
        }
        // A tapped notification opens the Friends tab; FriendsScreen then switches to the right
        // section and clears it.
        .onChange(of: notificationRouter.pending, initial: true) { _, pending in
            if pending != nil && selected != .friends {
                studyRoute = nil
                selected = .friends
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .translation:
            TranslateScreen(isActive: selected == .translation)
        case .library:
            LibraryScreen { ids in studyRoute = StudySelection.route(ids) }
        case .study:
            StudyScreen { route in studyRoute = route }
        case .friends:
            FriendsScreen()
        case .profile:
            ProfileScreen(isActive: selected == .profile, onLoggedOut: onLoggedOut)
        }
    }
}

/**
 * Whether the software keyboard is actually covering the screen. Judged by its frame, not by
 * show/hide notifications alone: with a hardware keyboard (or the Simulator's "Connect Hardware
 * Keyboard"), iOS still posts "will show" for an off-screen or toolbar-only keyboard, which used
 * to hide the tab bar with nothing visible in its place.
 */
@MainActor
final class KeyboardObserver: ObservableObject {
    static let shared = KeyboardObserver()
    @Published private(set) var isVisible = false

    /** Anything shorter than this is a shortcut bar, not a keyboard covering the tab bar. */
    private static let minimumHeight: CGFloat = 120

    private init() {
        let center = NotificationCenter.default
        center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
            let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            MainActor.assumeIsolated { self?.update(frame) }
        }
        center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isVisible = false }
        }
    }

    private func update(_ frame: CGRect) {
        let screen = UIScreen.main.bounds
        let covered = max(0, screen.maxY - max(frame.minY, screen.minY))
        let onScreen = frame.intersects(screen) && covered >= Self.minimumHeight
        if isVisible != onScreen { isVisible = onScreen }
    }

    /** Closes the keyboard, wherever focus is. */
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
