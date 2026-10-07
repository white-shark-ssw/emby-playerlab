import SwiftUI
import UIKit

// Four fixed counters, recorded at work boundaries. No per-cell log strings or unbounded samples.
struct EmbyPosterWorkTrace {
    enum Stage: Int, CaseIterable { case configure, imageAdopt, layout, apply }
    struct Cost {
        var count = 0
        var total = 0.0
        var maximum = 0.0
        var overBudget = 0
    }
    private(set) var costs = Array(repeating: Cost(), count: Stage.allCases.count)
    mutating func record(_ stage: Stage, milliseconds: Double) {
        costs[stage.rawValue].count += 1
        costs[stage.rawValue].total += milliseconds
        costs[stage.rawValue].maximum = max(costs[stage.rawValue].maximum, milliseconds)
        if milliseconds >= 8.33 { costs[stage.rawValue].overBudget += 1 }
    }
    mutating func reset() { costs = Array(repeating: Cost(), count: Stage.allCases.count) }
}

// Numeric history only. It observes UIKit; it never drives offset, paging or gesture state.
struct EmbyPosterMotionTrace {
    struct Sample {
        let time: Double
        let offset: CGFloat
        let maximum: CGFloat
        let count: Int
        let dragging: Bool
        let decelerating: Bool
    }
    static let capacity = 64
    private var storage: [Sample] = []
    private var next = 0
    var samples: [Sample] { storage.count < Self.capacity ? storage : Array(storage[next...] + storage[..<next]) }
    mutating func append(_ sample: Sample) {
        if storage.count < Self.capacity { storage.append(sample) } else { storage[next] = sample }
        next = (next + 1) % Self.capacity
    }
}

struct EmbyPosterImageRequestKey: Hashable {
    let baseURL: URL
    let accessToken: String?
    let itemID: String
    let tag: String?
    let pixelWidth: Int
}

// The native wall/cells access this record-owned URL memo on the main thread. Image storage stays in the shared preparation/cache owners.
final class EmbyPosterImageRequest: Equatable {
    let key: EmbyPosterImageRequestKey
    private let client: EmbyAPIClient
    private(set) var isResolved = false
    private(set) var resolvedURL: URL?

    init(key: EmbyPosterImageRequestKey, client: EmbyAPIClient) { self.key = key; self.client = client }
    var url: URL? {
        if !isResolved {
            resolvedURL = client.imageURL(itemId: key.itemID, maxWidth: key.pixelWidth, tag: key.tag)
            isResolved = true
        }
        return resolvedURL
    }
    static func == (lhs: EmbyPosterImageRequest, rhs: EmbyPosterImageRequest) -> Bool { lhs.key == rhs.key }
}

enum EmbyPosterCardKind { case media, plainMedia, person, genre, folder
    var hasYear: Bool { self == .media || self == .plainMedia }
    var textHeight: CGFloat { self == .media ? 42 : (self == .plainMedia ? 40 : 24) }
    var placeholder: String { self == .genre ? "rectangle.stack.fill" : (self == .folder ? "folder.fill" : "play.rectangle") }
}

enum EmbyPosterWallContent { case media, plainMedia, people, genres, folders
    var textHeight: CGFloat { self == .plainMedia ? 40 : (self == .genres || self == .people ? 24 : 42) }
    func kind(for item: LibraryItem) -> EmbyPosterCardKind {
        if self == .plainMedia { return .plainMedia }
        if self == .people { return .person }
        if self == .genres { return .genre }
        if self == .folders, ["folder", "collectionfolder"].contains(item.type?.lowercased() ?? "") { return .folder }
        return .media
    }
}

struct EmbyPosterRecord: Equatable {
    let id: String
    let name: String
    let year: String?
    let imageRequest: EmbyPosterImageRequest
    var url: URL? { imageRequest.url }
    let progress: Double
    let unplayed: Int
    let played: Bool
    let kind: EmbyPosterCardKind

