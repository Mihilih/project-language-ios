import SwiftUI

/**
 * Compose's FlowRow: lays children out left to right and wraps to a new line when the row is
 * full, with fixed spacing between items and between lines.
 */
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && needed > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/** A dashed rounded-rectangle outline (the "Find friends" card, empty streak days). */
struct DashedRoundedBorder: View {
    var color: Color
    var radius: CGFloat
    var lineWidth: CGFloat = 1.5
    var dash: [CGFloat] = [6, 5]

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .strokeBorder(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
    }
}

extension View {
    /** Kotlin's Modifier.background(color, shape) for a rounded rectangle. */
    func roundedBackground(_ color: Color, _ radius: CGFloat) -> some View {
        background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /** A hairline-or-thicker rounded outline drawn inside the bounds. */
    func roundedBorder(_ color: Color, _ radius: CGFloat, width: CGFloat = 1.5) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(color, lineWidth: width))
    }

    /** Hides a view without removing it, keeping its space (Compose's alpha 0 / invisible). */
    @ViewBuilder
    func visible(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0).accessibilityHidden(!isVisible)
    }
}
