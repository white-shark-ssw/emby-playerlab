import SwiftUI
import UIKit

enum EmbyPosterRowStyle { case poster, person, landscape, library
    var width: CGFloat { self == .landscape ? 212 : (self == .library ? 164 : 118) }
    func height(width: CGFloat) -> CGFloat {
        if self == .landscape { return 164 }
        if self == .library { return 118 }
        return floor(width / EmbyPosterGridMetrics.posterAspectRatio) + (self == .person ? 24 : 42)
    }
}

// Pages retain metadata, query and navigation ownership. These are presentation inputs only.
struct EmbyPosterSection {
    let id: String
    let title: String
    let items: [LibraryItem]
    let client: EmbyAPIClient
    var style: EmbyPosterRowStyle = .poster
    var width: CGFloat? = nil
    var spacing: CGFloat = 12
    var titleGap: CGFloat = 10
    var onMore: (() -> Void)? = nil
    let onSelect: (LibraryItem) -> Void
    var cardWidth: CGFloat { width ?? style.width }
    var rowHeight: CGFloat { style.height(width: cardWidth) }
    var source: String { "\(client.baseURL.absoluteString)|\(client.userId ?? "")|\(id)" }
}

struct EmbyPosterSectionCard: Equatable {
    let poster: EmbyPosterRecord
    let style: EmbyPosterRowStyle
    let subtitle: String
    let specialURL: URL?
    var url: URL? { style == .poster || style == .person ? poster.url : specialURL }
    init(item: LibraryItem, section: EmbyPosterSection, retained: [EmbyPosterImageRequestKey: EmbyPosterImageRequest]) {
        style = section.style
        let pixels = style == .person ? max(1, Int(ceil(section.cardWidth * UIScreen.main.scale))) : 440
        poster = EmbyPosterRecord(item: item, client: section.client, pixelWidth: pixels, sourceIdentity: section.source, retainedRequests: retained, kind: style == .person ? .person : .media)
        subtitle = style == .landscape ? v3MediaSubtitle(item) : ""
        if style == .landscape { specialURL = section.client.imageURL(itemId: item.id, imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop", maxWidth: 650, tag: item.backdropImageTags.first ?? item.primaryImageTag) }
        else if style == .library { specialURL = section.client.imageURL(itemId: item.id, maxWidth: 480, tag: item.primaryImageTag) }
        else { specialURL = nil }
    }
}

final class EmbyPosterWideCell: UICollectionViewCell {
    private let artwork = UIImageView()
    private let placeholder = UIImageView(image: UIImage(systemName: "play.rectangle"))
    private let title = UILabel()
    private let subtitle = UILabel()
    private let progress = UIView()
    private(set) var card: EmbyPosterSectionCard?
    private var subscription: UUID?
    private var generation = 0
    private let preparation: EmbyImagePreparation
    var onWork: ((EmbyPosterWorkTrace.Stage, Double) -> Void)?
    override init(frame: CGRect) { preparation = .shared; super.init(frame: frame); install() }
    init(preparation: EmbyImagePreparation) { self.preparation = preparation; super.init(frame: .zero); install() }
    private func install() {
        artwork.contentMode = .scaleAspectFill; artwork.clipsToBounds = true; artwork.backgroundColor = .secondarySystemBackground
        artwork.layer.cornerRadius = 9; artwork.layer.cornerCurve = .continuous
        placeholder.contentMode = .scaleAspectFit; placeholder.tintColor = .tertiaryLabel
        title.textColor = .label; title.lineBreakMode = .byTruncatingTail
        subtitle.font = .preferredFont(forTextStyle: .caption1); subtitle.textColor = .secondaryLabel; subtitle.lineBreakMode = .byTruncatingTail
        progress.backgroundColor = .systemBlue
        [artwork, placeholder, title, subtitle].forEach(contentView.addSubview); artwork.addSubview(progress)
        isAccessibilityElement = true; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let library = card?.style == .library, imageHeight: CGFloat = library ? 92 : 120
        artwork.frame = CGRect(x: 0, y: 0, width: bounds.width, height: imageHeight)
        placeholder.frame = CGRect(x: (bounds.width - 28) / 2, y: (imageHeight - 28) / 2, width: 28, height: 28)
        title.frame = CGRect(x: 0, y: imageHeight + (library ? 6 : 5), width: bounds.width, height: 20)
        subtitle.frame = CGRect(x: 0, y: 145, width: bounds.width, height: 19)
        progress.frame = CGRect(x: 0, y: imageHeight - 3, width: bounds.width * CGFloat(card?.poster.progress ?? 0), height: 3)
    }
    func configure(_ value: EmbyPosterSectionCard) {
        let started = CACurrentMediaTime()
        defer { onWork?(.configure, (CACurrentMediaTime() - started) * 1000) }
        if card == value { activate(); return }
        if card?.poster.id != value.poster.id || card?.url != value.url { deactivate(); artwork.image = value.url.flatMap(preparation.readyImage) }
        card = value; title.text = value.poster.name; subtitle.text = value.subtitle
        let library = value.style == .library
        title.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: library ? .medium : .semibold)
        title.textAlignment = library ? .center : .left
        subtitle.isHidden = library; progress.isHidden = library || value.poster.progress <= 0
        placeholder.isHidden = artwork.image != nil
        accessibilityLabel = [value.poster.name, value.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        setNeedsLayout(); activate()
    }
    func activate() {
        guard subscription == nil, let value = card, let url = value.url else { return }
        let expected = generation
        subscription = preparation.subscribe(url, priority: .visible) { [weak self] image in
            guard let self, self.generation == expected, self.card?.poster.id == value.poster.id, self.card?.url == url else { return }
            let started = CACurrentMediaTime()
            self.artwork.image = image; self.placeholder.isHidden = image != nil
            self.onWork?(.imageAdopt, (CACurrentMediaTime() - started) * 1000)
        }
    }
    func deactivate() { generation += 1; if let subscription { preparation.cancel(subscription) }; subscription = nil }
    override func prepareForReuse() { super.prepareForReuse(); deactivate(); card = nil; artwork.image = nil }
    var displayedImage: UIImage? { artwork.image }
}

// One page-wide prefetch demand budget, shared by every visible horizontal row.
@MainActor final class EmbyPosterSectionPrefetchBudget {
    private var tokens: [UUID: [URL: UUID]] = [:]
    var count: Int { tokens.values.reduce(0) { $0 + $1.count } }
    func subscribe(owner: UUID, url: URL) {
        guard tokens[owner]?[url] == nil, count < 12 else { return }
        tokens[owner, default: [:]][url] = EmbyImagePreparation.shared.subscribe(url, priority: .prefetch) { _ in }
    }
    func cancel(owner: UUID, url: URL) { if let token = tokens[owner]?.removeValue(forKey: url) { EmbyImagePreparation.shared.cancel(token) }; if tokens[owner]?.isEmpty == true { tokens.removeValue(forKey: owner) } }
    func cancel(owner: UUID) { let requests = tokens.removeValue(forKey: owner) ?? [:]; requests.values.forEach(EmbyImagePreparation.shared.cancel) }
}

final class EmbyPosterHorizontalRow: UICollectionViewCell, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {
    private let flow = UICollectionViewFlowLayout()
    private(set) lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: flow)
    private(set) var section: EmbyPosterSection?
    private(set) var cards: [EmbyPosterSectionCard] = []
    private let prefetchOwner = UUID()
    var prefetchBudget = EmbyPosterSectionPrefetchBudget()
    private var active = false
    var onOffset: ((String, CGFloat) -> Void)?
    var onWork: ((EmbyPosterWorkTrace.Stage, Double) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        flow.scrollDirection = .horizontal; flow.minimumLineSpacing = 12; flow.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collection.backgroundColor = .clear; collection.showsHorizontalScrollIndicator = false; collection.scrollsToTop = false
        collection.dataSource = self; collection.delegate = self; collection.prefetchDataSource = self
        collection.register(EmbyPosterCell.self, forCellWithReuseIdentifier: "poster")
        collection.register(EmbyPosterWideCell.self, forCellWithReuseIdentifier: "wide")
        collection.accessibilityIdentifier = "poster-horizontal"
        contentView.addSubview(collection)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); collection.frame = contentView.bounds }
    func configure(_ input: EmbyPosterSection, offset: CGFloat) {
        let changedSource = section?.source != input.source
        if let previous = section, changedSource { onOffset?(previous.source, collection.contentOffset.x) }
        let retained = Dictionary(cards.map { ($0.poster.imageRequest.key, $0.poster.imageRequest) }, uniquingKeysWith: { first, _ in first })
        let next = input.items.map { EmbyPosterSectionCard(item: $0, section: input, retained: retained) }
        let oldIDs = cards.map { $0.poster.id }, newIDs = next.map { $0.poster.id }
        let geometryChanged = section?.cardWidth != input.cardWidth || section?.rowHeight != input.rowHeight || section?.spacing != input.spacing
        section = input
        if flow.minimumLineSpacing != input.spacing { flow.minimumLineSpacing = input.spacing }
        if cards != next {
            cards = next; cancelPrefetch()
            if changedSource || oldIDs != newIDs || geometryChanged { collection.reloadData() }
            else { for index in collection.indexPathsForVisibleItems { configureCell(collection.cellForItem(at: index), index: index.item) } }
        } else if geometryChanged { flow.invalidateLayout() }
        if changedSource { collection.layoutIfNeeded(); collection.setContentOffset(CGPoint(x: offset, y: 0), animated: false) }
        if active { activate() }
    }
    func activate() {
        active = true
        for path in collection.indexPathsForVisibleItems { configureCell(collection.cellForItem(at: path), index: path.item) }
    }
    func deactivate() {
        active = false; cancelPrefetch()
        if let section { onOffset?(section.source, collection.contentOffset.x) }
        // Offscreen rows retain lightweight metadata/position, not a second image cache.
        collection.visibleCells.forEach { $0.prepareForReuse() }
    }
    private func cancelPrefetch() { prefetchBudget.cancel(owner: prefetchOwner) }
    private func configureCell(_ cell: UICollectionViewCell?, index: Int) {
        guard active, cards.indices.contains(index) else { return }
        if let poster = cell as? EmbyPosterCell { poster.onWork = onWork; poster.configure(cards[index].poster) }
        else if let wide = cell as? EmbyPosterWideCell { wide.onWork = onWork; wide.configure(cards[index]) }
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { cards.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let wide = cards[indexPath.item].style == .library || cards[indexPath.item].style == .landscape
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: wide ? "wide" : "poster", for: indexPath)
        configureCell(cell, index: indexPath.item); return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize { CGSize(width: section?.cardWidth ?? 118, height: section?.rowHeight ?? 219) }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) { configureCell(cell, index: indexPath.item) }
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) { cell.prepareForReuse() }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard active, !collectionView.isDragging, !collectionView.isDecelerating, let section, section.items.indices.contains(indexPath.item) else { return }
        section.onSelect(section.items[indexPath.item])
    }
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard active else { return }
        for path in indexPaths where prefetchBudget.count < 12 && cards.indices.contains(path.item) {
            guard let url = cards[path.item].url else { continue }
            prefetchBudget.subscribe(owner: prefetchOwner, url: url)
        }
    }
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for path in indexPaths where cards.indices.contains(path.item) { if let url = cards[path.item].url { prefetchBudget.cancel(owner: prefetchOwner, url: url) } }
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { if let section { onOffset?(section.source, scrollView.contentOffset.x) } }
    override func prepareForReuse() { super.prepareForReuse(); deactivate(); section = nil; cards = [] }
}

