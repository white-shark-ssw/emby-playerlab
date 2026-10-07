import XCTest
import SwiftUI

@MainActor
final class DetailLoadingTests: XCTestCase {
    private func data(_ value: Any) -> Data { try! JSONSerialization.data(withJSONObject: value) }
    private func item(_ id: String = "movie", type: String = "Movie", name: String = "Seed") -> LibraryItem { try! JSONDecoder().decode(LibraryItem.self, from: data(["Id": id, "Name": name, "Type": type])) }
    private func images(_ index: Int = 0) -> [EmbyImageInfo] { try! JSONDecoder().decode([EmbyImageInfo].self, from: data([["ImageType": "Screenshot", "ImageIndex": index]])) }
    private func snapshot(_ label: String) -> EmbyMediaDetailWarmSnapshot { EmbyMediaDetailWarmSnapshot(episodes: [], seasons: [], imageInfos: images(), similarItems: [item(label)]) }
    private func client(type: String = "Movie") -> EmbyAPIClient {
        let source = EmbyAPIClient(baseURL: URL(string: "http://detail-\(UUID().uuidString).invalid")!)
        source.responses = [
            "item": data(["Id": "movie", "Name": "Fresh", "Type": type]),
            "images": data([["ImageType": "Screenshot", "ImageIndex": 0]]),
            "similar": data([["Id": "similar", "Name": "Similar", "Type": type]]),
            "episodes": data([["Id": "first", "Name": "Episode 1", "Type": "Episode", "IndexNumber": 1, "ParentIndexNumber": 1], ["Id": "requested", "Name": "Episode 2", "Type": "Episode", "IndexNumber": 2, "ParentIndexNumber": 1]]),
            "seasons": data([["Id": "season", "Name": "Season 1", "Type": "Season", "IndexNumber": 1]]),
            "media": data(["MediaSources": [["Id": "source", "SupportsDirectPlay": true]], "PlaySessionId": "session"]),
        ]
        return source
    }
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        // Boundary readiness, not a product-latency assertion; cold simulator scheduling is allowed.
        for _ in 0..<1000 {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Production load did not reach controlled boundary")
        return false
    }

