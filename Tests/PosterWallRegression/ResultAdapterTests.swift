import XCTest
import SwiftUI
import UIKit

@MainActor final class ResultAdapterTests: XCTestCase {
    private func client() -> EmbyAPIClient { EmbyAPIClient(baseURL: URL(string: "https://\(UUID().uuidString).example.test")!) }
    private func page(_ ids: [String], total: Int? = nil) -> EmbyItemPage {
        var object: [String: Any] = ["Items": ids.map { ["Id": $0, "Name": $0, "Type": "Movie"] }]
        if let total { object["TotalRecordCount"] = total }
        return try! JSONDecoder().decode(EmbyItemPage.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func person(_ id: String?) -> EmbyPerson { EmbyPerson(itemId: id, name: "Actor", role: "Role", type: "Actor", primaryImageTag: nil) }
    private func wait(_ count: Int, _ source: EmbyAPIClient) async -> Bool {
        for _ in 0..<1000 { if source.resultRequests.count >= count { return true }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTFail("Controlled provider not reached"); return false
    }
    func testAllFavoriteTypesKeep60DedupRawFrontierAndNoPopReload() async {
        for type in ["Movie", "Series", "Episode", "Person"] {
            let source = client()
            let model = V3FavoriteCategoryGridViewModel(includeItemType: type, client: source)
            let first = Task { await model.reload() }; guard await wait(1, source) else { return }
            let q = source.resultRequests[0]; XCTAssertEqual(q.kind, "favorite"); XCTAssertEqual(q.types, [type]); XCTAssertEqual(q.limit, 60); XCTAssertEqual(q.start, 0)
            q.continuation.resume(returning: page(["a", "a"], total: 4)); await first.value
            let replacement = model.posterReplacement, revision = model.posterRevision
            let more = Task { await model.loadNextPage() }; guard await wait(2, source) else { return }
            XCTAssertEqual(source.resultRequests[1].start, 2)
            source.resultRequests[1].continuation.resume(returning: page(["a", "b"], total: 4)); await more.value
            XCTAssertEqual(model.items.map(\.id), ["a", "b"]); XCTAssertFalse(model.hasMore); XCTAssertTrue(model.hasLoaded)
            XCTAssertEqual(model.posterReplacement, replacement); XCTAssertGreaterThan(model.posterRevision, revision)
            if !model.hasLoaded { await model.reload() }; XCTAssertEqual(source.resultRequests.count, 2)
        }
    }
    func testPersonUsesActualIdNotNameOrRoleAndRetainsFailedAppend() async {
        let source = client()
        let owner = EmbyPersonMediaViewModel(person: person("person-id"), client: source)
        let first = Task { await owner.reload() }; guard await wait(1, source) else { return }
        XCTAssertEqual(source.resultRequests[0].value, "person-id"); XCTAssertEqual(source.resultRequests[0].limit, 60)
        source.resultRequests[0].continuation.resume(returning: page(["a", "a"], total: 4)); await first.value
        let revision = owner.posterRevision, replacement = owner.posterReplacement
        let more = Task { await owner.loadNextPage() }; guard await wait(2, source) else { return }
        XCTAssertEqual(source.resultRequests[1].start, 2)
        source.resultRequests[1].continuation.resume(throwing: URLError(.notConnectedToInternet)); await more.value
        XCTAssertEqual(owner.items.map(\.id), ["a"]); XCTAssertEqual(owner.posterRevision, revision); XCTAssertEqual(owner.posterReplacement, replacement)
        XCTAssertNotNil(owner.errorMessage); XCTAssertTrue(owner.hasMore)
    }
    func testMissingPersonIdDoesNotInventQuery() async {
        for id in [nil, ""] as [String?] {
            let source = client()
            let model = EmbyPersonMediaViewModel(person: person(id), client: source)
            await model.reload(); XCTAssertTrue(model.hasLoaded); XCTAssertFalse(model.hasMore); XCTAssertTrue(source.resultRequests.isEmpty)
        }
    }
    func testGenreAndTagKeepNameFlag60AndRawFrontier() async {
        for genre in [true, false] {
            let source = client(), filter = EmbyDetailFilter(name: "科幻 / 中文标签", isGenre: genre)
            let owner = EmbyDetailFilterResultsViewModel(filter: filter, client: source)
            let first = Task { await owner.reload() }; guard await wait(1, source) else { return }
            let q = source.resultRequests[0]; XCTAssertEqual(q.value, filter.name); XCTAssertEqual(q.isGenre, genre); XCTAssertEqual(q.limit, 60)
            q.continuation.resume(returning: page(["a", "a"], total: 3)); await first.value
            let replacement = owner.posterReplacement
            let more = Task { await owner.loadNextPage() }; guard await wait(2, source) else { return }
            XCTAssertEqual(source.resultRequests[1].start, 2)
            source.resultRequests[1].continuation.resume(returning: page(["b"], total: 3)); await more.value
            XCTAssertEqual(owner.items.map(\.id), ["a", "b"]); XCTAssertFalse(owner.hasMore); XCTAssertEqual(owner.posterReplacement, replacement)
        }
    }
    func testSearchUsesChosenServerTerm18TypesAndStopsAtOriginalFailurePolicy() async {
        let source = client()
        let model = V3GlobalSearchServerGridViewModel(term: "exact term", client: source)
        let first = Task { await model.loadNextPage() }; guard await wait(1, source) else { return }
        let q = source.resultRequests[0]; XCTAssertEqual(q.kind, "search"); XCTAssertEqual(q.value, "exact term"); XCTAssertEqual(q.limit, 18); XCTAssertEqual(q.types, ["Movie", "Series", "BoxSet"])
        q.continuation.resume(returning: page(["a", "a"], total: 30)); await first.value
        let revision = model.posterRevision
        let more = Task { await model.loadNextPage() }; guard await wait(2, source) else { return }
        XCTAssertEqual(source.resultRequests[1].start, 2)
        source.resultRequests[1].continuation.resume(throwing: URLError(.notConnectedToInternet)); await more.value
        XCTAssertEqual(model.items.map(\.id), ["a"]); XCTAssertEqual(model.posterRevision, revision); XCTAssertFalse(model.hasMore); XCTAssertNotNil(model.errorMessage)
    }
    func testFetchingGuardCancellationAndAbsentTotalKeepOriginalLeafPolicies() async {
        let source = client(), owner = V3FavoriteCategoryGridViewModel(includeItemType: "Movie", client: source)
        let first = Task { await owner.reload() }; guard await wait(1, source) else { return }
        await owner.reload(); await owner.loadNextPage(); XCTAssertEqual(source.resultRequests.count, 1)
        source.resultRequests[0].continuation.resume(throwing: URLError(.cancelled)); await first.value
        XCTAssertNil(owner.errorMessage); XCTAssertTrue(owner.hasLoaded)
        let retry = Task { await owner.reload() }; guard await wait(2, source) else { return }
        source.resultRequests[1].continuation.resume(returning: page((0..<60).map(String.init))); await retry.value; XCTAssertTrue(owner.hasMore)
        let more = Task { await owner.loadNextPage() }; guard await wait(3, source) else { return }
        XCTAssertEqual(source.resultRequests[2].start, 60)
        source.resultRequests[2].continuation.resume(returning: page(["60"])); await more.value; XCTAssertFalse(owner.hasMore)
    }
    func testPlainMediaAndPersonKeepActualFieldsGeometryAndReuse() {
        let source = client()
        let data = try! JSONSerialization.data(withJSONObject: ["Id": "same", "Name": "Title", "Type": "Episode", "ProductionYear": 2026, "PrimaryImageItemId": "series", "SeriesPrimaryImageTag": "series-tag", "UserData": ["Played": true, "UnplayedItemCount": 3]])
        let item = try! JSONDecoder().decode(LibraryItem.self, from: data)
        let plain = EmbyPosterRecord(item: item, client: source, pixelWidth: 400, kind: .plainMedia)
        XCTAssertEqual(plain.year, "2026"); XCTAssertEqual(plain.imageRequest.key.itemID, "series"); XCTAssertEqual(plain.progress, 0); XCTAssertEqual(plain.unplayed, 0); XCTAssertFalse(plain.played)
        let actor = EmbyPosterRecord(item: item, client: source, pixelWidth: 400, kind: .person)
        XCTAssertEqual(actor.imageRequest.key.itemID, "same"); XCTAssertNil(actor.year); XCTAssertEqual(actor.kind.textHeight, 24); XCTAssertEqual(plain.kind.textHeight, 40)
        let cell = EmbyPosterCell(); cell.configure(actor); XCTAssertEqual(cell.accessibilityLabel, "Title")
        cell.configure(plain); XCTAssertEqual(cell.accessibilityLabel, "Title, 2026"); cell.deactivate()
    }
    func testNativeResultQueryAndServerIdentityCannotReuseSameIdMetadata() {
        let controller = EmbyPosterWallController(); controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800); controller.viewDidLayoutSubviews()
        let item = page(["same"]).items[0], first = client(), second = client()
        func update(_ source: EmbyAPIClient, _ query: String) {
            controller.update(EmbyPosterWall(items: [item], revision: 1, replacement: 0, client: source, content: .plainMedia, queryIdentity: query, allowsRefresh: false, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 24, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in }))
        }
        update(first, "person|a"); let a = controller.records[0].id
        update(first, "person|b"); let b = controller.records[0].id; XCTAssertNotEqual(a, b)
        update(second, "person|b"); XCTAssertNotEqual(b, controller.records[0].id); XCTAssertNil(controller.collection.refreshControl)
        controller.dispose()
    }
    func testNativeLeafAppendKeepsOffsetGeometryAndDisablesOnlyItsRefresh() {
        let source = client(), controller = EmbyPosterWallController()
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800); controller.viewDidLayoutSubviews()
        func update(_ count: Int, _ revision: Int) {
            controller.update(EmbyPosterWall(items: page((0..<count).map(String.init)).items, revision: revision, replacement: 1, client: source, content: .plainMedia, queryIdentity: "filter|genre", allowsRefresh: false, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in }))
            controller.collection.layoutIfNeeded()
        }
        update(60, 1); controller.collection.contentOffset.y = 1600
        let first = controller.records[0], oldHeight = controller.collection.contentSize.height
        update(120, 2); XCTAssertEqual(controller.records[0], first); XCTAssertGreaterThan(controller.collection.contentSize.height, oldHeight); XCTAssertEqual(controller.collection.contentOffset.y, 1600, accuracy: 1)
        XCTAssertNil(controller.collection.refreshControl); controller.dispose()
        let library = EmbyPosterWallController(); library.loadViewIfNeeded(); XCTAssertNotNil(library.collection.refreshControl); library.dispose()
    }
}
