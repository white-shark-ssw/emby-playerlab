import XCTest
import SwiftUI
import UIKit

final class LayoutTests: XCTestCase {
    @MainActor private func dockFrame(current: Bool) -> CGRect {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        let host = UIHostingController(rootView: LayoutServerProbe(current: current))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        func find(_ view: UIView) -> UIView? {
            if view.accessibilityIdentifier == "dock-probe" { return view }
            for child in view.subviews { if let found = find(child) { return found } }
            return nil
        }
        let dock = find(host.view)!
        let frame = dock.convert(dock.bounds, to: window)
        window.isHidden = true
        return frame
    }

    @MainActor func testDockMatchesAcceptedBuild286Layout() {
        let accepted = dockFrame(current: false)
        let current = dockFrame(current: true)
        XCTAssertEqual(current.minY, accepted.minY, accuracy: 0.5)
        XCTAssertEqual(current.height, accepted.height, accuracy: 0.5)
        XCTAssertEqual(current.maxY, accepted.maxY, accuracy: 0.5)
        XCTAssertGreaterThan(accepted.minY, 800)
    }
}
