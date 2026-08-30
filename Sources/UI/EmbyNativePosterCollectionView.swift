import SwiftUI
import UIKit

struct EmbyNativePosterCollectionView: UIViewControllerRepresentable {
    let items: [LibraryItem]
    let client: EmbyAPIClient
    let isLoading: Bool
    let hasMore: Bool
    let onApproachingEnd: () -> Void
    let onRefresh: () -> Void
    let onSelect: (LibraryItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(items: items, client: client, isLoading: isLoading, hasMore: hasMore, onApproachingEnd: onApproachingEnd, onRefresh: onRefresh, onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> NativePosterCollectionController {
        let controller = NativePosterCollectionController()
        context.coordinator.attach(to: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: NativePosterCollectionController, context: Context) {
        context.coordinator.update(items: items, client: client, isLoading: isLoading, hasMore: hasMore, onApproachingEnd: onApproachingEnd, onRefresh: onRefresh, onSelect: onSelect)
    }

    static func dismantleUIViewController(_ uiViewController: NativePosterCollectionController, coordinator: Coordinator) { coordinator.detach() }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
        private var items: [LibraryItem]
        private var client: EmbyAPIClient
        private var isLoading: Bool
        private var hasMore: Bool
        private var onApproachingEnd: () -> Void
        private var onRefresh: () -> Void
        private var onSelect: (LibraryItem) -> Void
        private weak var controller: NativePosterCollectionController?
        private let refreshControl = UIRefreshControl()
        private var displayLink: CADisplayLink?
        private var sessionStartedAt: CFTimeInterval?
        private var previousDisplayTimestamp: CFTimeInterval?
        private var displayIntervalsMs: [Double] = []
        private var displayGapGE12_5 = 0
        private var displayGapGE25 = 0
        private var displayGapGE33_3 = 0
        private var gap12InsertOverlap = 0
        private var gap25InsertOverlap = 0
        private var gap33InsertOverlap = 0
        private var gap12ReconfigureOverlap = 0
        private var gap25ReconfigureOverlap = 0
        private var gap33ReconfigureOverlap = 0
        private var insertBatchActive = false
        private var insertEventsSinceLastDisplay = 0
        private var insertItemsSinceLastDisplay = 0
        private var reconfigureEventsSinceLastDisplay = 0
        private var reconfigureVisibleSinceLastDisplay = 0
        private var insertEvents = 0
        private var insertItemsTotal = 0
        private var reconfigureEvents = 0
        private var reconfigureVisibleTotal = 0
        private var reconfigureDurationMsTotal: Double = 0
        private var reconfigureDurationMsMax: Double = 0
        private var displayFrames = 0
        private var offsetSamples = 0
        private var decelFrames = 0
        private var decelZeroFrames = 0
        private var decelCatchupFrames = 0
        private var decelReverseCount = 0
        private var decelReverseGE1Count = 0
        private var maxReversePoints: CGFloat = 0
        private var maxReverseDistanceTop: CGFloat = 0
        private var maxReverseDistanceBottom: CGFloat = 0
        private var maxReverseOutsideBounds = false
        private var previousDisplayOffset: CGFloat?
        private var previousDisplayWasZero = false
        private var expectedDecelerationDirection: CGFloat = 0
        private var activeSession = false
        private var inDeceleration = false

        init(items: [LibraryItem], client: EmbyAPIClient, isLoading: Bool, hasMore: Bool, onApproachingEnd: @escaping () -> Void, onRefresh: @escaping () -> Void, onSelect: @escaping (LibraryItem) -> Void) {
            self.items = items
            self.client = client
            self.isLoading = isLoading
            self.hasMore = hasMore
            self.onApproachingEnd = onApproachingEnd
            self.onRefresh = onRefresh
            self.onSelect = onSelect
            super.init()
            refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        }

        func attach(to controller: NativePosterCollectionController) {
            self.controller = controller
            controller.collectionView.dataSource = self
            controller.collectionView.delegate = self
            controller.collectionView.refreshControl = refreshControl
            controller.collectionView.register(NativePosterHostingCell.self, forCellWithReuseIdentifier: NativePosterHostingCell.reuseIdentifier)
            let link = CADisplayLink(target: self, selector: #selector(displayTick(_:)))
            link.add(to: .main, forMode: .common)
            link.isPaused = true
            displayLink = link
        }

        func detach() {
            finishMotionSession(reason: "detach")
            displayLink?.invalidate()
            displayLink = nil
            controller?.collectionView.dataSource = nil
            controller?.collectionView.delegate = nil
            controller = nil
        }

        func update(items: [LibraryItem], client: EmbyAPIClient, isLoading: Bool, hasMore: Bool, onApproachingEnd: @escaping () -> Void, onRefresh: @escaping () -> Void, onSelect: @escaping (LibraryItem) -> Void) {
            let oldIDs = self.items.map(\.id)
            let newIDs = items.map(\.id)
            self.items = items
            self.client = client
            self.isLoading = isLoading
            self.hasMore = hasMore
            self.onApproachingEnd = onApproachingEnd
            self.onRefresh = onRefresh
            self.onSelect = onSelect
            if !isLoading && refreshControl.isRefreshing { refreshControl.endRefreshing() }
            guard let collectionView = controller?.collectionView else { return }
            if oldIDs == newIDs {
                let visibleCount = collectionView.indexPathsForVisibleItems.count
                let startedAt = CACurrentMediaTime()
                reconfigureVisibleCells(in: collectionView)
                if activeSession {
                    let durationMs = (CACurrentMediaTime() - startedAt) * 1000
                    reconfigureEvents += 1
                    reconfigureVisibleTotal += visibleCount
                    reconfigureEventsSinceLastDisplay += 1
                    reconfigureVisibleSinceLastDisplay += visibleCount
                    reconfigureDurationMsTotal += durationMs
                    reconfigureDurationMsMax = max(reconfigureDurationMsMax, durationMs)
                    DiagnosticsLogger.shared.log("NativePosterCollection", "event=reconfigure visible_count=\(visibleCount) duration_ms=\(format(durationMs))")
                }
                return
            }
            if oldIDs.count < newIDs.count, Array(newIDs.prefix(oldIDs.count)) == oldIDs {
                let inserted = (oldIDs.count..<newIDs.count).map { IndexPath(item: $0, section: 0) }
                let startedAt = CACurrentMediaTime()
                let startedDuringSession = activeSession
                insertBatchActive = true
                if startedDuringSession {
                    insertEvents += 1
                    insertItemsTotal += inserted.count
                    insertEventsSinceLastDisplay += 1
                    insertItemsSinceLastDisplay += inserted.count
                    DiagnosticsLogger.shared.log("NativePosterCollection", "event=insert-begin inserted=\(inserted.count) item_count=\(items.count)")
                }
                collectionView.performBatchUpdates({ collectionView.insertItems(at: inserted) }) { [weak self] _ in
                    guard let self else { return }
                    self.insertBatchActive = false
                    if startedDuringSession {
                        let durationMs = (CACurrentMediaTime() - startedAt) * 1000
                        DiagnosticsLogger.shared.log("NativePosterCollection", "event=insert-end inserted=\(inserted.count) duration_ms=\(self.format(durationMs))")
                    }
                }
            } else {
                collectionView.reloadData()
            }
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NativePosterHostingCell.reuseIdentifier, for: indexPath) as? NativePosterHostingCell,
                  let controller,
                  items.indices.contains(indexPath.item) else { return UICollectionViewCell() }
            configure(cell, item: items[indexPath.item], collectionView: collectionView, parent: controller)
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard items.indices.contains(indexPath.item) else { return }
            onSelect(items[indexPath.item])
        }

        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            guard hasMore, !items.isEmpty, indexPath.item >= max(0, items.count - EmbyPosterGridMetrics.loadAheadItemCount) else { return }
            onApproachingEnd()
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let width = cellWidth(for: collectionView)
            return CGSize(width: width, height: floor(width / EmbyPosterGridMetrics.posterAspectRatio) + 42)
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
            UIEdgeInsets(top: 8, left: EmbyPosterGridMetrics.horizontalPadding, bottom: 86, right: EmbyPosterGridMetrics.horizontalPadding)
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat { EmbyPosterGridMetrics.rowSpacing }
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { EmbyPosterGridMetrics.columnSpacing }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            startMotionSession(scrollView)
            inDeceleration = false
            expectedDecelerationDirection = 0
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if abs(velocity.y) > 0.01 { expectedDecelerationDirection = velocity.y > 0 ? 1 : -1 }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            inDeceleration = decelerate
            if !decelerate { finishMotionSession(reason: "drag-end") }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            inDeceleration = false
            finishMotionSession(reason: "deceleration-end")
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard activeSession else { return }
            offsetSamples += 1
        }

        @objc private func refreshTriggered() { onRefresh() }

        @objc private func displayTick(_ link: CADisplayLink) {
            guard activeSession, let scrollView = controller?.collectionView else { return }
            let timestamp = CACurrentMediaTime()
            if let previousDisplayTimestamp { recordDisplayInterval((timestamp - previousDisplayTimestamp) * 1000) }
            self.previousDisplayTimestamp = timestamp
            displayFrames += 1
            let current = scrollView.contentOffset.y
            defer { previousDisplayOffset = current }
            guard inDeceleration, let previous = previousDisplayOffset else { return }
            decelFrames += 1
            let delta = current - previous
            let isZero = abs(delta) < 0.05
            if isZero {
                decelZeroFrames += 1
            } else {
                if previousDisplayWasZero { decelCatchupFrames += 1 }
                if expectedDecelerationDirection != 0, delta * expectedDecelerationDirection < -0.01 {
                    let reverse = abs(delta)
                    decelReverseCount += 1
                    if reverse >= 1 { decelReverseGE1Count += 1 }
                    let bounds = legalBounds(for: scrollView)
                    let distanceTop = abs(current - bounds.top)
                    let distanceBottom = abs(bounds.bottom - current)
                    let outside = current < bounds.top - 0.5 || current > bounds.bottom + 0.5
                    if reverse > maxReversePoints {
                        maxReversePoints = reverse
                        maxReverseDistanceTop = distanceTop
                        maxReverseDistanceBottom = distanceBottom
                        maxReverseOutsideBounds = outside
                    }
                    if reverse >= 1 {
                        DiagnosticsLogger.shared.log("NativePosterCollection", "event=reverse delta_pt=\(format(reverse)) offset_y=\(format(current)) legal_top=\(format(bounds.top)) legal_bottom=\(format(bounds.bottom)) distance_top=\(format(distanceTop)) distance_bottom=\(format(distanceBottom)) outside_bounds=\(outside ? 1 : 0)")
                    }
                }
            }
            previousDisplayWasZero = isZero
        }

        private func configure(_ cell: NativePosterHostingCell, item: LibraryItem, collectionView: UICollectionView, parent: UIViewController) {
            let width = cellWidth(for: collectionView)
            let root = AnyView(
                V3PosterCard(item: item, client: client, width: nil)
                    .environment(\.embyPosterGridCellWidth, width)
                    .frame(width: width, alignment: .topLeading)
                    .id(item.id)
            )
            cell.configure(rootView: root, parent: parent)
        }

        private func reconfigureVisibleCells(in collectionView: UICollectionView) {
            guard let controller else { return }
            for indexPath in collectionView.indexPathsForVisibleItems where items.indices.contains(indexPath.item) {
                guard let cell = collectionView.cellForItem(at: indexPath) as? NativePosterHostingCell else { continue }
                configure(cell, item: items[indexPath.item], collectionView: collectionView, parent: controller)
            }
        }

        private func cellWidth(for collectionView: UICollectionView) -> CGFloat {
            let spacing = EmbyPosterGridMetrics.columnSpacing * CGFloat(EmbyPosterGridMetrics.columnCount - 1)
            let available = collectionView.bounds.width - EmbyPosterGridMetrics.horizontalPadding * 2 - spacing
            return floor(max(1, available) / CGFloat(EmbyPosterGridMetrics.columnCount))
        }

        private func startMotionSession(_ scrollView: UIScrollView) {
            guard !activeSession else { return }
            activeSession = true
            inDeceleration = false
            sessionStartedAt = CACurrentMediaTime()
            previousDisplayTimestamp = nil
            displayIntervalsMs.removeAll(keepingCapacity: true)
            displayGapGE12_5 = 0
            displayGapGE25 = 0
            displayGapGE33_3 = 0
            gap12InsertOverlap = 0
            gap25InsertOverlap = 0
            gap33InsertOverlap = 0
            gap12ReconfigureOverlap = 0
            gap25ReconfigureOverlap = 0
            gap33ReconfigureOverlap = 0
            insertEventsSinceLastDisplay = 0
            insertItemsSinceLastDisplay = 0
            reconfigureEventsSinceLastDisplay = 0
            reconfigureVisibleSinceLastDisplay = 0
            insertEvents = 0
            insertItemsTotal = 0
            reconfigureEvents = 0
            reconfigureVisibleTotal = 0
            reconfigureDurationMsTotal = 0
            reconfigureDurationMsMax = 0
            displayFrames = 0
            offsetSamples = 0
            decelFrames = 0
            decelZeroFrames = 0
            decelCatchupFrames = 0
            decelReverseCount = 0
            decelReverseGE1Count = 0
            maxReversePoints = 0
            maxReverseDistanceTop = 0
            maxReverseDistanceBottom = 0
            maxReverseOutsideBounds = false
            previousDisplayOffset = scrollView.contentOffset.y
            previousDisplayWasZero = false
            expectedDecelerationDirection = 0
            let maximumFPS = max(60, UIScreen.main.maximumFramesPerSecond)
            if maximumFPS > 60 { displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: Float(maximumFPS), preferred: Float(maximumFPS)) }
            else { displayLink?.preferredFrameRateRange = .default }
            displayLink?.isPaused = false
            DiagnosticsLogger.shared.log("NativePosterCollection", "event=session-start item_count=\(items.count) maximum_fps=\(maximumFPS) refresh_request=\(maximumFPS > 60 ? 1 : 0)")
        }

        private func finishMotionSession(reason: String) {
            guard activeSession else { return }
            let duration = max(0.001, CACurrentMediaTime() - (sessionStartedAt ?? CACurrentMediaTime()))
            let displayHz = Double(displayFrames) / duration
            let offsetHz = Double(offsetSamples) / duration
            let zeroRatio = decelFrames > 0 ? Double(decelZeroFrames) / Double(decelFrames) : 0
            let catchupRatio = decelFrames > 0 ? Double(decelCatchupFrames) / Double(decelFrames) : 0
            let sortedIntervals = displayIntervalsMs.sorted()
            let intervalP50 = percentile(sortedIntervals, 0.50)
            let intervalP95 = percentile(sortedIntervals, 0.95)
            let intervalP99 = percentile(sortedIntervals, 0.99)
            let intervalMax = sortedIntervals.last ?? 0
            DiagnosticsLogger.shared.log("NativePosterCollection", "event=session-end reason=\(reason) duration_ms=\(format(duration * 1000)) item_count=\(items.count) display_frames=\(displayFrames) display_hz=\(format(displayHz)) display_interval_p50_ms=\(format(intervalP50)) display_interval_p95_ms=\(format(intervalP95)) display_interval_p99_ms=\(format(intervalP99)) display_interval_max_ms=\(format(intervalMax)) gap_ge12_5=\(displayGapGE12_5) gap_ge25=\(displayGapGE25) gap_ge33_3=\(displayGapGE33_3) gap12_insert_overlap=\(gap12InsertOverlap) gap25_insert_overlap=\(gap25InsertOverlap) gap33_insert_overlap=\(gap33InsertOverlap) gap12_reconfigure_overlap=\(gap12ReconfigureOverlap) gap25_reconfigure_overlap=\(gap25ReconfigureOverlap) gap33_reconfigure_overlap=\(gap33ReconfigureOverlap) insert_events=\(insertEvents) insert_items=\(insertItemsTotal) reconfigure_events=\(reconfigureEvents) reconfigure_visible=\(reconfigureVisibleTotal) reconfigure_duration_total_ms=\(format(reconfigureDurationMsTotal)) reconfigure_duration_max_ms=\(format(reconfigureDurationMsMax)) offset_samples=\(offsetSamples) offset_hz=\(format(offsetHz)) decel_frames=\(decelFrames) decel_zero_ratio=\(format(zeroRatio)) decel_catchup_ratio=\(format(catchupRatio)) decel_reverse=\(decelReverseCount) decel_reverse_ge1=\(decelReverseGE1Count) decel_reverse_max_pt=\(format(maxReversePoints)) reverse_distance_top=\(format(maxReverseDistanceTop)) reverse_distance_bottom=\(format(maxReverseDistanceBottom)) reverse_outside_bounds=\(maxReverseOutsideBounds ? 1 : 0)")
            activeSession = false
            inDeceleration = false
            sessionStartedAt = nil
            previousDisplayOffset = nil
            displayLink?.isPaused = true
            displayLink?.preferredFrameRateRange = .default
        }

        private func recordDisplayInterval(_ intervalMs: Double) {
            displayIntervalsMs.append(intervalMs)
            let insertOverlap = insertBatchActive || insertEventsSinceLastDisplay > 0
            let reconfigureOverlap = reconfigureEventsSinceLastDisplay > 0
            if intervalMs >= 12.5 {
                displayGapGE12_5 += 1
                if insertOverlap { gap12InsertOverlap += 1 }
                if reconfigureOverlap { gap12ReconfigureOverlap += 1 }
            }
            if intervalMs >= 25 {
                displayGapGE25 += 1
                if insertOverlap { gap25InsertOverlap += 1 }
                if reconfigureOverlap { gap25ReconfigureOverlap += 1 }
                DiagnosticsLogger.shared.log("NativePosterCollection", "event=display-gap interval_ms=\(format(intervalMs)) insert_active=\(insertBatchActive ? 1 : 0) insert_events=\(insertEventsSinceLastDisplay) insert_items=\(insertItemsSinceLastDisplay) reconfigure_events=\(reconfigureEventsSinceLastDisplay) reconfigure_visible=\(reconfigureVisibleSinceLastDisplay)")
            }
            if intervalMs >= 33.3 {
                displayGapGE33_3 += 1
                if insertOverlap { gap33InsertOverlap += 1 }
                if reconfigureOverlap { gap33ReconfigureOverlap += 1 }
            }
            insertEventsSinceLastDisplay = 0
            insertItemsSinceLastDisplay = 0
            reconfigureEventsSinceLastDisplay = 0
            reconfigureVisibleSinceLastDisplay = 0
        }

        private func percentile(_ sorted: [Double], _ quantile: Double) -> Double {
            guard !sorted.isEmpty else { return 0 }
            let index = Int((Double(sorted.count - 1) * quantile).rounded())
            return sorted[min(max(index, 0), sorted.count - 1)]
        }

        private func legalBounds(for scrollView: UIScrollView) -> (top: CGFloat, bottom: CGFloat) {
            let top = -scrollView.adjustedContentInset.top
            let bottom = max(top, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
            return (top, bottom)
        }

        private func format(_ value: CGFloat) -> String { String(format: "%.2f", Double(value)) }
        private func format(_ value: Double) -> String { String(format: "%.2f", value) }
    }
}

final class NativePosterCollectionController: UIViewController {
    let collectionView: UICollectionView
    private var lastLayoutWidth: CGFloat = 0

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = .zero
        layout.scrollDirection = .vertical
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.contentInsetAdjustmentBehavior = .never
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = collectionView.bounds.width
        guard width > 0, abs(width - lastLayoutWidth) > 0.5 else { return }
        lastLayoutWidth = width
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

private final class NativePosterHostingCell: UICollectionViewCell {
    static let reuseIdentifier = "NativePosterHostingCell"
    private var host: UIHostingController<AnyView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(rootView: AnyView, parent: UIViewController) {
        if let host {
            host.rootView = rootView
            host.view.invalidateIntrinsicContentSize()
            return
        }
        let host = UIHostingController(rootView: rootView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        parent.addChild(host)
        contentView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        host.didMove(toParent: parent)
        self.host = host
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        host?.rootView = AnyView(EmptyView())
    }
}
