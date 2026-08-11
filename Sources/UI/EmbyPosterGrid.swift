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
    @Published fileprivate var selectedItem: LibraryItem?
    @Published fileprivate var client: EmbyAPIClient?
    @Published fileprivate var isActive = false
    @Published fileprivate var sourceInteractionLocked = false
    private var transitionLocked = false
    private var destinationPresented = false
    private var acceptingNewOpenAfter = Date.distantPast
    private var transitionGeneration = 0
    private let pushTapGuardInterval: TimeInterval = 1.0
    private let pushConfirmationTimeout: TimeInterval = 1.25

    func open(item: LibraryItem, client: EmbyAPIClient) {
        let now = Date()
        guard now >= acceptingNewOpenAfter, !isActive, !transitionLocked, !sourceInteractionLocked else {
            DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-rejected item=\(item.id) active=\(isActive) transitionLocked=\(transitionLocked) sourceLocked=\(sourceInteractionLocked) destinationPresented=\(destinationPresented) guardRemainingMs=\(max(0, Int(acceptingNewOpenAfter.timeIntervalSince(now) * 1000)))")
            return
        }
        transitionGeneration += 1
        let generation = transitionGeneration
        sourceInteractionLocked = true
        transitionLocked = true
        destinationPresented = false
        acceptingNewOpenAfter = now.addingTimeInterval(pushTapGuardInterval)
        selectedItem = item
        self.client = client
        isActive = true
        DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-accepted item=\(item.id) generation=\(generation)")
        DispatchQueue.main.asyncAfter(deadline: .now() + pushConfirmationTimeout) { [weak self] in
            self?.expirePendingPush(generation: generation)
        }
    }

    fileprivate func destinationDidAppear() {
        destinationPresented = true
        DiagnosticsLogger.shared.log("NavigationRace", "event=destination-did-appear item=\(selectedItem?.id ?? "none") generation=\(transitionGeneration)")
    }

    fileprivate func destinationDidDisappear() {
        DiagnosticsLogger.shared.log("NavigationRace", "event=destination-did-disappear item=\(selectedItem?.id ?? "none") generation=\(transitionGeneration)")
        destinationPresented = false
        isActive = false
        transitionLocked = false
        sourceInteractionLocked = false
        selectedItem = nil
        client = nil
    }

    fileprivate func updateActive(_ active: Bool) {
        DiagnosticsLogger.shared.log("NavigationRace", "event=binding-update active=\(active) currentActive=\(isActive) transitionLocked=\(transitionLocked) destinationPresented=\(destinationPresented) sourceLocked=\(sourceInteractionLocked) generation=\(transitionGeneration)")
        if active {
            isActive = true
            return
        }
        if transitionLocked && !destinationPresented {
            cancelPendingPush(reason: "binding-deactivated-before-appearance")
            return
        }
        isActive = false
        transitionLocked = false
        destinationPresented = false
        sourceInteractionLocked = false
        selectedItem = nil
        client = nil
    }

    fileprivate func prepareForGridAppearance() {
        DiagnosticsLogger.shared.log("NavigationRace", "event=grid-appear active=\(isActive) transitionLocked=\(transitionLocked) destinationPresented=\(destinationPresented) sourceLocked=\(sourceInteractionLocked) generation=\(transitionGeneration)")
        if !isActive {
            transitionLocked = false
            destinationPresented = false
            sourceInteractionLocked = false
            if Date() >= acceptingNewOpenAfter {
                selectedItem = nil
                client = nil
            }
        }
    }

    private func expirePendingPush(generation: Int) {
        guard generation == transitionGeneration, transitionLocked, !destinationPresented else { return }
        DiagnosticsLogger.shared.log("NavigationRace", "event=push-confirmation-timeout item=\(selectedItem?.id ?? "none") generation=\(generation) active=\(isActive) sourceLocked=\(sourceInteractionLocked)")
        cancelPendingPush(reason: "destination-did-not-appear")
    }

    private func cancelPendingPush(reason: String) {
        DiagnosticsLogger.shared.log("NavigationRace", "event=cancel-pending-push reason=\(reason) item=\(selectedItem?.id ?? "none") generation=\(transitionGeneration)")
        transitionGeneration += 1
        isActive = false
        transitionLocked = false
        destinationPresented = false
        sourceInteractionLocked = false
        selectedItem = nil
        client = nil
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

private struct EmbyPosterGridNavigationHost: View {
    @ObservedObject var state: EmbyPosterGridNavigationState

    var body: some View {
        NavigationLink(
            destination: Group {
                if let item = state.selectedItem, let client = state.client {
                    EmbyMediaDetailView(item: item, client: client)
                        .onAppear { state.destinationDidAppear() }
                        .onDisappear { state.destinationDidDisappear() }
                } else {
                    EmptyView()
                }
            },
            isActive: Binding(get: { state.isActive }, set: { state.updateActive($0) })
        ) { EmptyView() }
        .frame(width: 0, height: 0)
        .hidden()
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
        LazyVGrid(columns: columns, alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .environment(\.embyPosterGridNavigationState, navigationState)
                    .environment(\.embyPosterGridCellWidth, cellWidth)
                    .frame(width: cellWidth, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onAppear {
                        guard let handler = onApproachingEnd else { return }
                        let threshold = max(0, items.count - EmbyPosterGridMetrics.loadAheadItemCount)
                        if index >= threshold { handler() }
                    }
            }
        }
        .allowsHitTesting(!navigationState.sourceInteractionLocked)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { proxy in Color.clear.preference(key: EmbyPosterGridWidthPreferenceKey.self, value: proxy.size.width) })
        .background(EmbyPosterGridNavigationHost(state: navigationState))
        .onPreferenceChange(EmbyPosterGridWidthPreferenceKey.self) { width in
            if width > 0 && abs(containerWidth - width) > 0.5 { containerWidth = width }
        }
        .onAppear { navigationState.prepareForGridAppearance() }
    }
}