    init(item: LibraryItem, client: EmbyAPIClient, pixelWidth: Int, sourceIdentity: String? = nil, retainedRequests: [EmbyPosterImageRequestKey: EmbyPosterImageRequest] = [:], kind: EmbyPosterCardKind = .media) {
        self.kind = kind
        id = "\(sourceIdentity ?? "\(client.baseURL.absoluteString)|\(client.userId ?? "")")|\(item.id)"
        name = item.name; year = kind.hasYear ? item.productionYear.map(String.init) : nil
        let tag = (kind.hasYear ? item.preferredPrimaryImageTag : item.primaryImageTag).flatMap { $0.isEmpty ? nil : $0 }
        let token = client.accessToken.flatMap { $0.isEmpty ? nil : $0 }
        let key = EmbyPosterImageRequestKey(baseURL: client.baseURL, accessToken: token, itemID: kind.hasYear ? item.preferredPrimaryImageItemId : item.id, tag: tag, pixelWidth: pixelWidth)
        imageRequest = retainedRequests[key] ?? EmbyPosterImageRequest(key: key, client: client)
        progress = kind == .media ? item.playbackProgress : 0; unplayed = kind == .media ? item.userData?.unplayedItemCount ?? 0 : 0; played = kind == .media && item.isPlayed
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
    private let folderBadge = UIView()
    private let folderIcon = UIImageView(image: UIImage(systemName: "folder.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
    private let badgeCheck = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)))
    private(set) var record: EmbyPosterRecord?
    private var subscription: UUID?
    private var bindingGeneration = 0
    private let preparation: EmbyImagePreparation
    var onWork: ((EmbyPosterWorkTrace.Stage, Double) -> Void)?

