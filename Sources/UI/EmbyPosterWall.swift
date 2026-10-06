import SwiftUI
import UIKit

struct EmbyPosterRecord: Equatable {
    let id: String
    let name: String
    let year: String?
    let url: URL?
    let progress: Double
    let unplayed: Int
    let played: Bool

    init(item: LibraryItem, client: EmbyAPIClient, pixelWidth: Int) {
        id = "\(client.baseURL.absoluteString)|\(client.userId ?? "")|\(item.id)"
        name = item.name; year = item.productionYear.map(String.init)
        url = client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: pixelWidth, tag: item.preferredPrimaryImageTag)
        progress = item.playbackProgress; unplayed = item.userData?.unplayedItemCount ?? 0; played = item.isPlayed
    }
}

final class EmbyPosterCell: UICollectionViewCell {
    static let reuseID = "EmbyPosterCell"
    private let artwork = UIImageView()
    private let placeholder = UIImageView(image: UIImage(systemName: "play.rectangle"))
    private let title = UILabel()
    private let year = UILabel()
    private let progress = UIView()
    private let badge = UILabel()
    private(set) var record: EmbyPosterRecord?
    private var subscription: UUID?
    private var bindingGeneration = 0
    private let preparation: EmbyImagePreparation

    override init(frame: CGRect) { preparation = .shared; super.init(frame: frame); install() }
    init(preparation: EmbyImagePreparation) { self.preparation = preparation; super.init(frame: .zero); install() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func install() {
        artwork.contentMode = .scaleAspectFill; artwork.clipsToBounds = true
        artwork.backgroundColor = .secondarySystemBackground
        artwork.layer.cornerRadius = 10; artwork.layer.cornerCurve = .continuous
        placeholder.tintColor = .tertiaryLabel; placeholder.contentMode = .scaleAspectFit
        title.font = .systemFont(ofSize: 15); title.textColor = .label
        year.font = .systemFont(ofSize: 12); year.textColor = .secondaryLabel
        title.lineBreakMode = .byTruncatingTail; year.lineBreakMode = .byTruncatingTail
        progress.backgroundColor = .systemBlue
        badge.font = .systemFont(ofSize: 11, weight: .bold); badge.textColor = .white; badge.textAlignment = .center
        badge.clipsToBounds = true
        [artwork, placeholder, title, year, progress, badge].forEach(contentView.addSubview)
        isAccessibilityElement = true; accessibilityTraits = .button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let height = floor(width / EmbyPosterGridMetrics.posterAspectRatio)
        artwork.frame = CGRect(x: 0, y: 0, width: width, height: height)
        placeholder.frame = CGRect(x: (width - 28) / 2, y: (height - 28) / 2, width: 28, height: 28)
        title.frame = CGRect(x: 0, y: height + 4, width: width, height: 20)
        year.frame = CGRect(x: 0, y: height + 26, width: width, height: 16)
        progress.frame = CGRect(x: 0, y: height - 3, width: width * CGFloat(record?.progress ?? 0), height: 3)
        let badgeWidth = max(24, ceil(badge.intrinsicContentSize.width) + 12)
        badge.frame = CGRect(x: width - badgeWidth - 5, y: 5, width: badgeWidth, height: badgeWidth)
        badge.layer.cornerRadius = badgeWidth / 2
    }

    func configure(_ value: EmbyPosterRecord) {
        if record == value { activate(); return }
        let requestChanged = record?.id != value.id || record?.url != value.url
        if requestChanged { deactivate(); artwork.image = value.url.flatMap(preparation.readyImage) }
        record = value
        title.text = value.name; year.text = value.year; year.isHidden = value.year == nil
        progress.isHidden = value.progress <= 0
        badge.isHidden = value.unplayed <= 0 && !value.played
        badge.text = value.unplayed > 0 ? String(value.unplayed) : "✓"
        badge.backgroundColor = value.unplayed > 0 ? .systemBlue : .systemGreen
        placeholder.isHidden = artwork.image != nil
        accessibilityLabel = [value.name, value.year].compactMap { $0 }.joined(separator: ", ")
        setNeedsLayout()
        activate()
    }

    func activate() {
        guard subscription == nil, let value = record, let url = value.url else { return }
        let generation = bindingGeneration
        subscription = preparation.subscribe(url, priority: .visible) { [weak self] image in
            guard let self, self.bindingGeneration == generation, self.record?.id == value.id, self.record?.url == url else { return }
            // Target-image adoption only: no snapshot, layout invalidation, crossfade or business publication.
            self.artwork.image = image; self.placeholder.isHidden = image != nil
        }
    }

    func deactivate() {
        bindingGeneration += 1
        if let subscription { preparation.cancel(subscription) }
        subscription = nil
    }

    override func prepareForReuse() {
        super.prepareForReuse(); deactivate(); record = nil; artwork.image = nil
    }

    var displayedImage: UIImage? { artwork.image }
}

private final class EmbyPosterFooter: UICollectionReusableView {
    let label = UILabel()
    let spinner = UIActivityIndicatorView(style: .medium)
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 13); label.textAlignment = .center; label.numberOfLines = 0
        addSubview(label); addSubview(spinner)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 14, dy: 8)
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

