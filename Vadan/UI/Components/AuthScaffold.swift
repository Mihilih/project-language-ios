import SwiftUI

/**
 * The sign-up / log-in / username layout from the design: a deep clay header with the title,
 * Kato in the corner, and a white sheet with rounded top corners holding the form. Scrolls (and
 * moves above the keyboard) on small phones and with large text (AuthScaffold.kt).
 */
struct AuthScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    var onBack: (() -> Void)? = nil
    /** Kato in the header corner: wave (sign up), sit (log in), sleep (log-in error), talk (username). */
    var katoPose: KatoPose = .wave
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { outer in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 16) {
                        content()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                            .fill(AppColor.backgroundPrimary)
                            // The white sheet runs on under the home indicator.
                            .padding(.bottom, -400)
                    )
                }
                // At least screen height, so the white sheet always reaches the bottom.
                .frame(minHeight: outer.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(alignment: .bottom) {
            // Clay behind the header, white behind the bottom edge (seen when scrolled).
            VStack(spacing: 0) {
                AppColor.brandClay
                AppColor.backgroundPrimary.frame(height: 200)
            }
            .ignoresSafeArea()
        }
        .lightStatusBar()
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            Kato(pose: katoPose, width: 96, outline: false)
                .padding(.trailing, 16)
            VStack(alignment: .leading, spacing: 8) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppColor.textInverse)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .offset(x: -12)
                    .accessibilityLabel("Back")
                } else {
                    Spacer().frame(height: 44)
                }
                // Always two lines tall, so switching Sign up / Log in never resizes the header.
                Text(title + "\n ")
                    .hidden()
                    .overlay(alignment: .topLeading) {
                        Text(title)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .font(AppFont.poppins(34))
                    .tracking(-0.6)
                    .foregroundStyle(AppColor.textInverse)
                    .lineSpacing(-4)
                    // Leaves room for Kato on the right.
                    .frame(maxWidth: 236, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle + "\n ")
                    .hidden()
                    .overlay(alignment: .topLeading) { Text(subtitle) }
                    .font(AppFont.dmSans(16))
                    .foregroundStyle(AppColor.textInverse)
                    .frame(maxWidth: 300, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/** Blush banner with an alert icon, for a failed log-in or sign-up. */
struct AuthErrorBanner: View {
    let text: String
    var body: some View { AuthBanner(text: text, error: true) }
}

/** Cream banner with a check, e.g. "reset link sent". */
struct AuthInfoBanner: View {
    let text: String
    var body: some View { AuthBanner(text: text, error: false) }
}

private struct AuthBanner: View {
    let text: String
    let error: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: error ? "exclamationmark.circle" : "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(error ? AppColor.primaryDark : AppColor.textPrimary)
                .frame(width: 18, height: 18)
                .padding(.top, 1)
            Text(text)
                .font(AppFont.dmSans(14, .semibold))
                .foregroundStyle(error ? AppColor.primaryDark : AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .roundedBackground(error ? AppColor.primarySoft : AppColor.cream, 14)
        .accessibilityElement(children: .combine)
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: text)
            }
        }
        .onChange(of: text) { _, newText in
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: newText)
            }
        }
    }
}

/** Full-width clay pill; greyed out (the design's disabled "Continue") when not enabled. */
struct AuthPrimaryButton: View {
    let text: String
    var enabled: Bool = true
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().tint(AppColor.textInverse)
                } else {
                    Text(text).font(AppFont.dmSans(16, .bold)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(enabled || loading ? AppColor.textInverse : AppColor.textSecondary)
            .background(Capsule().fill(enabled || loading ? AppColor.primary : AppColor.trackGray))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled || loading)
    }
}

/** Label above a form field (AuthField in LoginScreen.kt). */
struct AuthField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.dmSans(13, .bold))
                .foregroundStyle(AppColor.textBody)
            content()
        }
    }
}

