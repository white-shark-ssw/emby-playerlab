import XCTest
import UIKit

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
        for _ in 0..<200 {
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
