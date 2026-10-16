import SwiftUI

enum AppButtonVariant { case filled, outlined }

/** Pill button from the design: clay fill, or white with a hairline outline (AppButton). */
struct AppButton: View {
    let text: String
    var icon: String? = nil
    var enabled: Bool = true
    var variant: AppButtonVariant = .filled
    var containerColor: Color? = nil
    var contentColor: Color? = nil
    var borderColor: Color = AppColor.neutral300
    let action: () -> Void

    var body: some View {
        let container = containerColor ?? (variant == .filled ? AppColor.primary : AppColor.backgroundPrimary)
        let content = contentColor ?? (variant == .filled ? AppColor.textInverse : AppColor.textPrimary)
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                }
                Text(text)
                    .font(AppFont.dmSans(15, .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(
                variant == .filled
                    ? (enabled ? content : content.opacity(0.85))
                    : (enabled ? content : AppColor.textTertiary)
            )
            .background(
                Capsule().fill(variant == .filled && !enabled ? container.opacity(0.45) : container)
            )
            .overlay {
                if variant == .outlined { Capsule().strokeBorder(borderColor, lineWidth: 1.5) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

/** A light press feedback for custom-drawn buttons (stands in for Material's ripple). */
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/** Full-width clay pill with an optional spinner — the app's standard primary action. */
struct PrimaryPillButton: View {
    let text: String
    var icon: String? = nil
    var trailingIcon: String? = nil
    var enabled: Bool = true
    var loading: Bool = false
    var height: CGFloat = 54
    var fontSize: CGFloat = 16
    var container: Color = AppColor.primary
    var content: Color = AppColor.textInverse
    /** Colors when disabled; defaults to Android's 45% / 85% alpha. */
    var disabledContainer: Color? = nil
    var disabledContent: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(content).controlSize(.small)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                }
                Text(text).font(AppFont.dmSans(fontSize, .bold)).lineLimit(1)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(enabled ? content : (disabledContent ?? content.opacity(0.85)))
            .background(Capsule().fill(enabled ? container : (disabledContainer ?? container.opacity(0.45))))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

/** Outlined pill (white fill, neutral outline), e.g. "Send feedback", "Dismiss". */
struct OutlinePillButton: View {
    let text: String
    var icon: String? = nil
    var enabled: Bool = true
    var loading: Bool = false
    var height: CGFloat = 50
    var fontSize: CGFloat = 14
    var content: Color = AppColor.textPrimary
    var horizontalPadding: CGFloat = 8
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(content).controlSize(.small)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                    Text(text).font(AppFont.dmSans(fontSize, .bold)).lineLimit(1)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(enabled ? content : content.opacity(0.38))
            .background(Capsule().fill(AppColor.backgroundPrimary))
            .overlay(Capsule().strokeBorder(enabled ? AppColor.neutral300 : AppColor.neutral300.opacity(0.5), lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled || loading)
    }
}

/** Material TextButton: just the label, with a 48pt touch target. */
struct PlainTextButton: View {
    let text: String
    var color: Color = AppColor.textSecondary
    var fontSize: CGFloat = 15
    var weight: AppFont.Weight = .semibold
    var enabled: Bool = true
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(AppFont.dmSans(fontSize, weight))
                .foregroundStyle(enabled ? color : color.opacity(0.38))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}