struct EmbyPosterWall: UIViewControllerRepresentable {
    let items: [LibraryItem]
    let revision: Int
    let replacement: Int
    let client: EmbyAPIClient
    let isLoading: Bool
    let hasLoaded: Bool
    let error: String?
    let emptyText: String
    let bottomPadding: CGFloat
    let isActive: Bool
    let onApproachingEnd: () -> Void
    let onRefresh: () -> Void
    let onSelect: (LibraryItem) -> Void

    func makeUIViewController(context: Context) -> EmbyPosterWallController { EmbyPosterWallController() }
    func updateUIViewController(_ controller: EmbyPosterWallController, context: Context) { controller.update(self) }
    static func dismantleUIViewController(_ controller: EmbyPosterWallController, coordinator: ()) { controller.dispose() }
}

final class EmbyPosterWallController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {
    private let flow = UICollectionViewFlowLayout()
    private(set) lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: flow)
    private var input: EmbyPosterWall?
    private var appliedReplacement: Int?
    private var appliedRevision: Int?
    private var sourceIdentity: String?
    private var items: [LibraryItem] = []
    private var records: [EmbyPosterRecord] = []
    private var prefetch: [URL: UUID] = [:]
    private let firstScreenOwner = UUID()
    private let preparation = EmbyImagePreparation.shared
    private var width: CGFloat = 0
    private var visible = false
    private var foregroundObserver: NSObjectProtocol?
    private var pressureObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var lastOffset: CGFloat = 0
    private var frameSamples: [Double] = []
    private var imageConfigurationCount = 0

    override func loadView() {
        view = collection
        collection.backgroundColor = .systemBackground
        collection.showsVerticalScrollIndicator = false; collection.alwaysBounceVertical = true
        collection.contentInsetAdjustmentBehavior = .never
        collection.dataSource = self; collection.delegate = self; collection.prefetchDataSource = self
        collection.register(EmbyPosterCell.self, forCellWithReuseIdentifier: EmbyPosterCell.reuseID)
        collection.register(EmbyPosterFooter.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "footer")
        flow.minimumInteritemSpacing = EmbyPosterGridMetrics.columnSpacing
        flow.minimumLineSpacing = EmbyPosterGridMetrics.rowSpacing
        flow.sectionInset = UIEdgeInsets(top: 8, left: 14, bottom: 0, right: 14)
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        collection.refreshControl = refresh
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in self?.prepareFirstScreen() }
        pressureObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in self?.cancelPrefetch() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let newWidth = floor((view.bounds.width - 28 - 24) / 3)
        guard newWidth > 0 else { return }
        if width != newWidth {
            width = newWidth
            flow.itemSize = CGSize(width: width, height: floor(width / EmbyPosterGridMetrics.posterAspectRatio) + 42)
            appliedRevision = nil; appliedReplacement = nil
            if let input { applyItems(input) }
        }
        prepareFirstScreen()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); visible = true; synchronizeActivity(); prepareFirstScreen()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated); visible = false; synchronizeActivity(); cancelPrefetch(); reportFrames()
    }

    func update(_ value: EmbyPosterWall) {
        loadViewIfNeeded()
        let footerChanged = input?.isLoading != value.isLoading || input?.error != value.error || input?.hasLoaded != value.hasLoaded
        input = value
        collection.contentInset.bottom = value.bottomPadding
        if width > 0 { applyItems(value) }
        if footerChanged { flow.invalidateLayout(); updateFooter() }
        if !value.isLoading { collection.refreshControl?.endRefreshing() }
        synchronizeActivity()
    }

    private func applyItems(_ value: EmbyPosterWall) {
        let identity = "\(value.client.baseURL.absoluteString)|\(value.client.userId ?? "")"
        guard appliedRevision != value.revision || sourceIdentity != identity else { return }
        let started = CACurrentMediaTime()
        let old = records
        let append = sourceIdentity == identity && appliedReplacement == value.replacement && value.items.count > old.count
        if sourceIdentity == identity && appliedReplacement == value.replacement && value.items.count == old.count {
            appliedRevision = value.revision
            return
        }
        let newItems = append ? Array(value.items.dropFirst(old.count)) : value.items
        let changed = newItems.map { EmbyPosterRecord(item: $0, client: value.client, pixelWidth: min(440, max(1, Int(ceil(width * view.traitCollection.displayScale))))) }
        let next = append ? old + changed : changed
        let sameIDs = !append && sourceIdentity == identity && next.map(\.id) == old.map(\.id)
        appliedReplacement = value.replacement
        items = value.items; records = next; appliedRevision = value.revision; sourceIdentity = identity
        if append {
            let paths = (old.count..<next.count).map { IndexPath(item: $0, section: 0) }
            UIView.performWithoutAnimation { collection.performBatchUpdates { collection.insertItems(at: paths) } }
        } else if sameIDs {
            for path in collection.indexPathsForVisibleItems where next[path.item] != old[path.item] {
                (collection.cellForItem(at: path) as? EmbyPosterCell)?.configure(next[path.item])
            }
        } else {
            cancelPrefetch()
            UIView.performWithoutAnimation { collection.reloadData() }
        }
        // Update image-demand membership on real data changes; ordinary SwiftUI updates do not scan items.
        if !append { cancelPrefetch(except: Set(next.compactMap(\.url))) }
        prepareFirstScreen()
        DiagnosticsLogger.shared.log("PosterWall", "event=items count=\(next.count) append=\(append ? 1 : 0) same_ids=\(sameIDs ? 1 : 0) apply_ms=\(String(format: "%.2f", (CACurrentMediaTime() - started) * 1000))")
    }

    private func prepareFirstScreen() {
        guard width > 0, view.bounds.height > 0 else { return }
        let count = min(18, (Int(ceil(view.bounds.height / (flow.itemSize.height + flow.minimumLineSpacing))) + 1) * 3)
        preparation.setFirstScreen(owner: firstScreenOwner, urls: records.prefix(count).compactMap(\.url))
    }

    private func synchronizeActivity() {
        let active = visible && (input?.isActive ?? false)
        collection.scrollsToTop = active
        if active && displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(frameTick(_:)))
            if #available(iOS 15.0, *) { link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120) }
            link.add(to: .main, forMode: .common); displayLink = link
        } else if !active { displayLink?.invalidate(); displayLink = nil; lastFrame = 0 }
    }

    @objc private func refreshTriggered() { input?.onRefresh() }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { records.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmbyPosterCell.reuseID, for: indexPath) as! EmbyPosterCell
        cell.configure(records[indexPath.item]); imageConfigurationCount += 1
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? EmbyPosterCell)?.activate()
        if let url = records[indexPath.item].url, let token = prefetch.removeValue(forKey: url) { preparation.cancel(token) }
        if indexPath.item >= records.count - EmbyPosterGridMetrics.loadAheadItemCount { input?.onApproachingEnd() }
    }
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) { (cell as? EmbyPosterCell)?.deactivate() }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        (input?.isActive ?? false) && !collectionView.isDragging && collectionView.panGestureRecognizer.numberOfTouches <= 1
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard indexPath.item < items.count, input?.isActive == true else { return }
        input?.onSelect(items[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard visible, input?.isActive == true else { return }
        for path in indexPaths where path.item < records.count && prefetch.count < 12 {
            guard let url = records[path.item].url, prefetch[url] == nil else { continue }
            prefetch[url] = preparation.subscribe(url, priority: .prefetch) { _ in }
        }
    }
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for path in indexPaths where path.item < records.count {
            guard let url = records[path.item].url, let token = prefetch.removeValue(forKey: url) else { continue }
            preparation.cancel(token)
        }
    }
    private func cancelPrefetch(except retained: Set<URL> = []) {
        for (url, token) in prefetch where !retained.contains(url) { preparation.cancel(token); prefetch.removeValue(forKey: url) }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: records.isEmpty ? 132 : (input?.error != nil || input?.isLoading == true ? 52 : 0))
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footer", for: indexPath) as! EmbyPosterFooter
        configureFooter(footer); return footer
    }
    private func updateFooter() {
        for footer in collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter) { if let footer = footer as? EmbyPosterFooter { configureFooter(footer) } }
    }
    private func configureFooter(_ footer: EmbyPosterFooter) {
        footer.label.text = input?.error ?? (records.isEmpty && input?.hasLoaded == true && input?.isLoading == false ? input?.emptyText : nil)
        footer.label.textColor = input?.error == nil ? .secondaryLabel : .systemRed
        if input?.isLoading == true { footer.spinner.startAnimating() } else { footer.spinner.stopAnimating() }
    }

    @objc private func frameTick(_ link: CADisplayLink) {
        let moving = collection.isDragging || collection.isDecelerating
        let offset = collection.contentOffset.y
        if lastFrame > 0, moving {
            let ms = (link.timestamp - lastFrame) * 1000
            frameSamples.append(ms)
            if ms >= 25 {
                let inBounds = offset >= -collection.adjustedContentInset.top && offset <= max(-collection.adjustedContentInset.top, collection.contentSize.height - collection.bounds.height + collection.adjustedContentInset.bottom)
                DiagnosticsLogger.shared.log("PosterWall", "event=gap ms=\(String(format: "%.2f", ms)) offset=\(String(format: "%.1f", offset)) delta=\(String(format: "%.1f", offset - lastOffset)) in_bounds=\(inBounds ? 1 : 0) dragging=\(collection.isDragging ? 1 : 0) demands=\(preparation.demandCount) tasks=\(preparation.activeTaskCount) pins=\(preparation.firstScreenCount)")
            }
            if frameSamples.count >= 1200 { reportFrames() }
        }
        lastFrame = link.timestamp; lastOffset = offset
    }
    private func reportFrames() {
        guard !frameSamples.isEmpty else { return }
        let values = frameSamples.sorted()
        let percentile: (Double) -> Double = { values[min(values.count - 1, Int(Double(values.count - 1) * $0))] }
        DiagnosticsLogger.shared.log("PosterWall", "event=frames samples=\(values.count) p50=\(percentile(0.5)) p95=\(percentile(0.95)) p99=\(percentile(0.99)) max=\(values.last ?? 0) ge16_7=\(values.filter { $0 >= 16.7 }.count) ge25=\(values.filter { $0 >= 25 }.count) ge33_3=\(values.filter { $0 >= 33.3 }.count) configured=\(imageConfigurationCount)")
        frameSamples.removeAll(keepingCapacity: true); imageConfigurationCount = 0
    }
    func dispose() {
        displayLink?.invalidate(); displayLink = nil
        reportFrames(); cancelPrefetch(); preparation.setFirstScreen(owner: firstScreenOwner, urls: [])
        collection.visibleCells.forEach { ($0 as? EmbyPosterCell)?.deactivate() }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        if let pressureObserver { NotificationCenter.default.removeObserver(pressureObserver) }
    }
}
