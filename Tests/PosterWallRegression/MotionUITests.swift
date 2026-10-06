import XCTest

final class PosterMotionUITests: XCTestCase {
    private func fields(_ text: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: text.split(separator: " ").compactMap { part in
            let pieces = part.split(separator: "=", maxSplits: 1)
            return pieces.count == 2 ? (String(pieces[0]), String(pieces[1])) : nil
        })
    }

    private func checkReturn(cancelPop: Bool) {
        let app = XCUIApplication(); app.launchArguments = ["--poster-return-ui"]; app.launch()
        let wall = app.collectionViews.firstMatch
        XCTAssertTrue(wall.waitForExistence(timeout: 10))
        for _ in 0..<16 { wall.swipeUp(velocity: .fast) }
        let anchor = wall.cells.element(boundBy: 0).label
        let index = Int(anchor.split(separator: " ").last ?? "") ?? -1
        XCTAssertGreaterThanOrEqual(index, 120, "Test must leave the first two pages: \(anchor)")
        wall.cells.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Fixture Detail"].waitForExistence(timeout: 5))
        let before = fields(app.staticTexts["return-status"].label)
        XCTAssertGreaterThan(Double(before["offset"] ?? "0") ?? 0, 8000)
        if cancelPop {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.55))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.55))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
            XCTAssertTrue(app.navigationBars["Fixture Detail"].exists, "The partial system pop must actually cancel")
            let cancelled = fields(app.staticTexts["return-status"].label)
            XCTAssertGreaterThan(Int(cancelled["cancelled"] ?? "0") ?? 0, Int(before["cancelled"] ?? "0") ?? 0, "The system transition coordinator must confirm an interactive cancellation")
        }
        app.navigationBars["Fixture Detail"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Fixture Library"].waitForExistence(timeout: 5))
        let after = fields(app.staticTexts["return-status"].label)
        XCTAssertEqual(after["requests"], before["requests"], "Returning restarted the original model's first page")
        XCTAssertEqual(after["count"], before["count"])
        XCTAssertEqual(after["wall"], before["wall"])
        XCTAssertGreaterThan(Int(after["appear"] ?? "0") ?? 0, Int(before["appear"] ?? "0") ?? 0)
        XCTAssertEqual(Double(after["offset"] ?? "-1") ?? -1, Double(before["offset"] ?? "-2") ?? -2, accuracy: 1)
        XCTAssertEqual(wall.cells.element(boundBy: 0).label, anchor)
        app.terminate()
    }

    func testProductionLibraryDeepNativePushPopRetainsPositionAndFrontier() { checkReturn(cancelPop: false) }
    func testCancelledSystemPopThenBackRetainsProductionLibrary() { checkReturn(cancelPop: true) }

    func testRealNativeDecelerationAcceptsDelayedMetadataAppendWithoutOffsetJump() {
        var observedInertia = false
        for _ in 0..<3 {
            let app = XCUIApplication(); app.launchArguments = ["--poster-motion-ui"]; app.launch()
            let wall = app.collectionViews["poster-wall"]
            XCTAssertTrue(wall.waitForExistence(timeout: 10))
            wall.swipeUp(velocity: .fast)
            // The controlled metadata gate opens on the real production delegate's deceleration-begin event.
            // No second automated touch or XCTest quiescence wait can terminate the ongoing gesture first.
            let status = app.staticTexts["motion-status"].label
            XCTAssertTrue(status.contains("expanded=1"), status)
            XCTAssertTrue(status.contains("jump=0"), status)
            XCTAssertTrue(status.contains("count=120"), status)
            if status.hasPrefix("decel=1 ") {
                observedInertia = true
                XCTAssertTrue(status.contains("after_decel=1"), "Actual UIKit inertia was interrupted by the append/update: \(status)")
                app.terminate(); break
            }
            app.terminate()
        }
        XCTAssertTrue(observedInertia, "No native deceleration was observed at the controlled metadata release; this cannot count as an inertia test pass")
    }
}
