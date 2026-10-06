import XCTest

final class PosterMotionUITests: XCTestCase {
    func testRealNativeDecelerationAcceptsDelayedMetadataAppendWithoutOffsetJump() {
        var observedInertia = false
        for _ in 0..<3 {
            let app = XCUIApplication(); app.launch()
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
