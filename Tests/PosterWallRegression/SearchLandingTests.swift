import XCTest
import SwiftUI
import UIKit

@MainActor final class SearchLandingTests: XCTestCase {
    private func client() -> EmbyAPIClient { EmbyAPIClient(baseURL: URL(string: "https://\(UUID().uuidString).example.test")!) }
    private func session(_ client: EmbyAPIClient) -> EmbySession { EmbySession(serverURL: client.baseURL, serverId: "server", serverName: "Server", serverVersion: "test", user: EmbyUser(id: "test", name: "Test"), tokenAccount: "session") }
    private func items(_ start: Int, _ count: Int) -> [LibraryItem] {
        try! JSONDecoder().decode([LibraryItem].self, from: JSONSerialization.data(withJSONObject: (start..<start + count).map { ["Id": String($0), "Name": "Recommendation \($0)", "Type": "Movie"] }))
    }
    private func owner() -> V3GlobalSearchViewModel {
        for key in ["oneplayer.search.recommendations-enabled.v1", "oneplayer.search.global-enabled.v1", "oneplayer.search.selected-server-ids.v1"] { UserDefaults.standard.removeObject(forKey: key) }
        return V3GlobalSearchViewModel()
    }
    private func wait(_ count: Int, _ source: EmbyAPIClient) async -> Bool {
        for _ in 0..<1000 { if source.recommendationRequests.count >= count { return true }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTFail("Controlled recommendation API not reached"); return false
    }
    func testOriginalNineThenSixExclusionsAndReturnDoesNotRefetch() async {
        let source = client(), model = owner()
        XCTAssertTrue(source.recommendationRequests.isEmpty, "Construction must not start recommendations")
        let initial = Task { await model.loadRecommendations(session: session(source), client: source) }
        guard await wait(1, source) else { return }
        XCTAssertEqual(source.recommendationRequests[0].limit, 9); XCTAssertEqual(source.recommendationRequests[0].types, ["Movie", "Series"])
        source.recommendationRequests[0].continuation.resume(returning: items(0, 9)); await initial.value
        let more = Task { await model.loadMoreRecommendations(client: source) }; guard await wait(2, source) else { return }
        XCTAssertEqual(source.recommendationRequests[1].limit, 6); XCTAssertEqual(source.recommendationRequests[1].excluded, (0..<9).map(String.init))
        source.recommendationRequests[1].continuation.resume(returning: items(9, 6)); await more.value
        XCTAssertEqual(model.recommendationItems.map(\.id), (0..<15).map(String.init)); XCTAssertTrue(model.hasMoreRecommendations)
        await model.loadRecommendations(session: session(source), client: source); XCTAssertEqual(source.recommendationRequests.count, 2)
    }
    func testToggleRejectsOldInitialResponseAndReentryOwnerIsFresh() async {
        let source = client(), model = owner()
        let initial = Task { await model.loadRecommendations(session: session(source), client: source) }; guard await wait(1, source) else { return }
        model.toggleRecommendations(); source.recommendationRequests[0].continuation.resume(returning: items(0, 9)); await initial.value
        XCTAssertTrue(model.recommendationItems.isEmpty); XCTAssertFalse(model.isLoadingRecommendations)
        model.toggleRecommendations()
        let retry = Task { await model.loadRecommendations(session: session(source), client: source) }; guard await wait(2, source) else { return }
        source.recommendationRequests[1].continuation.resume(returning: items(0, 9)); await retry.value
        let fresh = owner(); XCTAssertTrue(fresh.recommendationItems.isEmpty); XCTAssertEqual(fresh.recommendationRevision, 0)
        XCTAssertEqual(model.recommendationItems.count, 9)
    }
    func testDuplicateAndShortAppendKeepOriginalStopPolicy() async {
        for ids in [["8", "9", "10", "11", "12", "13"], ["9"]] {
            let source = client(), model = owner()
            let initial = Task { await model.loadRecommendations(session: session(source), client: source) }; guard await wait(1, source) else { return }
            source.recommendationRequests[0].continuation.resume(returning: items(0, 9)); await initial.value
            let more = Task { await model.loadMoreRecommendations(client: source) }; guard await wait(2, source) else { return }
            let values = try! JSONDecoder().decode([LibraryItem].self, from: JSONSerialization.data(withJSONObject: ids.map { ["Id": $0, "Name": $0, "Type": "Movie"] }))
            source.recommendationRequests[1].continuation.resume(returning: values); await more.value
            XCTAssertFalse(model.hasMoreRecommendations); XCTAssertEqual(Set(model.recommendationItems.map(\.id)).count, model.recommendationItems.count)
        }
    }
    func testAppendFailureRetainsContentAndFetchingGuard() async {
        let source = client(), model = owner()
        let initial = Task { await model.loadRecommendations(session: session(source), client: source) }; guard await wait(1, source) else { return }
        source.recommendationRequests[0].continuation.resume(returning: items(0, 9)); await initial.value
        let more = Task { await model.loadMoreRecommendations(client: source) }; guard await wait(2, source) else { return }
        await model.loadMoreRecommendations(client: source); XCTAssertEqual(source.recommendationRequests.count, 2)
        source.recommendationRequests[1].continuation.resume(throwing: URLError(.cancelled)); await more.value
        XCTAssertEqual(model.recommendationItems.count, 9); XCTAssertTrue(model.hasMoreRecommendations)
    }
    func testInitialFailureTerminatesAndConcurrentInitialLoadIsSuppressed() async {
        let source = client(), model = owner()
        let initial = Task { await model.loadRecommendations(session: session(source), client: source) }; guard await wait(1, source) else { return }
        await model.loadRecommendations(session: session(source), client: source); XCTAssertEqual(source.recommendationRequests.count, 1)
        source.recommendationRequests[0].continuation.resume(throwing: URLError(.badServerResponse)); await initial.value
        XCTAssertTrue(model.recommendationItems.isEmpty); XCTAssertFalse(model.hasMoreRecommendations); XCTAssertFalse(model.isLoadingRecommendations)
    }
    func testNativeHeaderSixPointInsetsAppendRetainsOffsetAndLegacyImageSpec() {
        let source = client(), controller = EmbyPosterWallController()
        var historyCalls: [String] = []; var clears = 0
        let header = EmbyPosterLandingHeaderInput(history: ["A", "B"], showsRecommendations: true, onHistory: { historyCalls.append($0) }, onClearHistory: { clears += 1 })
        func update(_ count: Int, _ revision: Int) {
            controller.update(EmbyPosterWall(items: items(0, count), revision: revision, replacement: 0, client: source, queryIdentity: "recommendations", allowsRefresh: false, horizontalPadding: 6, topPadding: 0, imagePixelWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, loadAheadItemCount: 1, landingHeader: header, emptyFooterHeight: 52, isLoading: false, hasLoaded: true, error: nil, emptyText: "", bottomPadding: 86, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in }))
        }
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800)
        update(60, 1); controller.viewDidLayoutSubviews(); controller.collection.layoutIfNeeded()
        XCTAssertEqual(controller.collection.numberOfItems(inSection: 0), 60); XCTAssertNil(controller.collection.refreshControl)
        let layout = controller.collection.collectionViewLayout as! UICollectionViewFlowLayout
        XCTAssertEqual(layout.sectionInset.left, 6); XCTAssertEqual(layout.sectionInset.top, 0)
        XCTAssertEqual(controller.records.first?.imageRequest.key.pixelWidth, V3SearchRecommendationPolicy.posterImageMaxWidth)
        controller.collection.setContentOffset(CGPoint(x: 0, y: 2200), animated: false)
        let before = controller.collection.contentOffset.y; update(66, 2); controller.collection.layoutIfNeeded()
        XCTAssertEqual(controller.collection.contentOffset.y, before, accuracy: 1)
        let view = EmbyPosterLandingHeader(frame: CGRect(x: 0, y: 0, width: 430, height: header.height)); view.configure(header); view.layoutIfNeeded()
        view.collectionView(UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout()), didSelectItemAt: IndexPath(item: 1, section: 0)); XCTAssertEqual(historyCalls, ["B"])
        let clear = view.subviews.compactMap { $0 as? UIButton }.first!; clear.sendActions(for: .touchUpInside); XCTAssertEqual(clears, 1)
        controller.dispose()
    }
    func testHistoryClearAndReorderDoNotResetRecommendationsOrImages() async {
        UserDefaults.standard.set(["Old"], forKey: "oneplayer.search.history.v1")
        let source = client(), model = owner(); source.automaticLibraryPages = true
        let stored = session(source), store = SessionStore([stored]); model.reconcileServers(store.sessions)
        await model.loadRecommendations(session: stored, client: source)
        let before = model.recommendationItems.map(\.id), revision = model.recommendationRevision
        let destination = await model.search(" New ", sessions: [stored], currentSession: stored, currentClient: source, sessionStore: store)
        XCTAssertNotNil(destination); XCTAssertEqual(model.history.first, "New")
        model.clearHistory(); XCTAssertTrue(model.history.isEmpty); XCTAssertEqual(model.recommendationItems.map(\.id), before); XCTAssertEqual(model.recommendationRevision, revision)
        XCTAssertEqual(source.recommendationRequests.count, 1)
    }
}
