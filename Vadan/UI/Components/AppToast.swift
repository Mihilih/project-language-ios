import SwiftUI

enum ToastKind { case success, error, info }

struct ToastMessage: Equatable {
    let text: String
    let kind: ToastKind
    /** Distinguishes two identical messages in a row so the second one still shows. */
    let id = UUID()
}

/** Holds the toast currently on screen. One at a time; a new one replaces the old (AppToast.kt). */
@MainActor
final class ToastState: ObservableObject {
    /** Last toast shown; kept after it's dismissed so it can animate out. */
    @Published private(set) var last: ToastMessage?
    @Published private(set) var visible = false

    /** The toast on screen, or nil. */
    var current: ToastMessage? { visible ? last : nil }

    func show(_ text: String, kind: ToastKind = .success) {
        last = ToastMessage(text: text, kind: kind)
        visible = true
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }

    func success(_ text: String) { show(text, kind: .success) }
    func error(_ text: String) { show(text, kind: .error) }

    func dismiss() { visible = false }
}

/**
 * The design's toast: a cream pill with a check (or an error icon) and one line of text. Hides
 * itself after a few seconds; errors stay up a little longer so they can be read.
 */
struct AppToastHost: View {
    @ObservedObject var state: ToastState

    var body: some View {
        ZStack {
            if state.visible, let message = state.last {
                AppToast(message: message)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: message.id) {
                        try? await Task.sleep(nanoseconds: message.kind == .error ? 4_500_000_000 : 3_000_000_000)
                        if state.current?.id == message.id { state.dismiss() }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.visible)
        .animation(.easeOut(duration: 0.2), value: state.last?.id)
    }
}

struct AppToast: View {
    let message: ToastMessage

    var body: some View {
        let (icon, tint): (String, Color) = {
            switch message.kind {
            case .success: return ("checkmark", AppColor.textPrimary)
            case .error: return ("exclamationmark.circle", AppColor.error)
            case .info: return ("info.circle", AppColor.textPrimary)
            }
        }()
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
            Text(message.text)
                .font(AppFont.dmSans(14, .semibold))
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .roundedBackground(AppColor.cream, 16)
        .accessibilityElement(children: .combine)
    }
}

/** Material's Snackbar with one action (the Library's "Phrase deleted · Undo"). */
@MainActor
final class SnackbarState: ObservableObject {
    struct Message: Equatable {
        let text: String
        let actionLabel: String?
        let id = UUID()
    }

    @Published private(set) var current: Message?
    private var action: (() -> Void)?
    private var timer: Task<Void, Never>?

    /** Shows a snackbar for 4 seconds (Material's short duration). */
    func show(_ text: String, actionLabel: String? = nil, onAction: (() -> Void)? = nil) {
        timer?.cancel()
        let message = Message(text: text, actionLabel: actionLabel)
        current = message
        action = onAction
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
        timer = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled && current?.id == message.id { dismiss() }
        }
    }

    func dismiss() {
        timer?.cancel()
        current = nil
        action = nil
    }

    func performAction() {
        let run = action
        dismiss()
        run?()
    }
}

struct SnackbarHost: View {
    @ObservedObject var state: SnackbarState

    var body: some View {
        ZStack {
            if let message = state.current {
                HStack(spacing: 8) {
                    Text(message.text)
                        .font(AppFont.dmSans(14, .medium))
                        .foregroundStyle(AppColor.textInverse)
                    Spacer(minLength: 0)
                    if let label = message.actionLabel {
                        Button(label) { state.performAction() }
                            .font(AppFont.dmSans(14, .bold))
                            .foregroundStyle(AppColor.tertiary)
                            .frame(minHeight: 36)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
                .frame(minHeight: 48)
                .roundedBackground(AppColor.secondary, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.current)
    }
}