/**
 * Material's OutlinedTextField as the auth and setup screens use it: 14pt corners, an outline
 * that turns clay when focused (or deep clay on error), placeholder, optional prefix and
 * trailing accessory.
 */
struct OutlinedField<Trailing: View>: View {
    @Binding var text: String
    var placeholder: String = ""
    var prefix: String? = nil
    var isError: Bool = false
    var secure: Bool = false
    var enabled: Bool = true
    var font: Font = AppFont.dmSans(16)
    var placeholderFont: Font? = nil
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrection: Bool = true
    var submitLabel: SubmitLabel = .done
    /** Outline when not focused; nil uses the standard outline color. */
    var unfocusedBorder: Color? = nil
    var focusedBorder: Color? = nil
    var minLines: Int = 1
    var maxLines: Int? = nil
    var focus: FocusState<Bool>.Binding? = nil
    var onSubmit: () -> Void = {}
    @ViewBuilder var trailing: () -> Trailing

    @FocusState var ownFocus: Bool

    private var isFocused: Bool { focus?.wrappedValue ?? ownFocus }

    var body: some View {
        let border: Color = {
            if isError { return AppColor.primaryDark }
            if isFocused { return focusedBorder ?? AppColor.accent }
            return unfocusedBorder ?? AppColor.outline
        }()
        HStack(alignment: minLines > 1 ? .top : .center, spacing: 6) {
            if let prefix {
                Text(prefix)
                    .font(font)
                    .foregroundStyle(AppColor.textSecondary)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(placeholderFont ?? font)
                        .foregroundStyle(AppColor.textTertiary)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                field
                    .font(font)
                    .foregroundStyle(AppColor.textPrimary)
                    .tint(AppColor.accent)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(!autocorrection)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                    .disabled(!enabled)
                    .accessibilityLabel(placeholder)
            }
            trailing()
        }
        .padding(.leading, 16)
        .padding(.trailing, Trailing.self == EmptyView.self ? 16 : 4)
        .padding(.vertical, minLines > 1 ? 16 : 0)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColor.backgroundPrimary))
        .roundedBorder(border, 14, width: isFocused || isError ? 2 : 1)
        .opacity(enabled ? 1 : 0.6)
    }

    @ViewBuilder
    private var field: some View {
        if secure {
            if let focus { SecureField("", text: $text).focused(focus) } else { SecureField("", text: $text).focused($ownFocus) }
        } else if minLines > 1 {
            let lines = TextField("", text: $text, axis: .vertical).lineLimit(minLines...(maxLines ?? 100))
            if let focus { lines.focused(focus) } else { lines.focused($ownFocus) }
        } else {
            if let focus { TextField("", text: $text).focused(focus) } else { TextField("", text: $text).focused($ownFocus) }
        }
    }
}

extension OutlinedField where Trailing == EmptyView {
    init(
        text: Binding<String>,
        placeholder: String = "",
        prefix: String? = nil,
        isError: Bool = false,
        secure: Bool = false,
        enabled: Bool = true,
        font: Font = AppFont.dmSans(16),
        placeholderFont: Font? = nil,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        autocorrection: Bool = true,
        submitLabel: SubmitLabel = .done,
        unfocusedBorder: Color? = nil,
        focusedBorder: Color? = nil,
        minLines: Int = 1,
        maxLines: Int? = nil,
        focus: FocusState<Bool>.Binding? = nil,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.init(
            text: text, placeholder: placeholder, prefix: prefix, isError: isError, secure: secure,
            enabled: enabled, font: font, placeholderFont: placeholderFont, keyboard: keyboard,
            contentType: contentType, autocapitalization: autocapitalization, autocorrection: autocorrection,
            submitLabel: submitLabel, unfocusedBorder: unfocusedBorder, focusedBorder: focusedBorder,
            minLines: minLines, maxLines: maxLines, focus: focus, onSubmit: onSubmit, trailing: { EmptyView() }
        )
    }
}
