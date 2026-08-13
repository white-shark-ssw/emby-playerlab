import SwiftUI

enum EmbyPosterGridMetrics {
    static let columnCount = 3
    static let horizontalPadding: CGFloat = 14
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 18
    static let loadAheadItemCount = 9
    static let posterAspectRatio: CGFloat = 2.0 / 3.0
}

final class EmbyPosterGridNavigationState: ObservableObject {
    @Published private var selectedItemID: String?
    private var pendingItemID: String?
    private var queuedItemID: String?
    private var transitionGeneration = 0
    private let pushConfirmationTimeout: TimeInterval = 1.25

    func selectionBinding(for itemID: String) -> Binding<String?> {
        Binding(
            get: { self.selectedItemID },
            set: { [weak self] value in self?.updateSelection(value, from: itemID) }
        )
    }

    func destinationDidAppear(itemID: String) {
        guard selectedItemID == itemID else {
            DiagnosticsLogger.shared.log("NavigationRace", "event=destination-did-appear-stale item=\(itemID) selected=\(selectedItemID ?? "none") generation=\(transitionGeneration)")
            return
        }
        pendingItemID = nil
        DiagnosticsLogger.shared.log("NavigationRace", "event=destination-did-appear item=\(itemID) generation=\(transitionGeneration)")
    }

    func destinationDidDisappear(itemID: String) {
        DiagnosticsLogger.shared.log("NavigationRace", "event=destination-did-disappear item=\(itemID) selected=\(selectedItemID ?? "none") pending=\(pendingItemID ?? "none") generation=\(transitionGeneration)")
    }

    func prepareForGridAppearance() {
        DiagnosticsLogger.shared.log("NavigationRace", "event=grid-appear selected=\(selectedItemID ?? "none") pending=\(pendingItemID ?? "none") queued=\(queuedItemID ?? "none") generation=\(transitionGeneration)")
    }

    private func updateSelection(_ value: String?, from itemID: String) {
        precondition(Thread.isMainThread)
        if value == itemID {
            requestOpen(itemID)
        } else if value == nil, selectedItemID == itemID {
            completeReturn(itemID)
        }
    }

    private func requestOpen(_ itemID: String) {
        if selectedItemID == itemID { return }
        if let activeItemID = selectedItemID {
            if pendingItemID == nil, queuedItemID == nil {
                queuedItemID = itemID
                DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-queued item=\(itemID) active=\(activeItemID) generation=\(transitionGeneration) reason=route-still-active")
            } else {
                DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-rejected item=\(itemID) active=\(activeItemID) pending=\(pendingItemID ?? "none") queued=\(queuedItemID ?? "none") generation=\(transitionGeneration)")
            }
            return
        }

        transitionGeneration += 1
        let generation = transitionGeneration
        pendingItemID = itemID
        queuedItemID = nil
        selectedItemID = itemID
        DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-accepted item=\(itemID) generation=\(generation) route=cell-link")
        DispatchQueue.main.asyncAfter(deadline: .now() + pushConfirmationTimeout) { [weak self] in
            self?.expirePendingPush(itemID: itemID, generation: generation)
        }
    }

    private func completeReturn(_ itemID: String) {
        let queued = queuedItemID
        DiagnosticsLogger.shared.log("NavigationRace", "event=route-returned item=\(itemID) generation=\(transitionGeneration) queued=\(queued ?? "none")")
        selectedItemID = nil
        pendingItemID = nil
        queuedItemID = nil
        guard let queued else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.selectedItemID == nil else { return }
            self.requestOpen(queued)
        }
    }

    private func expirePendingPush(itemID: String, generation: Int) {
        guard generation == transitionGeneration, selectedItemID == itemID, pendingItemID == itemID else { return }
        DiagnosticsLogger.shared.log("NavigationRace", "event=push-confirmation-timeout item=\(itemID) generation=\(generation) route=cell-link")
        selectedItemID = nil
        pendingItemID = nil
        queuedItemID = nil
    }
}

private struct EmbyPosterGridNavigationStateKey: EnvironmentKey {
    static let defaultValue: EmbyPosterGridNavigationState? = nil
}

extension EnvironmentValues {
    var embyPosterGridNavigationState: EmbyPosterGridNavigationState? {
        get { self[EmbyPosterGridNavigationStateKey.self] }
        set { self[EmbyPosterGridNavigationStateKey.self] = newValue }
    }
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
    @StateObject private var navigationState = EmbyPosterGridNavigationState()

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

    private var columns: [GridItem] {
        if let cellWidth = cellWidth {
            return Array(repeating: GridItem(.fixed(cellWidth), spacing: EmbyPosterGridMetrics.columnSpacing, alignment: .top), count: EmbyPosterGridMetrics.columnCount)
        }
        return Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: EmbyPosterGridMetrics.columnSpacing, alignment: .top), count: EmbyPosterGridMetrics.columnCount)
    }

    var body: some View {
        let loadAheadIDs = Set(items.suffix(EmbyPosterGridMetrics.loadAheadItemCount).map(\.id))
        return LazyVGrid(columns: columns, alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing) {
            ForEach(items) { item in
                content(item)
                    .environment(\.embyPosterGridNavigationState, navigationState)
                    .environment(\.embyPosterGridCellWidth, cellWidth)
                    .frame(width: cellWidth, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onAppear {
                        guard let handler = onApproachingEnd, loadAheadIDs.contains(item.id) else { return }
                        handler()
                    }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { proxy in Color.clear.preference(key: EmbyPosterGridWidthPreferenceKey.self, value: proxy.size.width) })
        .onPreferenceChange(EmbyPosterGridWidthPreferenceKey.self) { width in
            if width > 0 && abs(containerWidth - width) > 0.5 { containerWidth = width }
        }
        .onAppear { navigationState.prepareForGridAppearance() }
    }
}