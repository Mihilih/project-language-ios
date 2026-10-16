import SwiftUI

/** The five main tabs (bottomNavItems in Screen.kt). */
enum AppTab: String, CaseIterable, Identifiable {
    case translation, library, study, friends, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translation: return "Translate"
        case .library: return "Library"
        case .study: return "Study"
        case .friends: return "Friends"
        case .profile: return "Profile"
        }
    }

    /** SF Symbols matching Android's Material icons. */
    var icon: String {
        switch self {
        case .translation: return "translate"
        case .library: return "book"
        case .study: return "rectangle.on.rectangle.angled"
        case .friends: return "person.2"
        case .profile: return "person"
        }
    }
}

/**
 * Tab bar from the design: white bar, hairline top border, and a soft clay pill behind the
 * active tab's icon (BottomNavigationBar.kt).
 */
struct BottomNavigationBar: View {
    @Binding var selected: AppTab
    /** Unread counts by tab, e.g. Friends: pending requests + unread suggestions. */
    var badges: [AppTab: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppColor.neutral200).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    let isSelected = tab == selected
                    let color = isSelected ? AppColor.primaryDark : AppColor.textSecondary
                    let badge = badges[tab] ?? 0
                    Button { selected = tab } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Capsule()
                                    .fill(isSelected ? AppColor.primarySoft : Color.clear)
                                    .frame(width: 54, height: 30)
                                Image(systemName: tab.icon)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(color)
                                    .frame(width: 22, height: 22)
                            }
                            .frame(width: 54, height: 30)
                            .overlay(alignment: .topTrailing) {
                                if badge > 0 {
                                    // Small count bubble on the icon's top-right, as in the design.
                                    Text(badge > 99 ? "99+" : "\(badge)")
                                        .font(AppFont.dmSans(10, .bold))
                                        .foregroundStyle(AppColor.badgeContent)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 18, minHeight: 18)
                                        .background(Capsule().fill(AppColor.badgeBackground))
                                        .overlay(Capsule().strokeBorder(AppColor.backgroundPrimary, lineWidth: 2))
                                        .offset(x: -4, y: -3)
                                }
                            }
                            Text(tab.title)
                                .font(AppFont.dmSans(11, .semibold))
                                .foregroundStyle(color)
                        }
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Count goes in the label, so VoiceOver still announces "Selected".
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(badge > 0 ? "\(tab.title), \(badge) new" : tab.title)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea(edges: .bottom))
    }
}
