import SwiftUI

enum EmbyPosterGridMetrics {
    static let columnCount = 3
    static let horizontalPadding: CGFloat = 14
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 18
    static let loadAheadItemCount = 9
    static let posterAspectRatio: CGFloat = 2.0 / 3.0
    static let cardTextAreaHeight: CGFloat = 44
}

private struct EmbyPosterGridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

private struct EmbyPosterGridCellWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var embyPosterGridCellWidth: CGFloat? {
        get { self[EmbyPosterGridCellWidthKey.self] }
        set { self[EmbyPosterGridCellWidthKey.self] = newValue }
    }
}

struct EmbyPosterGrid<Content: View>: View {
    let items: [LibraryItem]
    let horizontalPadding: CGFloat
    let onApproachingEnd: (() -> Void)?
    private let content: (LibraryItem) -> Content
    @State private var containerWidth: CGFloat = 0

    init(
        items: [LibraryItem],
        horizontalPadding: CGFloat = EmbyPosterGridMetrics.horizontalPadding,
        onApproachingEnd: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (LibraryItem) -> Content
    ) {
        self.items = items
        self.horizontalPadding = horizontalPadding
        self.onApproachingEnd = onApproachingEnd
        self.content = content
    }

    private var cellWidth: CGFloat? {
        guard containerWidth > 0 else { return nil }
        let spacing = EmbyPosterGridMetrics.columnSpacing * CGFloat(EmbyPosterGridMetrics.columnCount - 1)
        let available = containerWidth - horizontalPadding * 2 - spacing
        guard available > 0 else { return nil }
        return floor(available / CGFloat(EmbyPosterGridMetrics.columnCount))
    }

    private var cellHeight: CGFloat? {
        guard let cellWidth = cellWidth else { return nil }
        let posterHeight = cellWidth / EmbyPosterGridMetrics.posterAspectRatio
        return floor(posterHeight + EmbyPosterGridMetrics.cardTextAreaHeight)
    }

    private var columns: [GridItem] {
        if let cellWidth = cellWidth {
            return Array(
                repeating: GridItem(
                    .fixed(cellWidth),
                    spacing: EmbyPosterGridMetrics.columnSpacing,
                    alignment: .top
                ),
                count: EmbyPosterGridMetrics.columnCount
            )
        }

        return Array(
            repeating: GridItem(
                .flexible(minimum: 0, maximum: .infinity),
                spacing: EmbyPosterGridMetrics.columnSpacing,
                alignment: .top
            ),
            count: EmbyPosterGridMetrics.columnCount
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .environment(\.embyPosterGridCellWidth, cellWidth)
                    .frame(width: cellWidth, height: cellHeight, alignment: .topLeading)
                    .clipped()
                    .contentShape(Rectangle())
                    .onAppear {
                        guard let handler = onApproachingEnd else { return }
                        let threshold = max(0, items.count - EmbyPosterGridMetrics.loadAheadItemCount)
                        if index >= threshold { handler() }
                    }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: EmbyPosterGridWidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(EmbyPosterGridWidthPreferenceKey.self) { width in
            if width > 0 && abs(containerWidth - width) > 0.5 { containerWidth = width }
        }
    }
}
