import SwiftUI
import UIKit

/**
 * Status bar icon color. Like Android, icons follow light/dark mode everywhere except on the
 * auth screens' dark clay header, which asks for light icons while it's on screen.
 */
@MainActor
final class StatusBarController {
    static let shared = StatusBarController()

    weak var host: UIViewController?
    private var lightRequests = 0

    var style: UIStatusBarStyle { lightRequests > 0 ? .lightContent : .default }

    func requestLight() {
        lightRequests += 1
        update()
    }

    func releaseLight() {
        lightRequests = max(0, lightRequests - 1)
        update()
    }

    private func update() {
        UIView.animate(withDuration: 0.2) { self.host?.setNeedsStatusBarAppearanceUpdate() }
    }
}

/** The root view controller: SwiftUI content with a status bar style SwiftUI can't set itself. */
final class RootHostingController<Content: View>: UIHostingController<Content> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        MainActor.assumeIsolated { StatusBarController.shared.style }
    }
}

private struct LightStatusBar: ViewModifier {
    @State private var requested = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !requested {
                    requested = true
                    StatusBarController.shared.requestLight()
                }
            }
            .onDisappear {
                if requested {
                    requested = false
                    StatusBarController.shared.releaseLight()
                }
            }
    }
}

extension View {
    /** Light status bar icons while this view is on screen (dark headers). */
    func lightStatusBar() -> some View { modifier(LightStatusBar()) }
}
