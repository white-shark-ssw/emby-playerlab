import XCTest
import SwiftUI
import UIKit

@MainActor
final class LibraryAdapterTests: XCTestCase {
    private func client() -> EmbyAPIClient { EmbyAPIClient(baseURL: URL(string: "https://\(UUID().uuidString).example.test")!) }
    private func item(_ id: String, type: String = "Movie") -> LibraryItem {
        let data = try! JSONSerialization.data(withJSONObject: ["Id": id, "Name": id, "Type": type, "CollectionType": "movies", "ProductionYear": 2026, "RunTimeTicks": 1000, "PrimaryImageItemId": "parent", "SeriesPrimaryImageTag": "parent-tag", "ImageTags": ["Primary": "own-tag"], "UserData": ["Played": true, "UnplayedItemCount": 3, "PlaybackPositionTicks": 500]])
        return try! JSONDecoder().decode(LibraryItem.self, from: data)
    }
    private func page(_ values: [LibraryItem], total: Int) -> EmbyItemPage {
        let object: [String: Any] = ["Items": values.map { ["Id": $0.id, "Name": $0.name, "Type": $0.type ?? "Movie"] }, "TotalRecordCount": total]
        return try! JSONDecoder().decode(EmbyItemPage.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func wait(_ count: Int, _ source: EmbyAPIClient) async -> Bool {
        for _ in 0..<1000 { if source.requests.count >= count { return true }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTFail("Network boundary not reached"); return false
    }

    func testPagedLibraryAdaptersKeepTypesScopeRawFrontierAndSuccessfulPopQuery() async {
        for (tab, type, filters) in [(V3LibraryTab.trailers, "Trailer", [String]()), (.collections, "BoxSet", []), (.favorites, "Movie", ["IsFavorite"])] {
            let source = client()
            // Use a unique cache/network identity for each original owner.
            let owner = V3LibraryBrowserViewModel(library: item("lib"), client: source)
            let initial = Task { await owner.load(tab: tab) }
            guard await wait(1, source) else { return }
            let first = source.requests[0]
            XCTAssertEqual(first.parent, "lib"); XCTAssertEqual(first.limit, 60); XCTAssertTrue(first.recursive)
            XCTAssertEqual(first.types, [type]); XCTAssertEqual(first.filters, filters); XCTAssertEqual(first.sort, "DateCreated")
            source.requests[0].continuation.resume(returning: page([item("a", type: type), item("a", type: type), item("wrong", type: "Person")], total: 100))
            await initial.value
            let replacement = owner.replacement(for: tab), revision = owner.revision(for: tab)
            let more = Task { await owner.loadNextPage(tab: tab) }
            guard await wait(2, source) else { return }
            XCTAssertEqual(source.requests[1].start, 3, "Frontier counts raw server records, not filtered/deduplicated cards")
            source.requests[1].continuation.resume(returning: page([item("a", type: type), item("b", type: type)], total: 5))
            await more.value
            XCTAssertEqual(owner.items(for: tab).map(\.id), ["a", "b"]); XCTAssertFalse(owner.hasMore(tab: tab))
            XCTAssertEqual(owner.replacement(for: tab), replacement); XCTAssertGreaterThan(owner.revision(for: tab), revision)
            await owner.load(tab: tab); XCTAssertEqual(source.requests.count, 2)
            // Explicit tab switch still refreshes the returning tab, as before native presentation.
            await owner.load(tab: .genres)
            let switched = Task { await owner.load(tab: tab) }
            guard await wait(3, source) else { return }
            XCTAssertEqual(source.requests[2].start, 0)
            source.requests[2].continuation.resume(throwing: URLError(.notConnectedToInternet)); await switched.value
            XCTAssertEqual(owner.items(for: tab).map(\.id), ["a", "b"])
        }
    }

    func testNewTabSortRejectsSupersededResponseAndRefreshChangesReplacement() async {
        let source = client()
        let model = V3LibraryBrowserViewModel(library: item("lib"), client: source)
        let old = Task { await model.load(tab: .collections) }
        guard await wait(1, source) else { return }
        let sorted = Task { await model.changeSort(to: "SortName", tab: .collections) }
        guard await wait(2, source) else { return }
        source.requests[1].continuation.resume(returning: page([item("new", type: "BoxSet")], total: 1)); await sorted.value
        let revision = model.revision(for: .collections), replacement = model.replacement(for: .collections)
        source.requests[0].continuation.resume(returning: page([item("old", type: "BoxSet")], total: 1)); await old.value
        XCTAssertEqual(model.items(for: .collections).map(\.id), ["new"]); XCTAssertEqual(model.revision(for: .collections), revision)
        await model.load(tab: .collections); XCTAssertEqual(source.requests.count, 2)
        let refresh = Task { await model.refresh(tab: .collections) }
        guard await wait(3, source) else { return }
        source.requests[2].continuation.resume(returning: page([item("refreshed", type: "BoxSet")], total: 1)); await refresh.value
        XCTAssertGreaterThan(model.replacement(for: .collections), replacement)
    }

    func testGenreResultKeepsNamedFilterAscendingSortDedupAndFailedAppend() async {
        let source = client()
        let owner = V3LibraryGenreGridViewModel(library: item("lib"), genre: item("Drama", type: "Genre"), client: source)
        let first = Task { await owner.refresh() }
        guard await wait(1, source) else { return }
        let query = source.requests[0]
        XCTAssertEqual(query.parent, "lib"); XCTAssertEqual(query.genres, ["Drama"]); XCTAssertEqual(query.types, ["Movie"])
        XCTAssertEqual(query.sort, "SortName"); XCTAssertEqual(query.order, "Ascending"); XCTAssertEqual(query.limit, 60)
        query.continuation.resume(returning: page([item("a"), item("a")], total: 5)); await first.value
        let replacement = owner.posterReplacement
        let failed = Task { await owner.loadNextPage() }
        guard await wait(2, source) else { return }; XCTAssertEqual(source.requests[1].start, 2)
        source.requests[1].continuation.resume(throwing: URLError(.notConnectedToInternet)); await failed.value
        XCTAssertEqual(owner.items.map(\.id), ["a"]); XCTAssertEqual(owner.posterReplacement, replacement)
        let retry = Task { await owner.loadNextPage() }
        guard await wait(3, source) else { return }; XCTAssertEqual(source.requests[2].start, 2)
        source.requests[2].continuation.resume(returning: page([item("a"), item("b"), item("c")], total: 5)); await retry.value
        XCTAssertEqual(owner.items.map(\.id), ["a", "b", "c"]); XCTAssertFalse(owner.hasMore)
        XCTAssertEqual(owner.posterReplacement, replacement)
    }

    func testFolderOwnerUsesExactParentUnpagedAndRetainsMixedRowsOnReturnAndFailure() async {
        let source = client()
        source.folderResponses["child"] = .success([item("sub", type: "CollectionFolder"), item("movie"), item("episode", type: "Episode")])
        let model = V3LibraryFolderBrowserViewModel(folder: item("child", type: "Folder"), client: source)
        await model.load(); let revision = model.posterRevision
        await model.load(); XCTAssertEqual(source.folderRequests, ["child"]); XCTAssertEqual(model.posterRevision, revision)
        XCTAssertEqual(model.items.map(\.id), ["sub", "movie", "episode"])
        XCTAssertTrue(v3LibraryIsBrowsableFolder(model.items[0])); XCTAssertFalse(v3LibraryIsBrowsableFolder(model.items[1])); XCTAssertFalse(v3LibraryIsBrowsableFolder(model.items[2]))
        XCTAssertTrue(v3LibraryIsBrowsableFolder(item("f", type: "fOlDeR")))
        source.folderResponses["child"] = .failure(URLError(.notConnectedToInternet)); await model.load(force: true)
        XCTAssertEqual(source.folderRequests, ["child", "child"]); XCTAssertEqual(model.posterRevision, revision); XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(source.requests.isEmpty, "No paging API is introduced for folder children")
    }

    func testCoverQueriesHaveSuccessfulReturnValidityAndFailedFirstLoadRetries() async {
        let source = client()
        let owner = V3LibraryBrowserViewModel(library: item("lib"), client: source)
        source.genreResponse = .failure(URLError(.notConnectedToInternet)); await owner.load(tab: .genres)
        source.genreResponse = .success([item("Drama", type: "Genre")]); await owner.load(tab: .genres)
        let revision = owner.genreRevision; await owner.load(tab: .genres)
        XCTAssertEqual(source.genreRequests.count, 2); XCTAssertEqual(owner.genreRevision, revision)
        XCTAssertEqual(source.genreRequests[1].0, "lib"); XCTAssertEqual(source.genreRequests[1].1, ["Movie"])
        source.folderResponses["lib"] = .success([item("folder", type: "Folder"), item("movie")]); await owner.load(tab: .folders)
        await owner.load(tab: .folders); XCTAssertEqual(source.folderRequests, ["lib"])
        await owner.load(tab: .genres); XCTAssertEqual(source.genreRequests.count, 3, "Explicit tab change reloads the original cover query")
    }

    func testGenreAndFolderCardsUseOwnImageNoMediaBadgesAndReuseRestoresMedia() {
        let source = client(), value = item("genre", type: "Genre")
        let media = EmbyPosterRecord(item: value, client: source, pixelWidth: 400)
        let genre = EmbyPosterRecord(item: value, client: source, pixelWidth: 400, kind: .genre)
        XCTAssertEqual(genre.imageRequest.key.itemID, "genre"); XCTAssertEqual(genre.imageRequest.key.tag, value.primaryImageTag)
        XCTAssertNil(genre.year); XCTAssertEqual(genre.progress, 0); XCTAssertEqual(genre.unplayed, 0); XCTAssertFalse(genre.played)
        XCTAssertEqual(media.year, "2026"); XCTAssertEqual(media.unplayed, 3)
        XCTAssertEqual(media.progress, 0.5)
        let inherited = try! JSONDecoder().decode(LibraryItem.self, from: JSONSerialization.data(withJSONObject: ["Id": "inherited", "Name": "Inherited", "PrimaryImageItemId": "parent", "SeriesPrimaryImageTag": "parent-tag"]))
        XCTAssertEqual(EmbyPosterRecord(item: inherited, client: source, pixelWidth: 400).imageRequest.key.itemID, "parent")
        XCTAssertEqual(EmbyPosterRecord(item: inherited, client: source, pixelWidth: 400, kind: .genre).imageRequest.key.itemID, "inherited")
        XCTAssertNil(EmbyPosterRecord(item: inherited, client: source, pixelWidth: 400, kind: .folder).imageRequest.key.tag)
        let cell = EmbyPosterCell(); cell.configure(genre); XCTAssertEqual(cell.accessibilityLabel, "genre")
        cell.configure(media); XCTAssertEqual(cell.record?.kind, .media); XCTAssertEqual(cell.accessibilityLabel, "genre, 2026")
        cell.configure(EmbyPosterRecord(item: value, client: source, pixelWidth: 400, kind: .folder)); XCTAssertEqual(cell.record?.kind, .folder)
        XCTAssertEqual(EmbyPosterWallContent.folders.kind(for: item("f", type: "Folder")), .folder)
        XCTAssertEqual(EmbyPosterWallContent.folders.kind(for: item("e", type: "Episode")), .media)
        cell.deactivate()
    }

    func testMixedRowsKeepTallestGeometryAndSameCountQueryCannotKeepOldCards() {
        let source = client(), controller = EmbyPosterWallController()
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 800); controller.viewDidLayoutSubviews()
        func update(_ values: [LibraryItem], content: EmbyPosterWallContent, query: String) {
            controller.update(EmbyPosterWall(items: values, revision: 1, replacement: 1, client: source, content: content, queryIdentity: query, isLoading: false, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in }))
            controller.collection.layoutIfNeeded()
        }
        update([item("a", type: "Folder"), item("b"), item("c", type: "Folder"), item("d", type: "Folder")], content: .folders, query: "root")
        let first = controller.collectionView(controller.collection, layout: controller.collection.collectionViewLayout, sizeForItemAt: IndexPath(item: 0, section: 0))
        let last = controller.collectionView(controller.collection, layout: controller.collection.collectionViewLayout, sizeForItemAt: IndexPath(item: 3, section: 0))
        XCTAssertEqual(first.height - last.height, 18)
        update([item("different", type: "Genre")], content: .genres, query: "genres")
        XCTAssertEqual(controller.records[0].kind, .genre)
        update([item("new", type: "Genre")], content: .genres, query: "other-library")
        XCTAssertTrue(controller.records[0].id.hasSuffix("|new")); XCTAssertEqual(controller.records[0].name, "new")
        controller.dispose()
    }
}