private final class EmbyPosterSectionHeader: UICollectionReusableView {
    let title = UILabel()
    let more = UIButton(type: .system)
    var action: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        title.font = .systemFont(ofSize: 20, weight: .bold); title.textColor = .label; title.lineBreakMode = .byTruncatingTail
        more.setTitle("更多", for: .normal); more.titleLabel?.font = .systemFont(ofSize: 16)
        more.addTarget(self, action: #selector(openMore), for: .touchUpInside)
        addSubview(title); addSubview(more)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        title.frame = CGRect(x: 16, y: 0, width: bounds.width - (more.isHidden ? 32 : 96), height: 24)
        more.frame = CGRect(x: bounds.width - 76, y: 0, width: 60, height: 24)
    }
    @objc private func openMore() { action?() }
}

private final class EmbyPosterSectionTop: UICollectionReusableView {}
private final class EmbyPosterSectionStatus: UICollectionReusableView {
    let title = UILabel()
    let spinner = UIActivityIndicatorView(style: .medium)
    override init(frame: CGRect) { super.init(frame: frame); title.font = .preferredFont(forTextStyle: .footnote); title.numberOfLines = 0; addSubview(title); addSubview(spinner) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); title.frame = bounds.insetBy(dx: 16, dy: 8); spinner.center = CGPoint(x: bounds.midX, y: 26) }
}

