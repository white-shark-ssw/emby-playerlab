import XCTest
import UIKit
import SwiftUI

@MainActor
private final class ImageGate {
    var calls: [URL: Int] = [:]
    var pending: [URL: CheckedContinuation<UIImage?, Never>] = [:]
    func load(_ url: URL) async -> UIImage? {
        calls[url, default: 0] += 1
        return await withCheckedContinuation { pending[url] = $0 }
    }
    func finish(_ url: URL, _ image: UIImage?) { pending.removeValue(forKey: url)?.resume(returning: image) }
}

@MainActor
final class PosterWallTests: XCTestCase {
    private func item(_ id: String, tag: String = "v1") -> LibraryItem {
        let data = try! JSONSerialization.data(withJSONObject: ["Id": id, "Name": "Movie \(id)", "Type": "Movie", "ProductionYear": 2026, "ImageTags": ["Primary": tag]])
        return try! JSONDecoder().decode(LibraryItem.self, from: data)
    }
    private func client() -> EmbyAPIClient { EmbyAPIClient(baseURL: URL(string: "https://\(UUID().uuidString).example.test")!) }
    private func drain() async { for _ in 0..<40 { await Task.yield() } }
    private func image(_ color: UIColor) -> UIImage { UIGraphicsImageRenderer(size: CGSize(width: 3, height: 3)).image { color.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 3, height: 3)) } }

    private func waitForRequests(_ count: Int, client: EmbyAPIClient) async -> Bool {
        // Cold simulator/utility-queue startup exceeded the old2s fixture deadline; this is not a latency assertion.
        for _ in 0..<1000 {
            if client.requests.count >= count { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Production model did not reach the controlled network boundary")
        return false
    }

    private func page(_ id: String) -> EmbyItemPage {
        let data = try! JSONSerialization.data(withJSONObject: ["Items": [["Id": id, "Name": id, "Type": "Movie"]], "TotalRecordCount": 1])
        return try! JSONDecoder().decode(EmbyItemPage.self, from: data)
    }

    private func page(start: Int, total: Int = 660) -> EmbyItemPage {
        let items = (start..<(start + 60)).map { ["Id": String($0), "Name": "Movie \($0)", "Type": "Movie"] }
        let data = try! JSONSerialization.data(withJSONObject: ["Items": items, "TotalRecordCount": total])
        return try! JSONDecoder().decode(EmbyItemPage.self, from: data)
    }

    func testTwoThousandItemsKeepFullGeometryWithBoundedURLDemandAndDeepAccess() {
        let source = client()
        let controller = EmbyPosterWallController()
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800)
        controller.viewDidLayoutSubviews()
        let values = (0..<2000).map { item(String($0)) }
        let value = EmbyPosterWall(items: values, revision: 1, replacement: 1, client: source, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in })
        controller.update(value); controller.collection.layoutIfNeeded()
        XCTAssertEqual(controller.collectionView(controller.collection, numberOfItemsInSection: 0), 2000)
        XCTAssertLessThanOrEqual(controller.records.filter { $0.imageRequest.isResolved }.count, 40)
        XCTAssertFalse(controller.records[1999].imageRequest.isResolved)
        let height = controller.collection.contentSize.height
        XCTAssertGreaterThan(height, 100000)
        let last = controller.records[1999]
        XCTAssertEqual(last.url, source.imageURL(itemId: "1999", maxWidth: last.imageRequest.key.pixelWidth, tag: "v1"))
        XCTAssertTrue(last.imageRequest.isResolved)
        XCTAssertEqual(controller.collection.contentSize.height, height)
        XCTAssertTrue(controller.records[1999].imageRequest === last.imageRequest)
        controller.dispose()
    }

    func testReplacementRetainsMaterializedRequestsAndPrefetchOnlyForUnchangedKeys() {
        let source = client()
        let controller = EmbyPosterWallController()
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800); controller.viewDidLayoutSubviews()
        var values = (0..<2000).map { item(String($0)) }
        func value(_ revision: Int) -> EmbyPosterWall { EmbyPosterWall(items: values, revision: revision, replacement: revision, client: source, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in }) }
        controller.update(value(1))
        controller.viewDidAppear(false)
        controller.collectionView(controller.collection, prefetchItemsAt: [IndexPath(item: 30, section: 0), IndexPath(item: 31, section: 0)])
        let unchanged = controller.records[30].imageRequest, changed = controller.records[31].imageRequest
        let retainedToken = controller.prefetch[unchanged.url!], removedURL = changed.url!
        XCTAssertNotNil(retainedToken); XCTAssertNotNil(controller.prefetch[removedURL])
        values[31] = item("31", tag: "v2")
        controller.update(value(2))
        XCTAssertTrue(controller.records[30].imageRequest === unchanged)
        XCTAssertEqual(controller.prefetch[unchanged.url!], retainedToken)
        XCTAssertNil(controller.prefetch[removedURL])
        XCTAssertFalse(controller.records[31].imageRequest === changed)
        XCTAssertFalse(controller.records[31].imageRequest.isResolved)
        XCTAssertFalse(controller.records[1999].imageRequest.isResolved)
        XCTAssertNotEqual(controller.records[31].url, removedURL)
        controller.dispose()
    }

    func testDemandRequestIdentityAndURLMatchActualAPIForRoutesTokensTagsAndWidths() {
        for base in ["https://example.invalid/emby", "https://example.invalid/代理?old=query"] {
            for token in [nil, "", "test +/&?token"] as [String?] {
                let source = EmbyAPIClient(baseURL: URL(string: base)!, accessToken: token)
                for width in [300, 700] {
                    let value = item("电影/a?#", tag: "tag +/&?")
                    let record = EmbyPosterRecord(item: value, client: source, pixelWidth: width)
                    let equivalent = EmbyPosterRecord(item: value, client: source, pixelWidth: width)
                    XCTAssertEqual(record, equivalent)
                    XCTAssertFalse(record.imageRequest.isResolved); XCTAssertFalse(equivalent.imageRequest.isResolved)
                    XCTAssertEqual(record.url, source.imageURL(itemId: value.preferredPrimaryImageItemId, maxWidth: width, tag: value.preferredPrimaryImageTag))
                    XCTAssertEqual(record.url, record.imageRequest.resolvedURL)
                    XCTAssertNotEqual(record.imageRequest.key, EmbyPosterRecord(item: value, client: source, pixelWidth: width + 1).imageRequest.key)
                    XCTAssertNotEqual(record.imageRequest.key, EmbyPosterRecord(item: item(value.id, tag: "new"), client: source, pixelWidth: width).imageRequest.key)
                }
            }
        }
    }

    func testActualEagerBaselineVersusDemandRecordPreparationMeasurement() {
        let source = client(), values = (0..<2000).map { item(String($0)) }
        let identity = "\(source.baseURL.absoluteString)|\(source.userId ?? "")"
        let oldStart = CACurrentMediaTime()
        let eager = values.map { EagerRecordBaseline(item: $0, client: source, pixelWidth: 300) }
        let eagerMS = (CACurrentMediaTime() - oldStart) * 1000
        let newStart = CACurrentMediaTime()
        let demand = values.map { EmbyPosterRecord(item: $0, client: source, pixelWidth: 300, sourceIdentity: identity) }
        let demandMS = (CACurrentMediaTime() - newStart) * 1000
        XCTAssertEqual(eager.map(\.id), demand.map(\.id)); XCTAssertEqual(eager.map(\.name), demand.map(\.name))
        XCTAssertEqual(eager.compactMap(\.url).count, 2000)
        XCTAssertEqual(demand.filter { $0.imageRequest.isResolved }.count, 0)
        for index in [0, 17, 1999] { XCTAssertEqual(eager[index].url, demand[index].url) }
        print("POSTER_RECORD_PREPARATION count=2000 eager_ms=\(eagerMS) demand_ms=\(demandMS) main_thread=\(Thread.isMainThread ? 1 : 0)")
        // Simulator timings are diagnostic, not a flaky speed assertion or a device FPS claim.
    }

    func testDetailScrollObservationReadsNativeExtentWithoutTakingGestureOrOffsetOwnership() {
        let controller = UIViewController(), scroll = UIScrollView()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 800))
        controller.view = scroll; window.rootViewController = controller; window.makeKeyAndVisible()
        scroll.contentSize = CGSize(width: 430, height: 1800); scroll.contentOffset.y = 200
        let probe = EmbyDetailScrollDiagnostics.Probe(), observer = EmbyDetailScrollDiagnostics.Coordinator()
        scroll.addSubview(probe)
        let enabled = scroll.panGestureRecognizer.isEnabled, delegate = scroll.delegate
        let start = DiagnosticsLogger.shared.records().count
        observer.attach(probe); observer.stop()
        XCTAssertEqual(scroll.contentOffset.y, 200); XCTAssertEqual(scroll.contentSize.height, 1800)
        XCTAssertEqual(scroll.panGestureRecognizer.isEnabled, enabled); XCTAssertTrue(scroll.delegate === delegate)
        let records = Array(DiagnosticsLogger.shared.records().dropFirst(start))
        XCTAssertTrue(records.contains { $0.contains("event=attach") && $0.contains("content_height=1800.0") && $0.contains("enabled=1") })
        XCTAssertTrue(records.contains { $0.contains("event=finish") })
        XCTAssertTrue(probe.gestureRecognizers?.isEmpty ?? true)
        window.isHidden = true
    }

    func testSameLivePageReappearancePreservesItemsRevisionReplacementAndFrontier() async {
        let source = client()
        source.automaticLibraryPages = true
        let model = V3LibraryBrowserViewModel(library: item("lib"), client: source)
        await model.load(tab: .items)
        await model.loadNextPage(tab: .items)
        let revision = model.posterRevision, replacement = model.posterReplacement
        for _ in 0..<3 { await model.load(tab: .items) }
        XCTAssertEqual(source.requests.count, 2)
        XCTAssertEqual(model.items(for: .items).map(\.id), (0..<120).map(String.init))
        XCTAssertEqual(model.posterRevision, revision); XCTAssertEqual(model.posterReplacement, replacement)
        await model.loadNextPage(tab: .items)
        XCTAssertEqual(source.requests[2].start, 120)
        await model.refresh(tab: .items)
        XCTAssertEqual(source.requests[3].start, 0)
        await model.changeSort(to: "SortName", tab: .items)
        XCTAssertEqual(source.requests[4].start, 0); XCTAssertEqual(source.requests[4].sort, "SortName")
        await model.load(tab: .items); XCTAssertEqual(source.requests.count, 5)
        // Failed new-sort data must not inherit the old successful query's reappearance validity.
        source.automaticLibraryPages = false
        let failedIndex = source.requests.count
        let failedSort = Task { await model.changeSort(to: "Runtime", tab: .items) }
        guard await waitForRequests(failedIndex + 1, client: source) else { return }
        source.requests[failedIndex].continuation.resume(throwing: URLError(.notConnectedToInternet))
        await failedSort.value
        source.automaticLibraryPages = true
        await model.load(tab: .items)
        XCTAssertEqual(source.requests.count, 7)
        XCTAssertEqual(source.requests.last?.sort, "Runtime")
        await model.load(tab: .items); XCTAssertEqual(source.requests.count, 7)
        // The sort key is shared by paged tabs; another tab's successful query is not Library.items data.
        await model.changeSort(to: "DatePlayed", tab: .trailers)
        await model.load(tab: .items)
        XCTAssertEqual(source.requests.count, 9)
        XCTAssertEqual(source.requests.last?.sort, "DatePlayed")
        await model.load(tab: .items); XCTAssertEqual(source.requests.count, 9)
    }

    func testFailedInitialLiveLoadCanRetryDespiteLoadedTabs() async {
        let source = client()
        let model = V3LibraryBrowserViewModel(library: item("lib"), client: source)
        let first = Task { await model.load(tab: .items) }
        guard await waitForRequests(1, client: source) else { return }
        source.requests[0].continuation.resume(throwing: URLError(.notConnectedToInternet)); await first.value
        XCTAssertTrue(model.hasLoaded(tab: .items))
        let retry = Task { await model.load(tab: .items) }
        guard await waitForRequests(2, client: source) else { return }
        XCTAssertEqual(source.requests[1].start, 0)
        source.requests[1].continuation.resume(returning: page(start: 0)); await retry.value
        await model.load(tab: .items); XCTAssertEqual(source.requests.count, 2)
    }

    func testDetailTimelineIsPerModelBoundedAndSectionAppearanceIsNotImageCompletion() {
        let start = DiagnosticsLogger.shared.records().count
        let trace = EmbyDetailLoadTrace()
        trace.mark("detail-appear")
        trace.mark("images-published", images: 4, stills: 2)
        trace.sectionAppeared(images: 4, stills: 2)
        trace.sectionAppeared(images: 4, stills: 2)
        for _ in 0..<100 { trace.mark("task-enter") }
        let records = Array(DiagnosticsLogger.shared.records().dropFirst(start))
        XCTAssertEqual(records.count, 64)
        XCTAssertEqual(records.filter { $0.contains("event=stills-section-appear") }.count, 1)
        XCTAssertTrue(records[2].contains("stills=2"))
        XCTAssertTrue(records.allSatisfy { $0.contains("main_thread=1") && !$0.contains("http") })
        let other = EmbyDetailLoadTrace(); other.mark("detail-appear")
        let firstID = records[0].split(separator: " ").first { $0.hasPrefix("model=") }
        let otherID = DiagnosticsLogger.shared.records().last!.split(separator: " ").first { $0.hasPrefix("model=") }
        XCTAssertNotEqual(firstID, otherID)
    }

    func testWorkCountersStayFixedAndResetWithoutChangingPresentation() {
        var trace = EmbyPosterWorkTrace()
        for _ in 0..<5000 { trace.record(.configure, milliseconds: 0.5) }
        trace.record(.layout, milliseconds: 9)
        XCTAssertEqual(trace.costs.count, 4)
        XCTAssertEqual(trace.costs[0].count, 5000); XCTAssertEqual(trace.costs[0].total, 2500)
        XCTAssertEqual(trace.costs[2].overBudget, 1)
        trace.reset(); XCTAssertTrue(trace.costs.allSatisfy { $0.count == 0 && $0.total == 0 })
    }

    func testCachedFirstFailurePreservesMetadataAndPagingFrontier() async {
        let source = client()
        let snapshot = V3LibraryPersistentSnapshot(tabItems: ["items": [item("cached")]], suggestionResumeItems: [], suggestionLatestItems: [], genericSuggestionItems: [], recommendationSections: [], genres: [], folderItems: [], sortBy: "DateCreated", loadedTabs: ["items"], pageStates: ["items": V3PersistedPageState(nextStartIndex: 660, hasMore: true)])
        await V3PagePersistentCache.shared.storeLibrarySnapshot(snapshot, client: source, libraryID: "lib")
        let model = V3LibraryBrowserViewModel(library: item("lib"), client: source)
        let loading = Task { await model.load(tab: .items) }
        guard await waitForRequests(1, client: source) else { return }
        XCTAssertEqual(model.items(for: .items).map(\.id), ["cached"])
        XCTAssertEqual(source.requests.count, 1)
        source.requests[0].continuation.resume(throwing: URLError(.notConnectedToInternet))
        await loading.value
        XCTAssertEqual(model.items(for: .items).map(\.id), ["cached"])
        let paging = Task { await model.loadNextPage(tab: .items) }
        guard await waitForRequests(2, client: source) else { return }
        XCTAssertEqual(source.requests[1].start, 660)
        source.requests[1].continuation.resume(returning: page("next")); await paging.value
        XCTAssertEqual(model.items(for: .items).map(\.id), ["cached", "next"])
    }

    func testMotionHistoryKeepsTerminalStationaryFrameInsideFixedBudget() {
        var trace = EmbyPosterMotionTrace()
        for index in 0..<5000 {
            trace.append(.init(time: Double(index) / 120, offset: CGFloat(index), maximum: 6000, count: 120, dragging: false, decelerating: true))
        }
        trace.append(.init(time: 5000.0 / 120, offset: 4999, maximum: 6000, count: 120, dragging: false, decelerating: false))
        XCTAssertEqual(trace.samples.count, 64)
        XCTAssertEqual(trace.samples.first?.offset, 4937)
        XCTAssertEqual(trace.samples.last?.offset, 4999)
        XCTAssertEqual(trace.samples.last?.decelerating, false)
        XCTAssertEqual(trace.samples.last?.count, 120)
    }

    func testDelayedMetadataTraceSeparatesResponsePublicationPersistenceAndFinish() async {
        let source = client()
        let model = V3LibraryBrowserViewModel(library: item("lib"), client: source)
        let loading = Task { await model.load(tab: .items) }
        guard await waitForRequests(1, client: source) else { return }
        let marker = DiagnosticsLogger.shared.records().last { $0.contains("event=page-request") }!
        let identity = marker.split(separator: " ").first { $0.hasPrefix("model=") }!
        XCTAssertTrue(model.isLoading(tab: .items)); XCTAssertTrue(model.items(for: .items).isEmpty)
        XCTAssertFalse(DiagnosticsLogger.shared.records().contains { $0.contains(String(identity)) && $0.contains("event=page-response") })
        source.requests[0].continuation.resume(returning: page("first")); await loading.value
        let events = DiagnosticsLogger.shared.records().filter { $0.contains(String(identity)) }
        XCTAssertEqual(events.map { $0.split(separator: " ")[0] }, ["event=page-request", "event=page-response", "event=page-published", "event=page-persisted", "event=page-finish"])
        XCTAssertTrue(events[2].contains("count=1")); XCTAssertTrue(events[2].contains("loading=1"))
        XCTAssertTrue(events[3].contains("loading=1")); XCTAssertTrue(events[4].contains("loading=0"))
        XCTAssertEqual(model.items(for: .items).map(\.id), ["first"])
    }

    func testNativeMotionEndDiagnosticsNeverChangeOffsetOrRequestMetadata() {
        let source = client()
        let controller = EmbyPosterWallController()
        var requests = 0
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800)
        controller.update(EmbyPosterWall(items: (0..<120).map { item(String($0)) }, revision: 1, replacement: 1, client: source, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: { requests += 1 }, onRefresh: { requests += 1 }, onSelect: { _ in }))
        controller.viewDidLayoutSubviews(); controller.collection.layoutIfNeeded()
        controller.collection.setContentOffset(CGPoint(x: 0, y: 600), animated: false)
        let before = requests
        controller.scrollViewWillBeginDragging(controller.collection)
        controller.scrollViewDidEndDragging(controller.collection, willDecelerate: true)
        controller.scrollViewWillBeginDecelerating(controller.collection)
        controller.scrollViewDidEndDecelerating(controller.collection)
        controller.sampleFrame(at: 100)
        XCTAssertEqual(controller.collection.contentOffset.y, 600, accuracy: 0.5)
        XCTAssertEqual(requests, before)
        let messages = DiagnosticsLogger.shared.records()
        XCTAssertTrue(messages.contains { $0.contains("event=deceleration-end") && $0.contains("offset=600.00") && $0.contains("count=120") && $0.contains("remaining=") })
        controller.dispose()
    }

    func testOnlyRealRefreshCompletionEndsRefreshing() {
        let source = client()
        let controller = EmbyPosterWallController()
        let value = EmbyPosterWall(items: [], revision: 1, replacement: 1, client: source, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in })
        controller.loadViewIfNeeded()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 800))
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        let start = DiagnosticsLogger.shared.records().count
        controller.update(value)
        XCTAssertFalse(DiagnosticsLogger.shared.records().dropFirst(start).contains { $0.contains("event=end-refresh-before") })
        controller.collection.refreshControl?.beginRefreshing()
        XCTAssertEqual(controller.collection.refreshControl?.isRefreshing, true)
        controller.update(value)
        XCTAssertEqual(controller.collection.refreshControl?.isRefreshing, false)
        XCTAssertTrue(DiagnosticsLogger.shared.records().dropFirst(start).contains { $0.contains("event=end-refresh-before") && $0.contains("refreshing=1") })
        let finished = DiagnosticsLogger.shared.records().count
        controller.update(value)
        XCTAssertFalse(DiagnosticsLogger.shared.records().dropFirst(finished).contains { $0.contains("event=end-refresh-before") })
        controller.dispose(); window.isHidden = true
    }

    func testSortGenerationRejectsOlderQueryAfterNewSortCompletes() async {
        let source = client()
        let model = V3LibraryBrowserViewModel(library: item("lib"), client: source)
        let old = Task { await model.load(tab: .items) }
        guard await waitForRequests(1, client: source) else { return }
        let fresh = Task { await model.changeSort(to: "SortName", tab: .items) }
        guard await waitForRequests(2, client: source) else { return }
        XCTAssertEqual(source.requests[1].sort, "SortName")
        source.requests[1].continuation.resume(returning: page("fresh")); await fresh.value
        source.requests[0].continuation.resume(returning: page("stale")); await old.value
        XCTAssertEqual(model.items(for: .items).map(\.id), ["fresh"])
        XCTAssertFalse(model.isLoading(tab: .items))
    }

    func testVisibleAndPrefetchShareTaskWithIndependentCancellation() async {
        let gate = ImageGate()
        let preparation = EmbyImagePreparation(concurrencyLimit: 2, operation: gate.load)
        let url = client().imageURL(itemId: "a")!
        var received: UIImage?
        let a = preparation.subscribe(url, priority: .prefetch) { _ in XCTFail("cancelled callback") }
        let b = preparation.subscribe(url, priority: .visible) { received = $0 }
        preparation.cancel(a)
        await drain(); XCTAssertEqual(gate.calls[url], 1)
        let expected = image(.red); gate.finish(url, expected); await drain()
        XCTAssertTrue(received === expected)
        preparation.cancel(b); XCTAssertEqual(preparation.demandCount, 0)
    }

    func testReuseTagAndSourceRejectDelayedImages() async {
        let gate = ImageGate()
        let preparation = EmbyImagePreparation(concurrencyLimit: 3, operation: gate.load)
        let cell = EmbyPosterCell(preparation: preparation)
        let source = client()
        let a = EmbyPosterRecord(item: item("a"), client: source, pixelWidth: 300)
        let b = EmbyPosterRecord(item: item("b"), client: source, pixelWidth: 300)
        let holder = preparation.subscribe(a.url!, priority: .visible) { _ in }
        cell.configure(a); await drain()
        cell.prepareForReuse(); cell.configure(b); await drain()
        gate.finish(a.url!, image(.red)); await drain(); XCTAssertNil(cell.displayedImage)
        let blue = image(.blue); gate.finish(b.url!, blue); await drain(); XCTAssertTrue(cell.displayedImage === blue)
        let newTag = EmbyPosterRecord(item: item("b", tag: "v2"), client: source, pixelWidth: 300)
        cell.configure(newTag); XCTAssertNil(cell.displayedImage); await drain()
        let green = image(.green); gate.finish(newTag.url!, green); await drain(); XCTAssertTrue(cell.displayedImage === green)
        let other = EmbyPosterRecord(item: item("b", tag: "v2"), client: client(), pixelWidth: 300)
        XCTAssertNotEqual(other.id, newTag.id); XCTAssertNotEqual(other.url, newTag.url)
        cell.configure(other); XCTAssertNil(cell.displayedImage); await drain()
        gate.finish(other.url!, green); await drain()
        cell.deactivate(); preparation.cancel(holder)
    }

    func testCancelledWorkRemainsInsideConcurrencyBudgetUntilItFinishes() async {
        let gate = ImageGate()
        let preparation = EmbyImagePreparation(concurrencyLimit: 1, operation: gate.load)
        let source = client()
        let first = source.imageURL(itemId: "first")!
        let second = source.imageURL(itemId: "second")!
        let a = preparation.subscribe(first, priority: .visible) { _ in XCTFail("cancelled") }
        await drain(); preparation.cancel(a)
        let b = preparation.subscribe(second, priority: .visible) { _ in }
        await drain(); XCTAssertNil(gate.calls[second]); XCTAssertEqual(preparation.activeTaskCount, 1)
        gate.finish(first, nil); await drain(); XCTAssertEqual(gate.calls[second], 1)
        gate.finish(second, nil); await drain(); preparation.cancel(b)
    }

    func testFiveThousandVisitsAndFirstScreensAreBounded() async {
        let preparation = EmbyImagePreparation(concurrencyLimit: 4, operation: { _ in nil })
        let source = client()
        for index in 0..<5000 {
            let token = preparation.subscribe(source.imageURL(itemId: String(index))!, priority: .prefetch) { _ in }
            preparation.cancel(token)
            XCTAssertLessThanOrEqual(preparation.activeTaskCount, 4)
        }
        await drain(); XCTAssertEqual(preparation.demandCount, 0)
        let owners = [UUID(), UUID(), UUID()]
        for (index, owner) in owners.enumerated() {
            preparation.setFirstScreen(owner: owner, urls: (0..<18).map { source.imageURL(itemId: "\(index)-\($0)")! })
            XCTAssertLessThanOrEqual(preparation.firstScreenCount, 24)
            XCTAssertLessThanOrEqual(preparation.demandCount, 24)
        }
        owners.forEach { preparation.setFirstScreen(owner: $0, urls: []) }
        await drain(); XCTAssertEqual(preparation.demandCount, 0)
    }

    func testLibrarySnapshotRestoresMetadataAndPagingOffMainInOrder() async {
        let source = client()
        let cache = V3PagePersistentCache.shared
        let values = (0..<600).map { item(String($0)) }
        let snapshot = V3LibraryPersistentSnapshot(tabItems: ["items": values], suggestionResumeItems: [], suggestionLatestItems: [], genericSuggestionItems: [], recommendationSections: [], genres: [], folderItems: [], sortBy: "DateCreated", loadedTabs: ["items"], pageStates: ["items": V3PersistedPageState(nextStartIndex: 660, hasMore: true)])
        await cache.storeLibrarySnapshot(snapshot, client: source, libraryID: "lib")
        let restored = await cache.restoreLibrary(client: source, libraryID: "lib")
        XCTAssertEqual(restored?.0.tabItems["items"]?.map(\.id), values.map(\.id))
        XCTAssertEqual(restored?.0.pageStates["items"]?.nextStartIndex, 660)
        XCTAssertEqual(restored?.1["items"]?.count, 600)
        let messages = DiagnosticsLogger.shared.records().filter { $0.contains("event=library-snapshot") || $0.contains("event=library-restore") }
        XCTAssertFalse(messages.isEmpty); XCTAssertTrue(messages.allSatisfy { $0.contains("main_thread=0") })
    }

    func testNativeGeometryAppendAndReturnTopPreserveBusinessState() async {
        let source = client()
        let controller = EmbyPosterWallController()
        var loadRequests = 0
        var refreshRequests = 0
        let make: ([LibraryItem], Int) -> EmbyPosterWall = { values, revision in
            EmbyPosterWall(items: values, revision: revision, replacement: 1, client: source, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: { loadRequests += 1 }, onRefresh: { refreshRequests += 1 }, onSelect: { _ in })
        }
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800)
        controller.update(make((0..<60).map { self.item(String($0)) }, 1))
        controller.viewDidLayoutSubviews()
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        let flow = controller.collection.collectionViewLayout as! UICollectionViewFlowLayout
        XCTAssertEqual(flow.itemSize.width, 126)
        XCTAssertEqual(flow.itemSize.height, 231)
        XCTAssertEqual(controller.collection.numberOfItems(inSection: 0), 60)
        controller.collection.setContentOffset(CGPoint(x: 0, y: 600), animated: false)
        controller.update(make((0..<120).map { self.item(String($0)) }, 2))
        controller.collection.layoutIfNeeded()
        XCTAssertEqual(controller.collection.numberOfItems(inSection: 0), 120)
        XCTAssertEqual(controller.collection.contentOffset.y, 600, accuracy: 0.5)
        let before = loadRequests
        controller.collection.setContentOffset(.zero, animated: false)
        controller.collection.layoutIfNeeded()
        XCTAssertEqual(loadRequests, before); XCTAssertEqual(refreshRequests, 0)
        XCTAssertEqual(controller.collection.numberOfItems(inSection: 0), 120)
        controller.dispose()
    }
}
