import SwiftUI

/** Sign up / Log in, matching the design's Auth screen (LoginScreen.kt). */
struct LoginScreen: View {
    let onLoginSuccess: () -> Void

    @StateObject private var viewModel = LoginViewModel()
    @State private var showPassword = false
    @FocusState var emailFocused: Bool
    @FocusState var passwordFocused: Bool

    var body: some View {
        let uiState = viewModel.uiState
        let isSignUp = uiState.mode == .signUp
        let hasError = uiState.errorMessage != nil

        AuthScaffold(
            title: isSignUp ? "Create your account" : "Welcome back",
            subtitle: isSignUp ? "Save your phrases and study on any device." : "Log in to pick up where you left off.",
            katoPose: isSignUp ? .wave : (hasError ? .sleep : .sit)
        ) {
            ModeTabs(selected: uiState.mode, onSelect: viewModel.setMode)

            if let error = uiState.errorMessage { AuthErrorBanner(text: error) }
            if let info = uiState.infoMessage { AuthInfoBanner(text: info) }

            AuthField(label: "Email") {
                OutlinedField(
                    text: Binding(get: { viewModel.uiState.email }, set: viewModel.onEmailChange),
                    placeholder: "you@example.com",
                    isError: hasError,
                    keyboard: .emailAddress,
                    contentType: .emailAddress,
                    autocapitalization: .never,
                    autocorrection: false,
                    submitLabel: .next,
                    focus: $emailFocused,
                    onSubmit: { passwordFocused = true }
                )
            }

            AuthField(label: "Password") {
                OutlinedField(
                    text: Binding(get: { viewModel.uiState.password }, set: viewModel.onPasswordChange),
                    placeholder: isSignUp ? "At least 8 characters" : "Your password",
                    isError: hasError,
                    secure: !showPassword,
                    contentType: isSignUp ? .newPassword : .password,
                    autocapitalization: .never,
                    autocorrection: false,
                    submitLabel: .done,
                    focus: $passwordFocused,
                    onSubmit: submit
                ) {
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
                if isSignUp {
                    let short = !uiState.password.isEmpty && !uiState.passwordLongEnough
                    Text(uiState.passwordHint)
                        .font(AppFont.dmSans(13, .semibold))
                        .foregroundStyle(short ? AppColor.primaryDark : AppColor.textSecondary)
                } else {
                    HStack {
                        Spacer()
                        PlainTextButton(
                            text: uiState.isSendingReset ? "Sending…" : "Forgot password?",
                            color: AppColor.primaryDark,
                            fontSize: 14,
                            weight: .bold,
                            enabled: !uiState.isSendingReset,
                            action: viewModel.sendPasswordReset
                        )
                    }
                }
            }

            AuthPrimaryButton(text: isSignUp ? "Create account" : "Log in", loading: uiState.isLoading, action: submit)

            OrDivider()

            // New Google accounts go to Pick a username next, same as email sign-ups.
            GoogleButton(loading: uiState.isGoogleLoading, enabled: !uiState.isLoading) {
                clearFocus()
                viewModel.onGoogleStarted()
                Task {
                    switch await GoogleSignInHelper.getTokens() {
                    case .success(let tokens):
                        viewModel.signInWithGoogle(tokens) {
                            AuthPrefs.markReturning()
                            onLoginSuccess()
                        }
                    case .failure(let error):
                        viewModel.onGoogleFailed(error is GoogleSignInHelper.Cancelled ? nil : error.localizedDescription)
                    }
                }
            }
        }
        .onAppear { viewModel.setInitialMode(returning: AuthPrefs.isReturning()) }
    }

    private func clearFocus() {
        emailFocused = false
        passwordFocused = false
    }

    private func submit() {
        clearFocus()
        viewModel.submit {
            AuthPrefs.markReturning()
            onLoginSuccess()
        }
    }
}

private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(AppColor.neutral200).frame(height: 1)
            Text("or")
                .font(AppFont.dmSans(13, .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, 12)
            Rectangle().fill(AppColor.neutral200).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/** Outlined pill from the design, with the official Google "G". */
private struct GoogleButton: View {
    let loading: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(AppColor.textPrimary)
                } else {
                    Image("google_logo")
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text("Continue with Google")
                        .font(AppFont.dmSans(16, .bold))
                }
            }
            .foregroundStyle(enabled ? AppColor.textPrimary : AppColor.textPrimary.opacity(0.38))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(AppColor.backgroundPrimary))
            .overlay(Capsule().strokeBorder(AppColor.neutral300, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled || loading)
    }
}

/** Cream segmented control: "Sign up" | "Log in", selected one in ink. */
private struct ModeTabs: View {
    let selected: AuthMode
    let onSelect: (AuthMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach([(AuthMode.signUp, "Sign up"), (AuthMode.logIn, "Log in")], id: \.1) { mode, label in
                let isSelected = mode == selected
                Button { onSelect(mode) } label: {
                    Text(label)
                        .font(AppFont.dmSans(15, .bold))
                        .foregroundStyle(isSelected ? AppColor.textInverse : AppColor.textBody)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .padding(.vertical, 0)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? AppColor.secondary : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .roundedBackground(AppColor.cream, 16)
    }
}
