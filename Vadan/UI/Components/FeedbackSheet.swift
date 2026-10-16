import SwiftUI

/** "Send feedback" from Profile: pick a kind, write a message, send (FeedbackSheet.kt). */
struct FeedbackSheet: View {
    @ObservedObject var viewModel: FeedbackViewModel
    let onSent: () -> Void

    @State private var category: FeedbackCategory = .bug
    @State private var message = ""

    var body: some View {
        let uiState = viewModel.uiState
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Send feedback")
                    .font(AppFont.poppins(24))
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Found a bug or a wrong translation, or have an idea? It goes straight to the developer.")
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textSecondary)
            }

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(FeedbackCategory.allCases) { option in
                    let on = option == category
                    Button { category = option } label: {
                        Text(option.label)
                            .font(AppFont.dmSans(15, .semibold))
                            .foregroundStyle(on ? AppColor.textInverse : AppColor.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(on ? AppColor.secondary : AppColor.backgroundPrimary))
                            .overlay(Capsule().strokeBorder(on ? AppColor.secondary : AppColor.neutral300, lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your message")
                    .font(AppFont.dmSans(12, .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                OutlinedField(
                    text: Binding(get: { message }, set: {
                        message = $0.take(FeedbackViewModel.maxMessage)
                        viewModel.clearError()
                    }),
                    placeholder: category == .translation
                        ? "Which phrase, and what should it say?"
                        : "Tell us what happened or what you'd like",
                    minLines: 5
                )
                Text("\(message.count) / \(FeedbackViewModel.maxMessage) · Your app version and phone model are included.")
                    .font(AppFont.dmSans(12))
                    .foregroundStyle(AppColor.textSecondary)
            }

            if let error = uiState.error {
                Text(error)
                    .font(AppFont.dmSans(14, .semibold))
                    .foregroundStyle(AppColor.error)
            }

            PrimaryPillButton(
                text: "Send feedback",
                enabled: message.isNotBlank && !uiState.sending,
                loading: uiState.sending
            ) {
                viewModel.send(category: category, message: message, onSent: onSent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}
