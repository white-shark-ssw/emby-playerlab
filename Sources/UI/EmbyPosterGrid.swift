import SwiftUI
import UIKit

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
    private var transitionLocked = false
    private var multitouchBlocked = false
    private var multitouchReleaseWorkItem: DispatchWorkItem?

    func open(item: LibraryItem, client: EmbyAPIClient) {
        guard !isActive, !transitionLocked, !multitouchBlocked else { return }
        transitionLocked = true
        selectedItem = item
        self.client = client
        DispatchQueue.main.async { [weak self] in
            guard let self, self.selectedItem?.id == item.id, !self.isActive, !self.multitouchBlocked else {
                self?.cancelPendingOpenIfNeeded(itemID: item.id)
                return
            }
            self.isActive = true
        }
    }

    fileprivate func updateActive(_ active: Bool) {
        isActive = active
        guard !active else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isActive else { return }
            self.selectedItem = nil
            self.client = nil
            self.transitionLocked = false
        }
    }

    fileprivate func beginMultitouchBlock() {
        multitouchReleaseWorkItem?.cancel()
        multitouchReleaseWorkItem = nil
        multitouchBlocked = true
        if !isActive { cancelPendingOpenIfNeeded(itemID: selectedItem?.id) }
    }

    fileprivate func endMultitouchBlock() {
        multitouchReleaseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.multitouchBlocked = false
            self?.multitouchReleaseWorkItem = nil
        }
        multitouchReleaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    fileprivate func prepareForGridAppearance() {
        multitouchReleaseWorkItem?.cancel()
        multitouchReleaseWorkItem = nil
        multitouchBlocked = false
        guard !isActive else { return }
        selectedItem = nil
        client = nil
        transitionLocked = false
    }

    private func cancelPendingOpenIfNeeded(itemID: String?) {
        guard !isActive else { return }
        if itemID == nil || selectedItem?.id == itemID {
            selectedItem = nil
            client = nil
            transitionLocked = false
        }
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
        Group {
            if let item = state.selectedItem, let client = state.client {
                NavigationLink(
                    destination: EmbyMediaDetailView(item: item, client: client),
                    isActive: Binding(get: { state.isActive }, set: { state.updateActive($0) })
                ) { EmptyView() }
                .frame(width: 0, height: 0)
                .hidden()
            }
        }
    }
}

private final class EmbyPosterGridMultitouchGuardGesture: UILongPressGestureRecognizer, UIGestureRecognizerDelegate {
    weak var guardedScrollView: UIScrollView?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        minimumPressDuration = 0
        numberOfTouchesRequired = 2
        allowableMovement = CGFloat.greatestFiniteMagnitude
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let guardedScrollView else { return false }
        return otherGestureRecognizer === guardedScrollView.panGestureRecognizer
    }
}

private final class EmbyPosterGridTouchShieldViewController: UIViewController {
    weak var navigationState: EmbyPosterGridNavigationState?
    private weak var guardGesture: EmbyPosterGridMultitouchGuardGesture?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureGridEnvironment()
        resetGuardForFreshAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureGridEnvironment()
    }

    private func configureGridEnvironment() {
        guard let scrollView = enclosingScrollView() else { return }
        scrollView.showsVerticalScrollIndicator = false
        installTouchShield(on: scrollView)
    }

    private func enclosingScrollView() -> UIScrollView? {
        var current = view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView { return scrollView }
            current = candidate.superview
        }
        return nil
    }

    private func installTouchShield(on scrollView: UIScrollView) {
        if let existing = scrollView.gestureRecognizers?.first(where: { $0 is EmbyPosterGridMultitouchGuardGesture }) as? EmbyPosterGridMultitouchGuardGesture {
            existing.guardedScrollView = scrollView
            if guardGesture !== existing {
                existing.addTarget(self, action: #selector(multitouchGuardChanged(_:)))
                guardGesture = existing
            }
            return
        }

        let gesture = EmbyPosterGridMultitouchGuardGesture(target: self, action: #selector(multitouchGuardChanged(_:)))
        gesture.guardedScrollView = scrollView
        scrollView.addGestureRecognizer(gesture)
        guardGesture = gesture
    }

    private func resetGuardForFreshAppearance() {
        if let guardGesture {
            guardGesture.isEnabled = false
            guardGesture.isEnabled = true
        }
        navigationState?.prepareForGridAppearance()
        DispatchQueue.main.async { [weak self] in self?.navigationState?.prepareForGridAppearance() }
    }

    @objc private func multitouchGuardChanged(_ gesture: EmbyPosterGridMultitouchGuardGesture) {
        switch gesture.state {
        case .began, .changed:
            navigationState?.beginMultitouchBlock()
        case .ended, .cancelled, .failed:
            navigationState?.endMultitouchBlock()
        default:
            break
        }
    }
}

private struct EmbyPosterGridTouchShieldBridge: UIViewControllerRepresentable {
    let navigationState: EmbyPosterGridNavigationState

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = EmbyPosterGridTouchShieldViewController()
        controller.navigationState = navigationState
        return controller
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard let controller = viewController as? EmbyPosterGridTouchShieldViewController else { return }
        controller.navigationState = navigationState
        DispatchQueue.main.async { controller.view.setNeedsLayout() }
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
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { proxy in Color.clear.preference(key: EmbyPosterGridWidthPreferenceKey.self, value: proxy.size.width) })
        .background(EmbyPosterGridNavigationHost(state: navigationState))
        .background(EmbyPosterGridTouchShieldBridge(navigationState: navigationState).frame(width: 0, height: 0))
        .onPreferenceChange(EmbyPosterGridWidthPreferenceKey.self) { width in
            if width > 0 && abs(containerWidth - width) > 0.5 { containerWidth = width }
        }
    }
}
