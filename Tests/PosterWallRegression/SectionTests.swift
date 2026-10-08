import XCTest
import UIKit
import SwiftUI

@MainActor final class PosterSectionTests: XCTestCase {
    private func item(_ id: String, type: String = "Movie", tag: String = "v1") -> LibraryItem {
        let data = try! JSONSerialization.data(withJSONObject: ["Id": id, "Name": "Card \(id)", "Type": type, "ProductionYear": 2026, "ImageTags": ["Primary": tag], "BackdropImageTags": ["backdrop"], "UserData": ["PlayedPercentage": 40]])
        return try! JSONDecoder().decode(LibraryItem.self, from: data)
    }
    private func client(_ name: String = UUID().uuidString) -> EmbyAPIClient { EmbyAPIClient(baseURL: URL(string: "https://\(name).example.test")!) }
    private func section(_ id: String, source: EmbyAPIClient, style: EmbyPosterRowStyle = .poster, count: Int = 20, select: @escaping (LibraryItem) -> Void = { _ in }) -> EmbyPosterSection {
        EmbyPosterSection(id: id, title: id, items: (0..<count).map { item(String($0)) }, client: source, style: style, onSelect: select)
    }
    private func update(_ controller: EmbyPosterSectionsController, sections: [EmbyPosterSection], query: String = "query", active: Bool = true, loading: Bool = false, topToken: Int = 0, onOffset: ((CGFloat) -> Void)? = nil, homeRefresh: ((@escaping () -> Void) -> Void)? = nil) {
        controller.update(sections: sections, query: query, topHeight: 300, topPadding: 2, gap: 24, bottom: 86, loading: loading, empty: "Empty", error: nil, active: active, topToken: topToken, refresh: nil, homeOffset: onOffset, homeRefresh: homeRefresh)
        controller.view.layoutIfNeeded(); controller.collection.layoutIfNeeded()
    }
    private func mounted() -> (UIWindow, EmbyPosterSectionsController) {
        let controller = EmbyPosterSectionsController(), window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 800))
        window.rootViewController = controller; window.makeKeyAndVisible(); controller.view.frame = window.bounds
        controller.viewDidLayoutSubviews(); controller.viewDidAppear(false)
        return (window, controller)
    }

    func testOriginalVariantsKeepImageSpecsFieldsAndSourceIdentity() {
        let a = client("first"), b = client("second"), value = item("shared")
        for style in [EmbyPosterRowStyle.poster, .person, .landscape, .library] {
            let first = section("same", source: a, style: style), second = section("same", source: b, style: style)
            let x = EmbyPosterSectionCard(item: value, section: first, retained: [:]), y = EmbyPosterSectionCard(item: value, section: second, retained: [:])
            XCTAssertNotEqual(x.poster.id, y.poster.id); XCTAssertNotEqual(x.url, y.url)
            let expected = style == .library ? a.imageURL(itemId: value.id, maxWidth: 480, tag: "v1") : (style == .landscape ? a.imageURL(itemId: value.id, imageType: "Backdrop", maxWidth: 650, tag: "backdrop") : a.imageURL(itemId: value.id, maxWidth: style == .person ? Int(ceil(118 * UIScreen.main.scale)) : 440, tag: "v1"))
            XCTAssertEqual(x.url, expected)
            XCTAssertEqual(x.poster.year, style == .person ? nil : "2026")
            XCTAssertEqual(x.subtitle, style == .landscape ? "2026" : "")
        }
        XCTAssertEqual(EmbyPosterRowStyle.library.height(width: 164), 118)
        XCTAssertEqual(EmbyPosterRowStyle.landscape.height(width: 212), 164)
        XCTAssertEqual(EmbyPosterRowStyle.poster.height(width: 118), 219)
        XCTAssertEqual(EmbyPosterRowStyle.person.height(width: 118), 201)
    }

    func testSameMetadataPublicationPreservesVerticalHorizontalGeometryAndRequests() {
        let (window, controller) = mounted(); defer { controller.dispose(); window.isHidden = true }
        let source = client(), values = (0..<12).map { section(String($0), source: source) }
        update(controller, sections: values)
        controller.collection.setContentOffset(CGPoint(x: 0, y: 450), animated: false); controller.collection.layoutIfNeeded()
        let row = controller.rows.first!; row.collection.setContentOffset(CGPoint(x: 450, y: 0), animated: false)
        let requests = row.cards.map { $0.poster.imageRequest }
        let height = controller.collection.contentSize.height
        update(controller, sections: values, loading: true)
        XCTAssertEqual(controller.collection.contentOffset.y, 450, accuracy: 0.1)
        XCTAssertEqual(row.collection.contentOffset.x, 450, accuracy: 0.1)
        XCTAssertTrue(zip(requests, row.cards).allSatisfy { $0 === $1.poster.imageRequest })
        XCTAssertGreaterThanOrEqual(controller.collection.contentSize.height, height)
        controller.viewWillDisappear(false); controller.viewDidAppear(false)
        XCTAssertEqual(controller.collection.contentOffset.y, 450, accuracy: 0.1)
        XCTAssertEqual(row.collection.contentOffset.x, 450, accuracy: 0.1)
        XCTAssertEqual(source.requests.count, 0)
    }

    func testRowReuseReturnsStoredOffsetAndLatestSelectionCallback() {
        let row = EmbyPosterHorizontalRow(frame: CGRect(x: 0, y: 0, width: 430, height: 219)), source = client()
        var selected = "", stored: [String: CGFloat] = [:]
        row.onOffset = { stored[$0] = $1 }; row.layoutIfNeeded(); row.activate()
        let a = section("a", source: source, select: { selected = "old|\($0.id)" })
        row.configure(a, offset: 0); row.collection.layoutIfNeeded(); row.collection.setContentOffset(CGPoint(x: 500, y: 0), animated: false)
        row.deactivate(); row.prepareForReuse()
        let b = section("b", source: source); row.configure(b, offset: 0); row.activate(); row.collection.layoutIfNeeded()
        XCTAssertEqual(row.collection.contentOffset.x, 0, accuracy: 0.1)
        let latest = section("a", source: source, select: { selected = "new|\($0.id)" })
        row.configure(latest, offset: stored[a.source] ?? -1); row.collection.layoutIfNeeded()
        XCTAssertEqual(row.collection.contentOffset.x, 500, accuracy: 0.1)
        row.collectionView(row.collection, didSelectItemAt: IndexPath(item: 4, section: 0))
        XCTAssertEqual(selected, "new|4"); row.deactivate()
    }

    func testQueryReplacementClearsOldSectionPositionAndSelectionSource() {
        let (window, controller) = mounted(); defer { controller.dispose(); window.isHidden = true }
        let a = client(), b = client()
        update(controller, sections: (0..<10).map { section(String($0), source: a) })
        controller.collection.setContentOffset(CGPoint(x: 0, y: 600), animated: false)
        update(controller, sections: [section("same", source: b)], query: "new query")
        XCTAssertEqual(controller.collection.contentOffset.y, 0, accuracy: 0.1)
        XCTAssertEqual(controller.sections.first?.client.baseURL, b.baseURL)
        XCTAssertEqual(controller.collection.numberOfSections, 3)
    }

    func testOnePagePrefetchBudgetCapsAllRowsAndCancelsIndependently() {
        let budget = EmbyPosterSectionPrefetchBudget(), a = UUID(), b = UUID()
        for index in 0..<8 { budget.subscribe(owner: a, url: URL(string: "https://prefetch.example.test/a\(index)")!) }
        for index in 0..<20 { budget.subscribe(owner: b, url: URL(string: "https://prefetch.example.test/b\(index)")!) }
        XCTAssertEqual(budget.count, 12)
        budget.cancel(owner: a); XCTAssertEqual(budget.count, 4)
        budget.cancel(owner: b); XCTAssertEqual(budget.count, 0)
    }

    func testTopGeometryAndResourceActivityKeepOneVerticalOwner() {
        let (window, controller) = mounted(); defer { controller.dispose(); window.isHidden = true }
        update(controller, sections: [section("row", source: client(), count: 2000)])
        let attributes = controller.collection.layoutAttributesForItem(at: IndexPath(item: 0, section: 1))!
        XCTAssertEqual(attributes.frame.minY, 336, accuracy: 0.1)
        XCTAssertEqual(controller.collection.contentInset.bottom, 86)
        XCTAssertTrue(controller.collection.scrollsToTop)
        XCTAssertTrue(controller.rows.allSatisfy { !$0.collection.scrollsToTop })
        XCTAssertLessThanOrEqual(EmbyImagePreparation.shared.firstScreenCount, 24)
        XCTAssertLessThanOrEqual(EmbyImagePreparation.shared.activeTaskCount, 4)
        update(controller, sections: controller.sections, active: false)
        XCTAssertFalse(controller.collection.scrollsToTop)
    }

    func testExistingHomeOffsetAndOwnedRefreshBridgesAttachToNativeHost() {
        let (window, controller) = mounted(); defer { controller.dispose(); window.isHidden = true }
        var offset: CGFloat = 0, refreshes = 0
        update(controller, sections: (0..<10).map { section(String($0), source: client()) }, onOffset: { offset = $0 }, homeRefresh: { complete in refreshes += 1; complete() })
        controller.collection.setContentOffset(CGPoint(x: 0, y: 350), animated: false)
        XCTAssertEqual(offset, -350, accuracy: 0.1)
        XCTAssertEqual(controller.collection.refreshControl?.tintColor, UIColor.white.withAlphaComponent(0.96))
        controller.collection.refreshControl?.sendActions(for: .valueChanged)
        XCTAssertEqual(refreshes, 1)
        update(controller, sections: controller.sections, topToken: 1, onOffset: { offset = $0 })
        XCTAssertEqual(controller.collection.contentOffset.y, 0, accuracy: 0.1)
    }

    func testExistingContentRefreshEndsOnlyAtOriginalTaskCompletion() {
        let (window, controller) = mounted(); defer { controller.dispose(); window.isHidden = true }
        let sections = [section("row", source: client())]
        var finish: (() -> Void)?
        controller.update(sections: sections, query: "query", topHeight: 0, topPadding: 8, gap: 28, bottom: 86, loading: false, empty: nil, error: nil, active: true, topToken: 0, refresh: { finish = $0 }, homeOffset: nil, homeRefresh: nil)
        controller.collection.refreshControl?.beginRefreshing()
        controller.collection.refreshControl?.sendActions(for: .valueChanged)
        XCTAssertNotNil(finish)
        controller.update(sections: sections, query: "query", topHeight: 0, topPadding: 8, gap: 28, bottom: 86, loading: false, empty: nil, error: nil, active: true, topToken: 0, refresh: { finish = $0 }, homeOffset: nil, homeRefresh: nil)
        XCTAssertTrue(controller.collection.refreshControl?.isRefreshing == true, "Existing metadata must not prematurely end the owner's async refresh")
        finish?()
        XCTAssertFalse(controller.collection.refreshControl?.isRefreshing == true)
    }

    func testWideCellLateImageCannotOverwriteReboundItem() async {
        var pending: [URL: CheckedContinuation<UIImage?, Never>] = [:]
        let preparation = EmbyImagePreparation(operation: { url in await withCheckedContinuation { pending[url] = $0 } })
        let cell = EmbyPosterWideCell(preparation: preparation), source = client(), value = section("wide", source: source, style: .landscape)
        let a = EmbyPosterSectionCard(item: item("a"), section: value, retained: [:]), b = EmbyPosterSectionCard(item: item("b"), section: value, retained: [:])
        cell.configure(a)
        for _ in 0..<50 { await Task.yield() }
        cell.configure(b)
        for _ in 0..<50 { await Task.yield() }
        let red = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 3)).image { UIColor.red.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 3, height: 3)) }
        let blue = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 3)).image { UIColor.blue.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 3, height: 3)) }
        XCTAssertNotNil(pending[a.url!]); XCTAssertNotNil(pending[b.url!])
        pending.removeValue(forKey: a.url!)?.resume(returning: red)
        for _ in 0..<50 { await Task.yield() }
        XCTAssertFalse(cell.displayedImage === red)
        pending.removeValue(forKey: b.url!)?.resume(returning: blue)
        for _ in 0..<50 { await Task.yield() }
        XCTAssertTrue(cell.displayedImage === blue); cell.prepareForReuse(); XCTAssertNil(cell.displayedImage)
    }
}
