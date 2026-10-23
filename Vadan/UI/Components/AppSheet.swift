import SwiftUI

/**
 * The grey pill at the top of every bottom sheet (SheetDragHandle.kt). Decorative here: iOS
 * sheets dismiss with a swipe, and VoiceOver users get the system's dismiss gesture.
 */
struct SheetDragHandle: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(AppColor.neutral200)
                .frame(width: 40, height: 5)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

/**
 * Android's ModalBottomSheet as the app uses it: white sheet with 28pt top corners, the drag
 * handle, sized to its content (or full height), scrolling when the content is taller than
 * the screen.
 */
private struct AppSheetContainer<Content: View>: View {
    let fullHeight: Bool
    let dismissDisabled: Bool
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 300

    var body: some View {
        Group {
            if fullHeight {
                VStack(spacing: 0) {
                    SheetDragHandle()
                    content()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .presentationDetents([.large])
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        SheetDragHandle()
                        content()
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                        }
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
                .onPreferenceChange(SheetHeightKey.self) { height in
                    if height > 0 { contentHeight = height }
                }
                .presentationDetents([.height(contentHeight)])
            }
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .presentationBackground(AppColor.backgroundPrimary)
        .interactiveDismissDisabled(dismissDisabled)
        .foregroundStyle(AppColor.textPrimary)
    }
}

private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension View {
    /** Presents `content` as the app's bottom sheet while `isPresented` is true. */
    func appSheet<Content: View>(
        isPresented: Binding<Bool>,
        fullHeight: Bool = false,
        dismissDisabled: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            AppSheetContainer(fullHeight: fullHeight, dismissDisabled: dismissDisabled, content: content)
        }
    }

    /** Presents the app's bottom sheet for `item` while it's non-nil. */
    func appSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        fullHeight: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { value in
            AppSheetContainer(fullHeight: fullHeight, dismissDisabled: false) { content(value) }
        }
    }
}