private struct EmbyPosterSectionTopContent<Content: View>: View {
    let content: Content
    var body: some View { content.ignoresSafeArea(.container) }
}

struct EmbyPosterSections<Top: View>: UIViewControllerRepresentable {
    let sections: [EmbyPosterSection]
    let queryIdentity: String
    var topHeight: CGFloat = 0
    var topPadding: CGFloat = 0
    var sectionGap: CGFloat = 28
    let bottomPadding: CGFloat
    var isLoading = false
    var emptyText: String? = nil
    var error: String? = nil
    var isActive = true
    var scrollToTopToken = 0
    var onRefresh: (() -> Void)? = nil
    var onHomeOffset: ((CGFloat) -> Void)? = nil
    var onHomeRefresh: ((@escaping () -> Void) -> Void)? = nil
    let top: Top

    func makeUIViewController(context: Context) -> EmbyPosterSectionsController {
        let controller = EmbyPosterSectionsController()
        let host = UIHostingController(rootView: EmbyPosterSectionTopContent(content: top))
        host.view.backgroundColor = .clear; controller.installTop(host)
        return controller
    }
    func updateUIViewController(_ controller: EmbyPosterSectionsController, context: Context) {
        (controller.topHost as? UIHostingController<EmbyPosterSectionTopContent<Top>>)?.rootView = EmbyPosterSectionTopContent(content: top)
        controller.update(sections: sections, query: queryIdentity, topHeight: topHeight, topPadding: topPadding, gap: sectionGap, bottom: bottomPadding, loading: isLoading, empty: emptyText, error: error, active: isActive, topToken: scrollToTopToken, refresh: onRefresh, homeOffset: onHomeOffset, homeRefresh: onHomeRefresh)
    }
    static func dismantleUIViewController(_ controller: EmbyPosterSectionsController, coordinator: ()) { controller.dispose() }
}