    override init(frame: CGRect) { preparation = .shared; super.init(frame: frame); install() }
    init(preparation: EmbyImagePreparation) { self.preparation = preparation; super.init(frame: .zero); install() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func install() {
        artwork.contentMode = .scaleAspectFill; artwork.clipsToBounds = true
        artwork.backgroundColor = .secondarySystemBackground
        artwork.layer.cornerRadius = 10; artwork.layer.cornerCurve = .continuous
        placeholder.tintColor = .tertiaryLabel; placeholder.contentMode = .scaleAspectFit
        title.font = .preferredFont(forTextStyle: .subheadline); title.textColor = .label
        year.font = .preferredFont(forTextStyle: .caption1); year.textColor = .secondaryLabel
        title.lineBreakMode = .byTruncatingTail; year.lineBreakMode = .byTruncatingTail
        progress.backgroundColor = .systemBlue
        badge.font = .systemFont(ofSize: 11, weight: .bold); badge.textColor = .white; badge.textAlignment = .center
        badge.clipsToBounds = true; badgeCheck.tintColor = .white; badgeCheck.contentMode = .scaleAspectFit
        [artwork, placeholder, title, year, badge].forEach(contentView.addSubview)
        artwork.addSubview(progress)
        folderBadge.backgroundColor = UIColor.black.withAlphaComponent(0.55); folderBadge.layer.cornerRadius = 7; folderBadge.layer.cornerCurve = .continuous
        folderIcon.tintColor = .white; folderIcon.contentMode = .scaleAspectFit
        folderBadge.addSubview(folderIcon); artwork.addSubview(folderBadge); folderBadge.isHidden = true
        badge.addSubview(badgeCheck)
        isAccessibilityElement = true; accessibilityTraits = .button
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        title.font = .preferredFont(forTextStyle: .subheadline); year.font = .preferredFont(forTextStyle: .caption1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let height = floor(width / EmbyPosterGridMetrics.posterAspectRatio)
        artwork.frame = CGRect(x: 0, y: 0, width: width, height: height)
        placeholder.frame = CGRect(x: (width - 28) / 2, y: (height - 28) / 2, width: 28, height: 28)
        title.frame = CGRect(x: 0, y: height + 4, width: width, height: 20)
        year.frame = CGRect(x: 0, y: height + (record?.kind == .plainMedia ? 24 : 26), width: width, height: 16)
        progress.frame = CGRect(x: 0, y: height - 3, width: width * CGFloat(record?.progress ?? 0), height: 3)
        let badgeWidth = max(24, ceil(badge.intrinsicContentSize.width) + 12)
        badge.frame = CGRect(x: width - badgeWidth - 5, y: 5, width: badgeWidth, height: badgeWidth)
        badge.layer.cornerRadius = badgeWidth / 2
        badgeCheck.frame = badge.bounds.insetBy(dx: 6, dy: 6)
        folderBadge.frame = CGRect(x: 6, y: 6, width: 28, height: 26)
        folderIcon.frame = folderBadge.bounds.insetBy(dx: 6, dy: 6)
    }

    func configure(_ value: EmbyPosterRecord) {
        let started = CACurrentMediaTime()
        defer { onWork?(.configure, (CACurrentMediaTime() - started) * 1000) }
        if record == value { activate(); return }
        let requestChanged = record?.id != value.id || record?.url != value.url
        if requestChanged { deactivate(); artwork.image = value.url.flatMap(preparation.readyImage) }
        if record?.kind != value.kind { placeholder.image = UIImage(systemName: value.kind.placeholder) }
        record = value
        folderBadge.isHidden = value.kind != .folder
        title.text = value.name; year.text = value.year; year.isHidden = value.year == nil
        progress.isHidden = value.progress <= 0
        badge.isHidden = value.unplayed <= 0 && !value.played
        badge.text = value.unplayed > 0 ? String(value.unplayed) : nil
        badgeCheck.isHidden = value.unplayed > 0
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
            let started = CACurrentMediaTime()
            self.artwork.image = image; self.placeholder.isHidden = image != nil
            self.onWork?(.imageAdopt, (CACurrentMediaTime() - started) * 1000)
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
    var content: EmbyPosterWallContent = .media
    var queryIdentity: String = ""
    var allowsRefresh: Bool = true
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
    private var pixelWidth = 0
    private var width: CGFloat = 0
    private var visible = false
    private var foregroundObserver: NSObjectProtocol?
    private var pressureObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var lastOffset: CGFloat = 0
    private var frameSamples: [Double] = []
    private var imageConfigurationCount = 0
    private var lastMoving = false
    private var motion = EmbyPosterMotionTrace()
    private let traceID = String(UUID().uuidString.prefix(8))
    private var traceSequence = 0
    private var lastGeometry: [CGFloat] = []
    private var lastApproachRevision: Int?
    private var work = EmbyPosterWorkTrace()

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
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        trace("created", detail: "source_version=\(AppIdentity.sourceVersion) build=\(build)")
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in self?.prepareFirstScreen() }
        pressureObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in self?.cancelPrefetch() }
    }

    override func viewDidLayoutSubviews() {
        let started = CACurrentMediaTime()
        defer { work.record(.layout, milliseconds: (CACurrentMediaTime() - started) * 1000) }
        super.viewDidLayoutSubviews()
        let newWidth = floor((view.bounds.width - 28 - 24) / 3)
        guard newWidth > 0 else { return }
        let newPixelWidth = min(440, max(1, Int(ceil(newWidth * view.traitCollection.displayScale))))
        if width != newWidth || pixelWidth != newPixelWidth {
            width = newWidth; pixelWidth = newPixelWidth
            flow.itemSize = CGSize(width: width, height: floor(width / EmbyPosterGridMetrics.posterAspectRatio) + (input?.content.textHeight ?? 42))
            appliedRevision = nil; appliedReplacement = nil
            if let input { applyItems(input) }
        }
        prepareFirstScreen()
        let geometry = [collection.contentSize.height, collection.bounds.height, collection.adjustedContentInset.top, collection.adjustedContentInset.bottom]
        if geometry != lastGeometry { lastGeometry = geometry; trace("geometry") }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); visible = true; synchronizeActivity(); prepareFirstScreen()
        trace("view-appear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        trace("view-disappear")
        super.viewWillDisappear(animated); visible = false; synchronizeActivity(); cancelPrefetch(); reportFrames()
    }