    func testDelayedPlaybackInfoDoesNotBlockStillsOrSimilarPublication() async {
        let source = client(); source.paused = ["media"]
        let model = EmbyMediaDetailViewModel(item: item(), client: source)
        let loading = Task { await model.load() }
        guard await waitUntil({ !source.pending.isEmpty && model.stillImages.count == 1 && model.similarItems.count == 1 }) else { source.finishAll(); await loading.value; return }
        XCTAssertTrue(model.mediaSources.isEmpty); XCTAssertFalse(model.hasLoaded)
        XCTAssertEqual(Set(source.requests.map { $0.0 }), ["item", "images", "similar", "media"])
        source.finish("media"); await loading.value
        XCTAssertTrue(model.hasLoaded); XCTAssertEqual(model.mediaSources.first?.id, "source")
        XCTAssertEqual(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie")?.similarItems.first?.id, "similar")
    }

    func testDelayedImagesDoNotBlockSimilarOrMediaPublication() async {
        let source = client(); source.paused = ["images"]
        let model = EmbyMediaDetailViewModel(item: item(), client: source)
        let loading = Task { await model.load() }
        guard await waitUntil({ !source.pending.isEmpty && !model.mediaSources.isEmpty && !model.similarItems.isEmpty }) else { source.finishAll(); await loading.value; return }
        XCTAssertTrue(model.imageInfos.isEmpty); XCTAssertFalse(model.hasLoaded)
        source.finish("images"); await loading.value
        XCTAssertEqual(model.stillImages.count, 1)
    }

    func testSeriesPresentationIsIndependentButPlaybackRetainsEpisodeSelectionDependencies() async {
        let source = client(type: "Series"); source.paused = ["episodes", "seasons"]
        let model = EmbyMediaDetailViewModel(item: item(type: "Series"), client: source, initialEpisodeID: "requested")
        let loading = Task { await model.load() }
        guard await waitUntil({ source.pending.contains { $0.kind == "episodes" } && !model.stillImages.isEmpty && !model.similarItems.isEmpty }) else { source.finishAll(); await loading.value; return }
        XCTAssertFalse(source.requests.contains { $0.0 == "media" }); XCTAssertTrue(model.isLoadingEpisodes)
        XCTAssertEqual(source.similarTypes, ["Series"])
        source.finish("episodes")
        guard await waitUntil({ source.pending.contains { $0.kind == "seasons" } }) else { source.finishAll(); await loading.value; return }
        XCTAssertFalse(source.requests.contains { $0.0 == "media" })
        source.finish("seasons"); await loading.value
        XCTAssertEqual(model.selectedEpisodeID, "requested"); XCTAssertEqual(model.selectedSeason, 1)
        XCTAssertEqual(source.requests.first { $0.0 == "media" }?.1, "requested")
        XCTAssertFalse(model.isLoadingEpisodes); XCTAssertTrue(model.hasLoaded)
    }

    func testCancellationRejectsLateResultsAndDoesNotStoreOrMarkLoadedThenSameModelRetries() async {
        let source = client(); source.paused = ["images", "similar", "media"]
        let model = EmbyMediaDetailViewModel(item: item(), client: source)
        let loading = Task { await model.load() }
        guard await waitUntil({ source.pending.count == 3 }) else { source.finishAll(); await loading.value; return }
        loading.cancel()
        // Deliberately non-cooperative boundary: production checks must reject successful late responses.
        source.finishAll(); await loading.value
        XCTAssertFalse(model.hasLoaded); XCTAssertTrue(model.imageInfos.isEmpty); XCTAssertTrue(model.similarItems.isEmpty); XCTAssertTrue(model.mediaSources.isEmpty)
        XCTAssertNil(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie"))
        source.paused = []; await model.load()
        XCTAssertTrue(model.hasLoaded); XCTAssertEqual(model.stillImages.count, 1)
        XCTAssertEqual(source.requests.filter { $0.0 == "item" }.count, 2)
    }

    func testCancellationAfterPresentationPublishedDoesNotCreateAnIncompleteWarmHit() async {
        let source = client(); source.paused = ["media"]
        let model = EmbyMediaDetailViewModel(item: item(), client: source)
        let loading = Task { await model.load() }
        guard await waitUntil({ !source.pending.isEmpty && model.stillImages.count == 1 && model.similarItems.count == 1 }) else { source.finishAll(); await loading.value; return }
        loading.cancel(); source.finish("media", error: URLError(.cancelled)); await loading.value
        XCTAssertFalse(model.hasLoaded)
        XCTAssertNil(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie"))
        let reentry = EmbyMediaDetailViewModel(item: item(), client: source)
        XCTAssertTrue(reentry.imageInfos.isEmpty); XCTAssertTrue(reentry.similarItems.isEmpty)
    }

    func testPartialFailureAndUserDataRefreshPreservePreviousCompleteSnapshot() async {
        let source = client(); source.paused = ["images"]
        await EmbyMediaDetailWarmCache.shared.store(snapshot("old"), client: source, itemID: "movie")
        let model = EmbyMediaDetailViewModel(item: item(), client: source)
        XCTAssertEqual(model.similarItems.first?.id, "old")
        let loading = Task { await model.load() }
        guard await waitUntil({ source.pending.count == 1 && model.similarItems.first?.id == "similar" }) else { source.finishAll(); await loading.value; return }
        source.finish("images", error: URLError(.notConnectedToInternet)); await loading.value
        XCTAssertTrue(model.hasLoaded); XCTAssertEqual(model.stillImages.count, 1)
        XCTAssertEqual(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie")?.similarItems.first?.id, "old")
        await model.refreshPlaybackUserData(itemID: "movie")
        XCTAssertEqual(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie")?.similarItems.first?.id, "old")
    }

    func testMediaFailureStillAllowsCompletePresentationSnapshot() async {
        let source = client(); source.paused = ["media"]
        let model = EmbyMediaDetailViewModel(item: item(), client: source)
        let loading = Task { await model.load() }
        guard await waitUntil({ !source.pending.isEmpty && !model.stillImages.isEmpty }) else { source.finishAll(); await loading.value; return }
        source.finish("media", error: URLError(.notConnectedToInternet)); await loading.value
        XCTAssertTrue(model.hasLoaded); XCTAssertTrue(model.mediaSources.isEmpty)
        XCTAssertEqual(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie")?.similarItems.first?.id, "similar")
    }

    func testCancelledItemCannotPublishLateBasicDataOrStartDependentRequests() async {
        let source = client(); source.paused = ["item"]
        let model = EmbyMediaDetailViewModel(item: item(), client: source)
        let loading = Task { await model.load() }
        guard await waitUntil({ !source.pending.isEmpty }) else { source.finishAll(); await loading.value; return }
        loading.cancel(); source.finish("item"); await loading.value
        XCTAssertEqual(model.item.name, "Seed"); XCTAssertFalse(model.hasLoaded)
        XCTAssertEqual(source.requests.count, 1); XCTAssertNil(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie"))
    }

    func testCacheKeepsImmediateMemoryOrderedOffMainDiskAndRouteIsolation() async {
        let source = client(), cache = EmbyMediaDetailWarmCache()
        let gate = DispatchSemaphore(value: 0)
        cache.writeQueue.async { gate.wait() }
        let first = Task { await cache.store(snapshot("first"), client: source, itemID: "movie") }
        guard await waitUntil({ cache.snapshot(client: source, itemID: "movie")?.similarItems.first?.id == "first" }) else { gate.signal(); await first.value; return }
        let second = Task { await cache.store(snapshot("second"), client: source, itemID: "movie") }
        guard await waitUntil({ cache.snapshot(client: source, itemID: "movie")?.similarItems.first?.id == "second" }) else { gate.signal(); await first.value; await second.value; return }
        let recordsStart = DiagnosticsLogger.shared.records().count
        gate.signal(); await first.value; await second.value
        let writes = Array(DiagnosticsLogger.shared.records().dropFirst(recordsStart)).filter { $0.contains("event=disk-store") }
        XCTAssertEqual(writes.count, 2); XCTAssertTrue(writes.allSatisfy { $0.contains("main_thread=0") })
        cache.cache.removeAllObjects()
        XCTAssertEqual(cache.snapshot(client: source, itemID: "movie")?.similarItems.first?.id, "second")
        XCTAssertEqual(cache.snapshot(client: source, itemID: "movie")?.imageInfos.first?.imageType, "Screenshot")
        let otherUser = EmbyAPIClient(baseURL: source.baseURL, userId: "other")
        XCTAssertNil(cache.snapshot(client: otherUser, itemID: "movie")); XCTAssertNil(cache.snapshot(client: client(), itemID: "movie"))
    }

    func testCachedPlaybackSessionReuseAndCompleteUserDataRefreshRemain() async {
        let source = client()
        let bound = EmbyMediaDetailViewModel(item: item(), client: source)
        await bound.load(); await bound.play(bound.item)
        XCTAssertEqual(source.requests.filter { $0.0 == "media" }.count, 1)
        XCTAssertEqual(source.resolvedSessions.count, 1); XCTAssertEqual(source.resolvedSessions.first!, "session")
        XCTAssertNotNil(bound.selectedSource)
        await bound.refreshPlaybackUserData(itemID: "movie")
        XCTAssertEqual(EmbyMediaDetailWarmCache.shared.snapshot(client: source, itemID: "movie")?.similarItems.first?.id, "similar")
        source.paused = ["item"]
        source.responses["item"] = data(["Id": "movie", "Name": "Late cancelled refresh", "Type": "Movie"])
        let refresh = Task { await bound.refreshPlaybackUserData(itemID: "movie") }
        guard await waitUntil({ !source.pending.isEmpty }) else { source.finishAll(); await refresh.value; return }
        refresh.cancel(); source.finish("item"); await refresh.value
        XCTAssertEqual(bound.item.name, "Fresh")
    }
}