final class EmbyPosterSectionsController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let flow = UICollectionViewFlowLayout()
    private(set) lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: flow)
    private(set) var sections: [EmbyPosterSection] = []
    private(set) var topHost: UIViewController?
    private var query: String?
    private var offsets: [String: CGFloat] = [:]
    private var topHeight: CGFloat = 0
    private var topPadding: CGFloat = 0
    private var gap: CGFloat = 28
    private var active = false
    private var visible = false
    private var topToken: Int?
    private var refreshAction: (() -> Void)?
    private var loading = false
    private var empty: String?
    private var error: String?
    private let refreshControl = UIRefreshControl()
    private let firstScreenOwner = UUID()
    private let prefetchBudget = EmbyPosterSectionPrefetchBudget()
    private var offsetBridge: V3HomeScrollOffsetObserver.Coordinator?
    private var ownedRefresh: V3HomeOwnedRefreshControl.Coordinator?
    private var foreground: NSObjectProtocol?
    private var pressure: NSObjectProtocol?
    private var layoutWidth: CGFloat = 0
    private var work = EmbyPosterWorkTrace()
    private var displayLink: CADisplayLink?
    private var lastStamp: CFTimeInterval = 0
    private var lastMoving = false
    private var frameSamples: [Double] = []
    private var traceCount = 0
    private let traceID = String(UUID().uuidString.prefix(8))
    override func viewDidLoad() {
        super.viewDidLoad()
        flow.minimumLineSpacing = 0; flow.minimumInteritemSpacing = 0
        collection.backgroundColor = .clear; collection.showsVerticalScrollIndicator = false; collection.alwaysBounceVertical = true
        collection.dataSource = self; collection.delegate = self; collection.contentInsetAdjustmentBehavior = .never
        collection.accessibilityIdentifier = "poster-sections"
        collection.register(EmbyPosterHorizontalRow.self, forCellWithReuseIdentifier: "row")
        collection.register(EmbyPosterSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        collection.register(EmbyPosterSectionTop.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "top")
        collection.register(EmbyPosterSectionStatus.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "status")
        refreshControl.tintColor = .label; refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        view.backgroundColor = .clear; view.addSubview(collection)
        foreground = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in self?.activateResources() }
        pressure = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.active && self.visible else { return }
            DispatchQueue.main.async { [weak self] in self?.prepareFirstScreen() }
        }
    }
    func installTop(_ host: UIViewController) { loadViewIfNeeded(); topHost = host; addChild(host); host.didMove(toParent: self) }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); collection.frame = view.bounds
        if layoutWidth != view.bounds.width { layoutWidth = view.bounds.width; flow.invalidateLayout(); prepareFirstScreen() }
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); visible = true; activateResources() }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); visible = false; collection.scrollsToTop = false; rows.forEach { $0.deactivate() }; displayLink?.invalidate(); displayLink = nil; reportFrames(); trace("disappear") }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); visible = true; activateResources() }
    var rows: [EmbyPosterHorizontalRow] { collection.visibleCells.compactMap { $0 as? EmbyPosterHorizontalRow } }
    func update(sections next: [EmbyPosterSection], query: String, topHeight: CGFloat, topPadding: CGFloat, gap: CGFloat, bottom: CGFloat, loading: Bool, empty: String?, error: String?, active: Bool, topToken: Int, refresh: (() -> Void)?, homeOffset: ((CGFloat) -> Void)?, homeRefresh: ((@escaping () -> Void) -> Void)?) {
        let started = CACurrentMediaTime()
        defer { work.record(.apply, milliseconds: (CACurrentMediaTime() - started) * 1000) }
        loadViewIfNeeded()
        let changedQuery = self.query != nil && self.query != query
        let oldShape = sections.map { "\($0.source)|\($0.title)|\($0.cardWidth)|\($0.rowHeight)|\($0.titleGap)" }
        let newShape = next.map { "\($0.source)|\($0.title)|\($0.cardWidth)|\($0.rowHeight)|\($0.titleGap)" }
        let structureChanged = oldShape != newShape || self.topHeight != topHeight || self.topPadding != topPadding || self.gap != gap
        let statusChanged = self.loading != loading || self.empty != empty || self.error != error
        self.query = query; self.sections = next; self.topHeight = topHeight; self.topPadding = topPadding; self.gap = gap
        self.loading = loading; self.empty = empty; self.error = error; self.active = active; refreshAction = refresh
        offsets = offsets.filter { key, _ in next.contains { $0.source == key } }
        if changedQuery { offsets.removeAll(); rows.forEach { $0.deactivate() } }
        if collection.contentInset.bottom != bottom { collection.contentInset.bottom = bottom }
        if structureChanged || changedQuery { collection.reloadData() }
        else {
            for path in collection.indexPathsForVisibleItems where sections.indices.contains(path.section - 1) { configureRow(collection.cellForItem(at: path) as? EmbyPosterHorizontalRow, sectionIndex: path.section - 1) }
            for path in collection.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader) {
                if let header = collection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: path) as? EmbyPosterSectionHeader { configureHeader(header, index: path.section - 1) }
            }
            if statusChanged { flow.invalidateLayout(); configureStatus() }
        }
        if let homeOffset {
            if offsetBridge == nil { offsetBridge = V3HomeScrollOffsetObserver.Coordinator(onChange: homeOffset) }
            offsetBridge?.onChange = homeOffset; offsetBridge?.attach(from: collection)
        } else { offsetBridge?.detach(); offsetBridge = nil }
        if let homeRefresh {
            if ownedRefresh == nil { ownedRefresh = V3HomeOwnedRefreshControl.Coordinator(onRefresh: homeRefresh) }
            ownedRefresh?.onRefresh = homeRefresh; ownedRefresh?.attach(from: collection)
        } else {
            ownedRefresh?.detach(); ownedRefresh = nil
            let control: UIRefreshControl? = refresh == nil ? nil : refreshControl
            if collection.refreshControl !== control { collection.refreshControl = control }
            if !loading { refreshControl.endRefreshing() }
        }
        if let old = self.topToken, old != topToken { UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) { self.collection.setContentOffset(CGPoint(x: 0, y: -self.collection.adjustedContentInset.top), animated: false) } }
        self.topToken = topToken
        if changedQuery { collection.setContentOffset(.zero, animated: false) }
        topHost?.view.frame = CGRect(x: 0, y: 0, width: collection.bounds.width, height: topHeight)
        activateResources()
    }
    private func configureRow(_ row: EmbyPosterHorizontalRow?, sectionIndex: Int) {
        guard let row, sections.indices.contains(sectionIndex) else { return }
        row.onWork = { [weak self] stage, ms in self?.work.record(stage, milliseconds: ms) }
        row.prefetchBudget = prefetchBudget
        row.onOffset = { [weak self] source, offset in self?.offsets[source] = offset }
        let section = sections[sectionIndex]; row.configure(section, offset: offsets[section.source] ?? 0)
        if active && visible { row.activate() } else { row.deactivate() }
    }
    private func configureHeader(_ header: EmbyPosterSectionHeader, index: Int) {
        guard sections.indices.contains(index) else { return }
        header.title.text = sections[index].title; header.action = sections[index].onMore; header.more.isHidden = header.action == nil
    }
    private func configureStatus() {
        for view in collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            guard let status = view as? EmbyPosterSectionStatus else { continue }
            status.title.text = error ?? (sections.isEmpty && !loading ? empty : nil)
            status.title.textColor = error == nil ? .secondaryLabel : .systemRed
            if loading { status.spinner.startAnimating() } else { status.spinner.stopAnimating() }
        }
    }
    private func activateResources() {
        collection.scrollsToTop = active && visible
        if active && visible {
            rows.forEach { $0.activate() }; prepareFirstScreen()
            if displayLink == nil {
                lastStamp = 0; lastMoving = false
                let link = CADisplayLink(target: self, selector: #selector(frameTick(_:)))
                let rate = Float(UIScreen.main.maximumFramesPerSecond)
                link.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
                link.add(to: .main, forMode: .common); displayLink = link; trace("appear")
            }
        } else { rows.forEach { $0.deactivate() }; displayLink?.invalidate(); displayLink = nil; reportFrames() }
    }
    private func prepareFirstScreen() {
        guard active && visible, view.bounds.width > 0 else { return }
        var remainingHeight = view.bounds.height - topHeight - topPadding, urls: [URL] = []
        for section in sections where remainingHeight > 0 {
            let count = max(1, Int(ceil((view.bounds.width - 32) / (section.cardWidth + section.spacing)))) + 1
            let retained: [EmbyPosterImageRequestKey: EmbyPosterImageRequest] = [:]
            urls.append(contentsOf: section.items.prefix(count).compactMap { EmbyPosterSectionCard(item: $0, section: section, retained: retained).url })
            remainingHeight -= 24 + section.titleGap + section.rowHeight + gap
        }
        EmbyImagePreparation.shared.setFirstScreen(owner: firstScreenOwner, urls: urls)
    }
    @objc private func refresh() {
        let feedback = UIImpactFeedbackGenerator(style: .light); feedback.prepare(); feedback.impactOccurred(intensity: 0.55)
        refreshAction?()
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count + 2 }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { section > 0 && section <= sections.count ? 1 : 0 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let row = collectionView.dequeueReusableCell(withReuseIdentifier: "row", for: indexPath) as! EmbyPosterHorizontalRow
        configureRow(row, sectionIndex: indexPath.section - 1); return row
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) { configureRow(cell as? EmbyPosterHorizontalRow, sectionIndex: indexPath.section - 1) }
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) { (cell as? EmbyPosterHorizontalRow)?.deactivate() }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize { CGSize(width: max(1, collectionView.bounds.width), height: sections[indexPath.section - 1].rowHeight) }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let height: CGFloat
        if section == 0 { height = topHeight + topPadding }
        else if section == sections.count + 1 { height = loading || error != nil || (sections.isEmpty && empty != nil) ? 76 : 0 }
        else { height = 24 + sections[section - 1].titleGap }
        return CGSize(width: collectionView.bounds.width, height: height)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets { UIEdgeInsets(top: 0, left: 0, bottom: section > 0 && section <= sections.count ? gap : 0, right: 0) }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if indexPath.section == 0 {
            let top = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "top", for: indexPath)
            if let host = topHost { if host.view.superview !== top { top.addSubview(host.view) }; host.view.frame = CGRect(x: 0, y: 0, width: collectionView.bounds.width, height: topHeight); host.view.autoresizingMask = [.flexibleWidth] }
            return top
        }
        if indexPath.section == sections.count + 1 {
            let status = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "status", for: indexPath) as! EmbyPosterSectionStatus
            status.title.text = error ?? (sections.isEmpty && !loading ? empty : nil); status.title.textColor = error == nil ? .secondaryLabel : .systemRed
            if loading { status.spinner.startAnimating() } else { status.spinner.stopAnimating() }
            return status
        }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! EmbyPosterSectionHeader
        configureHeader(header, index: indexPath.section - 1); return header
    }
    @objc private func frameTick(_ link: CADisplayLink) {
        let moving = collection.isDragging || collection.isDecelerating || rows.contains { $0.collection.isDragging || $0.collection.isDecelerating }
        if lastStamp > 0 && (moving || lastMoving) {
            let ms = (link.timestamp - lastStamp) * 1000
            frameSamples.append(ms)
            if ms >= 25 { trace("gap", detail: "ms=\(ms)") }
            if frameSamples.count >= 1200 { reportFrames() }
        }
        if lastMoving && !moving { reportFrames() }
        lastMoving = moving; lastStamp = link.timestamp
    }
    private func trace(_ event: String, detail: String = "") {
        guard traceCount < 4096 else { return }; traceCount += 1
        DiagnosticsLogger.shared.log("PosterSections", "event=\(event) host=\(traceID) seq=\(traceCount) uptime=\(ProcessInfo.processInfo.systemUptime) offset=\(collection.contentOffset.y) sections=\(sections.count) prefetch=\(prefetchBudget.count) demands=\(EmbyImagePreparation.shared.demandCount) tasks=\(EmbyImagePreparation.shared.activeTaskCount) pins=\(EmbyImagePreparation.shared.firstScreenCount) \(detail)")
    }
    private func reportFrames() {
        for stage in EmbyPosterWorkTrace.Stage.allCases {
            let cost = work.costs[stage.rawValue]
            if cost.count > 0 { trace("work", detail: "stage=\(stage) calls=\(cost.count) total_ms=\(cost.total) max_ms=\(cost.maximum) ge8_33=\(cost.overBudget)") }
        }
        work.reset()
        if !frameSamples.isEmpty {
            let values = frameSamples.sorted()
            let percentile: (Double) -> Double = { values[min(values.count - 1, Int(Double(values.count - 1) * $0))] }
            trace("frames", detail: "samples=\(values.count) p50=\(percentile(0.5)) p95=\(percentile(0.95)) p99=\(percentile(0.99)) max=\(values.last ?? 0) ge16_7=\(values.filter { $0 >= 16.7 }.count) ge25=\(values.filter { $0 >= 25 }.count) ge33_3=\(values.filter { $0 >= 33.3 }.count)")
            frameSamples.removeAll(keepingCapacity: true)
        }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { trace("deceleration-end") }
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { trace("return-top") }
    func dispose() {
        displayLink?.invalidate(); displayLink = nil; reportFrames()
        rows.forEach { $0.deactivate() }; EmbyImagePreparation.shared.setFirstScreen(owner: firstScreenOwner, urls: [])
        offsetBridge?.detach(); ownedRefresh?.detach()
        if let foreground { NotificationCenter.default.removeObserver(foreground) }; if let pressure { NotificationCenter.default.removeObserver(pressure) }
    }
}