    func update(_ value: EmbyPosterWall) {
        loadViewIfNeeded()
        let footerChanged = input?.isLoading != value.isLoading || input?.error != value.error || input?.hasLoaded != value.hasLoaded
        let insetChanged = collection.contentInset.bottom != value.bottomPadding
        if footerChanged || insetChanged { trace("update-before", detail: "next_loading=\(value.isLoading ? 1 : 0) next_revision=\(value.revision) next_count=\(value.items.count)") }
        input = value
        if !value.allowsRefresh, collection.refreshControl != nil { collection.refreshControl = nil }
        let itemHeight = floor(width / EmbyPosterGridMetrics.posterAspectRatio) + value.content.textHeight
        if width > 0, flow.itemSize.height != itemHeight {
            flow.itemSize.height = itemHeight
        }
        collection.contentInset.bottom = value.bottomPadding
        if width > 0 { applyItems(value) }
        if footerChanged { flow.invalidateLayout(); updateFooter() }
        // UIKit ends deceleration even when endRefreshing is called on an inactive control.
        // Only a real refresh owns this completion; ordinary paging must not stop native inertia.
        if !value.isLoading, collection.refreshControl?.isRefreshing == true {
            trace("end-refresh-before")
            collection.refreshControl?.endRefreshing()
            trace("end-refresh-after")
        }
        if footerChanged || insetChanged { trace("update-after") }
        synchronizeActivity()
    }

    private func applyItems(_ value: EmbyPosterWall) {
        let baseIdentity = "\(value.client.baseURL.absoluteString)|\(value.client.userId ?? "")"
        let identity = value.queryIdentity.isEmpty && value.content == .media ? baseIdentity : "\(baseIdentity)|\(value.queryIdentity)|\(value.content)"
        guard appliedRevision != value.revision || sourceIdentity != identity else { return }
        let started = CACurrentMediaTime()
        defer { work.record(.apply, milliseconds: (CACurrentMediaTime() - started) * 1000) }
        let old = records
        trace("items-before", detail: "next_count=\(value.items.count) next_revision=\(value.revision)")
        let append = sourceIdentity == identity && appliedReplacement == value.replacement && value.items.count > old.count
        if sourceIdentity == identity && appliedReplacement == value.replacement && value.items.count == old.count {
            appliedRevision = value.revision
            return
        }
        let newItems = append ? Array(value.items.dropFirst(old.count)) : value.items
        let retainedRequests = append ? [:] : Dictionary(old.map { ($0.imageRequest.key, $0.imageRequest) }, uniquingKeysWith: { first, next in first.isResolved ? first : next })
        let changed = newItems.map { EmbyPosterRecord(item: $0, client: value.client, pixelWidth: pixelWidth, sourceIdentity: identity, retainedRequests: retainedRequests, kind: value.content.kind(for: $0)) }
        let next = append ? old + changed : changed
        let sameIDs = !append && sourceIdentity == identity && next.map(\.id) == old.map(\.id)
        let recordsFinished = CACurrentMediaTime()
        appliedReplacement = value.replacement
        items = value.items; records = next; appliedRevision = value.revision; sourceIdentity = identity
        if append {
            let paths = (old.count..<next.count).map { IndexPath(item: $0, section: 0) }
            trace("batch-begin", detail: "old_count=\(old.count)")
            UIView.performWithoutAnimation {
                collection.performBatchUpdates({ collection.insertItems(at: paths) }) { [weak self] finished in
                    self?.trace("batch-complete", detail: "finished=\(finished ? 1 : 0)")
                }
            }
        } else if sameIDs {
            for path in collection.indexPathsForVisibleItems where next[path.item] != old[path.item] {
                (collection.cellForItem(at: path) as? EmbyPosterCell)?.configure(next[path.item])
            }
        } else {
            cancelPrefetch()
            UIView.performWithoutAnimation { collection.reloadData() }
        }
        let nativeFinished = CACurrentMediaTime()
        // Update image-demand membership on real data changes; ordinary SwiftUI updates do not scan items.
        // A retained prefetch URL is already materialized; membership must not resolve the entire library.
        if !append { cancelPrefetch(except: Set(next.compactMap { $0.imageRequest.resolvedURL })) }
        let membershipFinished = CACurrentMediaTime()
        prepareFirstScreen()
        let firstScreenFinished = CACurrentMediaTime()
        trace("items-after", detail: "append=\(append ? 1 : 0) same_ids=\(sameIDs ? 1 : 0)")
        DiagnosticsLogger.shared.log("PosterWall", "event=items count=\(next.count) append=\(append ? 1 : 0) same_ids=\(sameIDs ? 1 : 0) apply_ms=\(String(format: "%.2f", (CACurrentMediaTime() - started) * 1000)) records_ms=\((recordsFinished - started) * 1000) native_submit_ms=\((nativeFinished - recordsFinished) * 1000) membership_ms=\((membershipFinished - nativeFinished) * 1000) first_screen_ms=\((firstScreenFinished - membershipFinished) * 1000)")
    }

