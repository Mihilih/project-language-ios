import SwiftUI

/**
 * Screen title from the design: large left-aligned Poppins title on the page background, with
 * an optional caption underneath and optional trailing actions (AppHeader.kt).
 */
struct AppHeader<Trailing: View>: View {
    let text: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .screenTitleStyle()
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.dmSans(14, .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .background(AppColor.backgroundSecondary)
    }
}

extension AppHeader where Trailing == EmptyView {
    init(_ text: String, subtitle: String? = nil) {
        self.text = text
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}
