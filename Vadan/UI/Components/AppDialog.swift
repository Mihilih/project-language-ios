import SwiftUI

/**
 * Material's AlertDialog, as the app uses it (log out, delete account, reply): a rounded card
 * over a dim scrim with a title, content, and text buttons on the right. Shown by the root view
 * so it covers the tab bar too. Screens describe it with `AppDialog` and present it through
 * `DialogHost`.
 */
@MainActor
final class DialogHost: ObservableObject {
    @Published fileprivate(set) var content: AnyView?
    fileprivate var onScrimTap: (() -> Void)?

    /** Shows a dialog. `onDismissRequest` runs when the scrim is tapped. */
    func show<V: View>(onDismissRequest: (() -> Void)? = nil, @ViewBuilder _ view: () -> V) {
        onScrimTap = onDismissRequest
        content = AnyView(view())
    }

    func dismiss() {
        content = nil
        onScrimTap = nil
    }
}

/** Overlays whatever dialog the host is showing. Applied once, at the root. */
struct DialogOverlay: ViewModifier {
    @ObservedObject var host: DialogHost

    func body(content: Content) -> some View {
        content.overlay {
            if let dialog = host.content {
                ZStack {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .onTapGesture { host.onScrimTap?() }
                        .accessibilityHidden(true)
                    dialog
                        .padding(.horizontal, 40)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: host.content != nil)
    }
}

/** The dialog card itself. */
struct AppDialog<Content: View, Buttons: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(AppFont.poppins(24))
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(AppFont.dmSans(15, .medium))
                .foregroundStyle(AppColor.textSecondary)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                buttons()
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: 560, alignment: .leading)
        .roundedBackground(AppColor.backgroundPrimary, 28)
    }
}

/** A dialog text button (Material TextButton): bold label, no background. */
struct DialogButton: View {
    let text: String
    var color: Color = AppColor.accent
    var enabled: Bool = true
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(text).font(AppFont.dmSans(14, .bold)).visible(!loading)
                if loading { ProgressView().tint(color).controlSize(.small) }
            }
            .foregroundStyle(enabled ? color : color.opacity(0.38))
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
    }
}

/** Outlined text field used inside dialogs (Material OutlinedTextField with a label). */
struct DialogTextField: View {
    let label: String
    @Binding var text: String
    var secure: Bool = false
    var enabled: Bool = true
    var minLines: Int = 1

    @FocusState var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFont.dmSans(12, .semibold))
                .foregroundStyle(focused ? AppColor.accent : AppColor.textSecondary)
            Group {
                if secure {
                    SecureField("", text: $text)
                        .textContentType(.password)
                } else if minLines > 1 {
                    TextField("", text: $text, axis: .vertical)
                        .lineLimit(minLines...8)
                } else {
                    TextField("", text: $text)
                }
            }
            .focused($focused)
            .font(AppFont.dmSans(16))
            .foregroundStyle(AppColor.textPrimary)
            .tint(AppColor.accent)
            .disabled(!enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .roundedBorder(focused ? AppColor.accent : AppColor.outline, 4, width: focused ? 2 : 1)
        }
    }
}
