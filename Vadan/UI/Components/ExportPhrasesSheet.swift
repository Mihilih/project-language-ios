import SwiftUI
import UIKit

/** One row of the "What to export" choice: label + how many phrases it covers. */
struct ExportOption: Identifiable {
    let scope: ExportScope
    let label: String
    let count: Int
    var id: String { label }
}

/**
 * The Library's "Export phrases" sheet, as in the design: pick all / favorites / current
 * results, then "Export PDF". "Share as text" sends the same phrases as a message instead
 * (ExportPhrasesSheet.kt).
 */
struct ExportPhrasesSheet: View {
    let options: [ExportOption]
    let selected: ExportScope
    let busy: Bool
    let onSelect: (ExportScope) -> Void
    let onExportPdf: () -> Void
    let onShareText: () -> Void

    var body: some View {
        let selectedCount = options.first { $0.scope == selected }?.count ?? 0
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export phrases")
                    .font(AppFont.poppins(24))
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("We’ll make a PDF you can share or print.")
                    .font(AppFont.dmSans(15))
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(spacing: 8) {
                ForEach(options) { option in
                    let on = option.scope == selected
                    Button { onSelect(option.scope) } label: {
                        HStack(spacing: 6) {
                            RadioCircle(selected: on)
                                .frame(width: 48, height: 48)
                            Text(option.label)
                                .font(AppFont.dmSans(16, .semibold))
                                .foregroundStyle(AppColor.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 18)
                            Text("\(option.count)")
                                .font(AppFont.dmSans(14, .semibold))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 60)
                        .roundedBackground(AppColor.backgroundPrimary, 16)
                        .roundedBorder(on ? AppColor.accent : AppColor.outline, 16, width: on ? 2 : 1.5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                }
            }

            VStack(spacing: 2) {
                PrimaryPillButton(
                    text: busy ? "Making your PDF…" : "Export PDF",
                    icon: "square.and.arrow.up",
                    enabled: !busy && selectedCount > 0,
                    loading: busy,
                    action: onExportPdf
                )
                PlainTextButton(
                    text: "Share as text instead",
                    color: AppColor.textSecondary,
                    enabled: !busy && selectedCount > 0,
                    fullWidth: true,
                    action: onShareText
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

/** Material's RadioButton: clay ring + dot when selected, outline ring otherwise. */
struct RadioCircle: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle().strokeBorder(selected ? AppColor.accent : AppColor.outline, lineWidth: 2)
                .frame(width: 20, height: 20)
            if selected {
                Circle().fill(AppColor.accent).frame(width: 10, height: 10)
            }
        }
    }
}

/** Opens the iOS share sheet for a finished export (shareExport on Android). */
@MainActor
enum ShareSheet {
    static func share(_ result: ExportResult) {
        let items: [Any]
        switch result {
        case .text(let text): items = [text]
        case .pdfFile(let url), .textFile(let url): items = [url]
        }
        present(items)
    }

    static func present(_ items: [Any]) {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let top = topViewController() else { return }
        // iPad needs an anchor; the app is iPhone-only but this keeps it safe.
        controller.popoverPresentationController?.sourceView = top.view
        controller.popoverPresentationController?.sourceRect = CGRect(
            x: top.view.bounds.midX, y: top.view.bounds.maxY, width: 0, height: 0
        )
        top.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
