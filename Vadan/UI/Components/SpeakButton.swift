import SwiftUI

/**
 * Speaker icon that reads `text` aloud in `language` (SpeakButton.kt). Shows nothing for
 * languages without a voice. While loading it spins; while playing it turns into a stop button.
 * Errors show as a short toast, like Android's Toast.
 */
struct SpeakButton: View {
    let text: String
    let language: String
    var tint: Color = AppColor.textSecondary
    var size: CGFloat = 44

    @ObservedObject private var speech = SpeechRepository.shared
    @EnvironmentObject var systemToast: SystemToast

    var body: some View {
        if !text.isBlank && speech.supported.contains(language) {
            let mine = speech.state.key == speech.keyFor(text, language)
            Button {
                speech.speak(text, language: language) { message in
                    systemToast.show(message)
                }
            } label: {
                ZStack {
                    if mine && speech.state.loading {
                        ProgressView().tint(tint).controlSize(.small).frame(width: 18, height: 18)
                    } else if mine {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(tint)
                    } else {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(mine && !speech.state.loading ? "Stop playing" : "Listen to “\(text.trimmed)”")
        }
    }
}

/**
 * Android's system Toast (a short dark message near the bottom), used for speech errors from
 * any screen. Shown by the root view above everything else.
 */
@MainActor
final class SystemToast: ObservableObject {
    @Published private(set) var message: String?
    private var timer: Task<Void, Never>?

    func show(_ text: String) {
        timer?.cancel()
        message = text
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
        timer = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled { message = nil }
        }
    }
}

struct SystemToastOverlay: ViewModifier {
    @ObservedObject var toast: SystemToast

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = toast.message {
                Text(message)
                    .font(AppFont.dmSans(14, .medium))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.2).opacity(0.92), in: Capsule())
                    .padding(.bottom, 96)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: toast.message)
    }
}
