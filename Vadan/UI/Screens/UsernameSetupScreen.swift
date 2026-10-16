import SwiftUI

private enum StatusKind { case neutral, good, problem }

/**
 * "Pick a username", shown after sign-up and on launch for any signed-in user without one.
 * Friends find each other by username, so it can't be skipped — `onBack` signs out instead
 * (UsernameSetupScreen.kt).
 */
struct UsernameSetupScreen: View {
    let onUsernameClaimed: () -> Void
    var onBack: () -> Void = {}

    @StateObject private var viewModel = UsernameSetupViewModel()
    @FocusState var focused: Bool

    var body: some View {
        let uiState = viewModel.uiState
        let name = uiState.username

        // Status line under the field, as in the design.
        let statusInfo: (text: String, kind: StatusKind) = {
            if name.isEmpty { return ("Type a username", .neutral) }
            if let problem = uiState.validationMessage { return (problem, .problem) }
            switch uiState.availability {
            case .checking: return ("Checking @\(name)…", .neutral)
            case .taken: return ("@\(name) is taken", .problem)
            case .available: return ("@\(name) is available", .good)
            case .checkFailed: return ("Couldn't check right now. We'll check when you continue.", .neutral)
            case .unknown: return ("", .neutral)
            }
        }()
        let status = statusInfo.text
        let statusKind = statusInfo.kind
        let borderColor: Color = {
            switch statusKind {
            case .good: return AppColor.secondary
            case .problem: return AppColor.primaryDark
            case .neutral: return AppColor.neutral300
            }
        }()
        let usernameFont = AppFont.poppins(20)

        AuthScaffold(
            title: "Pick a username",
            subtitle: "This is how friends find you.",
            onBack: onBack,
            katoPose: .talk
        ) {
            if let error = uiState.errorMessage { AuthErrorBanner(text: error) }

            AuthField(label: "Username") {
                OutlinedField(
                    text: Binding(get: { viewModel.uiState.username }, set: viewModel.onUsernameChange),
                    placeholder: "yourname",
                    prefix: "@",
                    enabled: !uiState.isSaving,
                    font: usernameFont,
                    autocapitalization: .never,
                    autocorrection: false,
                    submitLabel: .done,
                    unfocusedBorder: borderColor,
                    focusedBorder: statusKind == .neutral ? AppColor.accent : borderColor,
                    focus: $focused,
                    onSubmit: { if viewModel.uiState.canSubmit { submit() } }
                )
                HStack(spacing: 6) {
                    let color: Color = {
                        switch statusKind {
                        case .good: return AppColor.textPrimary
                        case .problem: return AppColor.primaryDark
                        case .neutral: return AppColor.textSecondary
                        }
                    }()
                    if uiState.availability == .checking && !name.isEmpty {
                        ProgressView().tint(AppColor.textSecondary).controlSize(.mini).frame(width: 14, height: 14)
                    } else if statusKind == .good {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(color)
                    } else if statusKind == .problem {
                        Image(systemName: "exclamationmark.circle").font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                    }
                    Text(status)
                        .font(AppFont.dmSans(14, .semibold))
                        .foregroundStyle(color)
                }
                .frame(minHeight: 22)
                .accessibilityElement(children: .combine)
            }

            if uiState.availability == .taken && !uiState.alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AVAILABLE INSTEAD")
                        .font(AppFont.dmSans(12, .bold))
                        .tracking(1.2)
                        .foregroundStyle(AppColor.textSecondary)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(uiState.alternatives, id: \.self) { alt in
                            Button { viewModel.onUsernameChange(alt) } label: {
                                Text("@\(alt)")
                                    .font(AppFont.dmSans(14, .semibold))
                                    .foregroundStyle(AppColor.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(minHeight: 40)
                                    .background(Capsule().fill(AppColor.backgroundPrimary))
                                    .overlay(Capsule().strokeBorder(AppColor.neutral300, lineWidth: 1.5))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach([
                    "\(UserProfileRepository.minLength)–\(UserProfileRepository.maxLength) characters",
                    "Letters, numbers, dots and underscores",
                    "Friends search for you by this name",
                ], id: \.self) { rule in
                    Text(rule)
                        .font(AppFont.dmSans(14))
                        .foregroundStyle(AppColor.textBody)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .roundedBackground(AppColor.backgroundSecondary, 16)

            Spacer().frame(minHeight: 8)

            VStack(spacing: 10) {
                AuthPrimaryButton(
                    text: uiState.availability == .available ? "Continue as @\(name)" : "Continue",
                    enabled: uiState.canSubmit,
                    loading: uiState.isSaving,
                    action: submit
                )
                Text("You can’t change your username later.")
                    .font(AppFont.dmSans(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func submit() {
        viewModel.submit(onSuccess: onUsernameClaimed)
    }
}
