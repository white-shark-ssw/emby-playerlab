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

    func open(item: LibraryItem, client: EmbyAPIClient) {
        guard !isActive, !transitionLocked else { return }
        transitionLocked = true
        selectedItem = item
        self.client = client
        DispatchQueue.main.async { [weak self] in
            guard let self, self.selectedItem?.id == item.id, !self.isActive else { return }
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

private final class EmbyPosterGridMultitouchCancellationGesture: UIGestureRecognizer {
    private var activeTouches = Set<ObjectIdentifier>()

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { activeTouches.insert(ObjectIdentifier(touch)) }
        if activeTouches.count >= 2 {
            if state == .possible { state = .began }
            else if state == .began { state = .changed }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began { state = .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { activeTouches.remove(ObjectIdentifier(touch)) }
        finishSequenceIfNeeded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { activeTouches.remove(ObjectIdentifier(touch)) }
        finishSequenceIfNeeded()
    }

    override func reset() {
        super.reset()
        activeTouches.removeAll()
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    private func finishSequenceIfNeeded() {
        guard activeTouches.isEmpty else { return }
        if state == .began || state == .changed { state = .ended }
        else if state == .possible { state = .failed }
    }
}

private final class EmbyPosterGridTouchShieldViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installTouchShield()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installTouchShield()
    }

    private func installTouchShield() {
        if let navigationController { installTouchShield(on: navigationController) }
        guard let root = viewIfLoaded?.window?.rootViewController else { return }
        var stack: [UIViewController] = [root]
        while let current = stack.popLast() {
            if let navigationController = current as? UINavigationController { installTouchShield(on: navigationController) }
            if let presented = current.presentedViewController { stack.append(presented) }
            stack.append(contentsOf: current.children)
        }
    }

    private func installTouchShield(on navigationController: UINavigationController) {
        let alreadyInstalled = navigationController.view.gestureRecognizers?.contains { $0 is EmbyPosterGridMultitouchCancellationGesture } ?? false
        guard !alreadyInstalled else { return }
        navigationController.view.addGestureRecognizer(EmbyPosterGridMultitouchCancellationGesture())
    }
}

private struct EmbyPosterGridTouchShieldBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { EmbyPosterGridTouchShieldViewController() }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        DispatchQueue.main.async { viewController.view.setNeedsLayout() }
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
        .background(EmbyPosterGridTouchShieldBridge().frame(width: 0, height: 0))
        .onPreferenceChange(EmbyPosterGridWidthPreferenceKey.self) { width in
            if width > 0 && abs(containerWidth - width) > 0.5 { containerWidth = width }
        }
    }
}