    private func prepareFirstScreen() {
        guard width > 0, view.bounds.height > 0 else { return }
        let rowHeight = input?.content == .folders ? floor(width / EmbyPosterGridMetrics.posterAspectRatio) + 24 : flow.itemSize.height
        let count = min(18, (Int(ceil(view.bounds.height / (rowHeight + flow.minimumLineSpacing))) + 1) * 3)
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

    @objc private func refreshTriggered() { trace("refresh-triggered"); input?.onRefresh() }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { records.count }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard input?.content != .media else { return flow.itemSize }
        // The old three-column HStack reserved the tallest card in each mixed folder row.
        let start = (indexPath.item / 3) * 3
        let textHeight = records[start..<min(start + 3, records.count)].map { $0.kind.textHeight }.max() ?? 24
        return CGSize(width: width, height: floor(width / EmbyPosterGridMetrics.posterAspectRatio) + textHeight)
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmbyPosterCell.reuseID, for: indexPath) as! EmbyPosterCell
        cell.onWork = { [weak self] stage, milliseconds in self?.work.record(stage, milliseconds: milliseconds) }
        cell.configure(records[indexPath.item]); imageConfigurationCount += 1
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? EmbyPosterCell)?.activate()
        if let url = records[indexPath.item].url, let token = prefetch.removeValue(forKey: url) { preparation.cancel(token) }
        if indexPath.item >= records.count - EmbyPosterGridMetrics.loadAheadItemCount {
            if lastApproachRevision != appliedRevision { lastApproachRevision = appliedRevision; trace("approaching-end", detail: "index=\(indexPath.item)") }
            input?.onApproachingEnd()
        }
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
            guard let url = records[path.item].imageRequest.resolvedURL, let token = prefetch.removeValue(forKey: url) else { continue }
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
        sampleFrame(at: link.timestamp)
    }
    func sampleFrame(at timestamp: CFTimeInterval) {
        let moving = collection.isDragging || collection.isDecelerating
        let offset = collection.contentOffset.y
        if moving || lastMoving {
            motion.append(.init(time: timestamp, offset: offset, maximum: maximumOffset, count: records.count, dragging: collection.isDragging, decelerating: collection.isDecelerating))
        }
        if lastFrame > 0, moving || lastMoving {
            let ms = (timestamp - lastFrame) * 1000
            frameSamples.append(ms)
            if ms >= 25 {
                let inBounds = offset >= -collection.adjustedContentInset.top && offset <= max(-collection.adjustedContentInset.top, collection.contentSize.height - collection.bounds.height + collection.adjustedContentInset.bottom)
                DiagnosticsLogger.shared.log("PosterWall", "event=gap ms=\(String(format: "%.2f", ms)) offset=\(String(format: "%.1f", offset)) delta=\(String(format: "%.1f", offset - lastOffset)) in_bounds=\(inBounds ? 1 : 0) dragging=\(collection.isDragging ? 1 : 0) demands=\(preparation.demandCount) tasks=\(preparation.activeTaskCount) pins=\(preparation.firstScreenCount)")
                trace("gap-state", detail: "ms=\(ms)"); reportMotion("gap")
            }
            if frameSamples.count >= 1200 { reportFrames() }
        }
        if lastMoving && !moving { trace("motion-stopped"); reportMotion("stopped") }
        lastFrame = timestamp; lastOffset = offset; lastMoving = moving
    }

    private var maximumOffset: CGFloat { max(-collection.adjustedContentInset.top, collection.contentSize.height - collection.bounds.height + collection.adjustedContentInset.bottom) }
    private func trace(_ event: String, detail: String = "") {
        guard traceSequence < 4096 else { return }
        traceSequence += 1
        let paths = collection.indexPathsForVisibleItems.map(\.item)
        let velocity = collection.panGestureRecognizer.velocity(in: collection).y
        let footer = records.isEmpty ? 132 : (input?.error != nil || input?.isLoading == true ? 52 : 0)
        let numeric = String(format: "uptime=%.3f offset=%.2f size=%.2f viewport=%.2f top=%.2f bottom=%.2f max=%.2f remaining=%.2f pan_velocity=%.2f", ProcessInfo.processInfo.systemUptime, collection.contentOffset.y, collection.contentSize.height, collection.bounds.height, collection.adjustedContentInset.top, collection.adjustedContentInset.bottom, maximumOffset, maximumOffset - collection.contentOffset.y, velocity)
        DiagnosticsLogger.shared.log("PosterWall", "event=\(event) wall=\(traceID) seq=\(traceSequence) \(numeric) count=\(records.count) revision=\(appliedRevision ?? -1) replacement=\(appliedReplacement ?? -1) loading=\(input?.isLoading == true ? 1 : 0) footer=\(footer) visible=\(paths.min() ?? -1):\(paths.max() ?? -1) dragging=\(collection.isDragging ? 1 : 0) decelerating=\(collection.isDecelerating ? 1 : 0) tracking=\(collection.isTracking ? 1 : 0) refreshing=\(collection.refreshControl?.isRefreshing == true ? 1 : 0) pan=\(collection.panGestureRecognizer.state.rawValue) \(detail)")
    }
    private func reportMotion(_ reason: String) {
        guard traceSequence < 4096, let first = motion.samples.first else { return }
        let values = motion.samples.map { String(format: "%.1f:%.1f:%.1f:%d:%d:%d", ($0.time - first.time) * 1000, $0.offset, $0.maximum, $0.count, $0.dragging ? 1 : 0, $0.decelerating ? 1 : 0) }.joined(separator: ",")
        traceSequence += 1
        DiagnosticsLogger.shared.log("PosterWall", "event=motion-tail wall=\(traceID) seq=\(traceSequence) reason=\(reason) first_uptime=\(first.time) columns=relative_ms:offset:max:count:drag:decel samples=\(values)")
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { trace("drag-begin") }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { trace("drag-end", detail: "will_decelerate=\(decelerate ? 1 : 0)") }
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) { trace("deceleration-begin") }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { trace("deceleration-end"); reportMotion("delegate-end") }
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { trace("return-top") }
    private func reportFrames() {
        for stage in EmbyPosterWorkTrace.Stage.allCases {
            let cost = work.costs[stage.rawValue]
            if cost.count > 0 { trace("work", detail: "stage=\(stage) calls=\(cost.count) total_ms=\(cost.total) max_ms=\(cost.maximum) ge8_33=\(cost.overBudget)") }
        }
        work.reset()
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
