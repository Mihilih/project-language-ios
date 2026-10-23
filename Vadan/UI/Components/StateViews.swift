import SwiftUI
import Network

/** Centered spinner with an optional line of text, for lists that are still loading. */
struct LoadingState: View {
    var text: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColor.accent)
                .controlSize(.large)
                .frame(width: 32, height: 32)
            if let text {
                Text(text)
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/** Something failed to load: says so plainly and offers a retry. */
struct ErrorState: View {
    let title: String
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(AppFont.poppins(20))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppFont.dmSans(15))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button(action: onRetry) {
                    Text("Try again")
                        .font(AppFont.dmSans(14, .bold))
                        .foregroundStyle(AppColor.textInverse)
                        .padding(.horizontal, 24)
                        .frame(height: 46)
                        .background(AppColor.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
}

/** Thin ink strip shown while the device has no internet connection. */
struct OfflineBanner: View {
    let offline: Bool

    var body: some View {
        VStack(spacing: 0) {
            if offline {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.textInverse)
                    Text("You're offline. Changes will sync when you reconnect.")
                        .font(AppFont.dmSans(13, .semibold))
                        .foregroundStyle(AppColor.textInverse)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColor.secondary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: offline)
    }
}

/** True while the device has a working internet connection; updates live (rememberIsOnline). */
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "vadan.network-monitor"))
    }
}
