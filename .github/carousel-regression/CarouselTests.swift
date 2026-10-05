import XCTest
import SwiftUI
import UIKit

final class CarouselTests: XCTestCase {
    @MainActor private func fixture() -> (UIWindow, V3HomeCarouselNativeView, [V3HomeCarouselPresentationItem]) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let view = V3HomeCarouselNativeView(frame: window.bounds)
        window.rootViewController!.view.addSubview(view)
        let items = ["logo-page", "text-page", "third-page"].map { V3HomeCarouselPresentationItem(id: $0, title: $0, overview: "overview", rating: 8, year: 2026, officialRating: nil, typeTitle: "Movie", heroURL: nil, logoURL: nil) }
        let logo = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 30)).image { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 30)) }
        view.configure(items: items, resources: [items[0].id: V3HomeCarouselNativeResource(heroImage: nil, logoImage: logo, analysis: nil)])
        view.updateGeometry(width: 430, viewportHeight: 932, surfaceHeight: 932, displayRange: 0.30, rawScrollMinY: 0)
        return (window, view, items)
    }

    @MainActor func testFollowAndReversePreservePageSpacingAndBaseCenter() {
        let (window, view, items) = fixture()
        defer { window.isHidden = true }
        let pages = view.subviews[2].subviews
        for direction in [1, -1] {
            for progress in [CGFloat(0), 0.1, 0.4, 0.7, 0.2, 0] {
                view.applyVisualState(V3HomeCarouselTransitionVisualState(currentID: items[0].id, fromID: items[0].id, toID: items[1].id, direction: direction, progress: progress), animated: false)
                view.setNeedsLayout()
                view.layoutIfNeeded()
                let from = pages[0].convert(pages[0].bounds, to: pages[0].superview)
                let to = pages[1].convert(pages[1].bounds, to: pages[1].superview)
                XCTAssertEqual(pages[0].center.x, 215, accuracy: 0.01)
                XCTAssertEqual(pages[1].center.x, 215, accuracy: 0.01)
                XCTAssertEqual(from.minX, -CGFloat(direction) * progress * 430, accuracy: 0.01)
                XCTAssertEqual(to.minX - from.minX, CGFloat(direction) * 430, accuracy: 0.01)
                XCTAssertTrue(pages[2].isHidden)
            }
        }
    }

    @MainActor func testVerticalLayoutAndResourceArrivalDoNotUndoTranslation() {
        let (window, view, items) = fixture()
        defer { window.isHidden = true }
        let pages = view.subviews[2].subviews
        view.applyVisualState(V3HomeCarouselTransitionVisualState(currentID: items[0].id, fromID: items[0].id, toID: items[1].id, direction: 1, progress: 0.4), animated: false)
        for scroll in [CGFloat(-50), 20, 0] {
            view.updateRawScrollMinY(scroll)
            view.setImageAnalysis(V3HomeCarouselImageAnalysis(sourceSize: CGSize(width: 1400, height: 2100), prefersLightForeground: true, red: 0.2, green: 0.2, blue: 0.2), itemID: items[0].id)
            XCTAssertEqual(pages[0].convert(pages[0].bounds, to: pages[0].superview).minX, -172, accuracy: 0.01)
            XCTAssertEqual(pages[1].convert(pages[1].bounds, to: pages[1].superview).minX, 258, accuracy: 0.01)
        }
    }

    @MainActor func testAnimationReleaseMovesInSameDirectionAndInterruptIsContinuous() {
        let (window, view, items) = fixture()
        defer { window.isHidden = true }
        let from = view.subviews[2].subviews[0]
        view.applyVisualState(V3HomeCarouselTransitionVisualState(currentID: items[0].id, fromID: items[0].id, toID: items[1].id, direction: 1, progress: 0.4), animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        view.animateVisualState(V3HomeCarouselTransitionVisualState(currentID: items[0].id, fromID: items[0].id, toID: items[1].id, direction: 1, progress: 1), duration: 0.6, curve: .linear, completion: { XCTFail("Interrupted completion must not run") })
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        let visible = from.layer.presentation()!
        let visibleX = visible.position.x + CGFloat(visible.transform.m41) - visible.bounds.width * 0.5
        XCTAssertLessThan(visibleX, -172)
        let progress = view.interruptAndReadProgress(fromID: items[0].id, toID: items[1].id, direction: 1, fallback: 0.4)
        XCTAssertGreaterThan(progress, 0.4)
        XCTAssertLessThan(progress, 1)
        XCTAssertEqual(from.convert(from.bounds, to: from.superview).minX, visibleX, accuracy: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.65))
    }

    @MainActor func testRuntimeTakeoverReverseAndOldCompletionCannotSettle() {
        let (window, view, items) = fixture()
        defer { window.isHidden = true }
        let bridge = V3HomeCarouselPresentationBridge()
        bridge.configure(items: items)
        bridge.updateGeometry(width: 430, viewportHeight: 932, surfaceHeight: 932, displayRange: 0.30)
        bridge.bind(view)
        let runtime = V3HomeCarouselRuntimeState(currentID: items[0].id)
        runtime.bind(presentation: bridge)
        runtime.synchronize(itemIDs: items.map(\.id))
        XCTAssertTrue(runtime.prepareHorizontalDrag(acquisitionTranslationX: -1))
        runtime.updateDrag(translationX: -172, width: 430)
        runtime.finishDrag(actualTranslationX: -172, releaseVelocityX: 0, width: 430)
        RunLoop.main.run(until: Date().addingTimeInterval(0.06))
        XCTAssertTrue(runtime.prepareHorizontalDrag(acquisitionTranslationX: 1))
        let origin = runtime.progress
        XCTAssertGreaterThan(origin, 0.4)
        runtime.updateDrag(translationX: 20, width: 430)
        XCTAssertEqual(runtime.progress, origin - 20 / 430, accuracy: 0.001)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        XCTAssertEqual(runtime.currentID, items[0].id)
        XCTAssertTrue(runtime.isDragging)
        runtime.cancelDrag()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        XCTAssertNil(runtime.toID)
        XCTAssertEqual(runtime.currentID, items[0].id)
    }
}
