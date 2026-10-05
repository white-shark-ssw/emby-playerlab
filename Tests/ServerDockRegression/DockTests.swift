import XCTest
import SwiftUI
import UIKit

final class DockTests: XCTestCase {
    @MainActor private func fixture<V: View>(_ view: V) -> (UIWindow, UIHostingController<V>) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        settle(host.view)
        XCTAssertGreaterThan(window.bounds.height, window.bounds.width, "The device regression fixture must remain in portrait")
        return (window, host)
    }

    @MainActor private func settle(_ view: UIView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.30))
        view.layoutIfNeeded()
    }

    @MainActor private func find(_ view: UIView, identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        for child in view.subviews { if let found = find(child, identifier: identifier) { return found } }
        return nil
    }

    @MainActor private func frame<V: View>(_ view: V) -> CGRect {
        let (window, host) = fixture(view)
        defer { window.isHidden = true }
        guard let dock = find(host.view, identifier: "dock-probe") else { XCTFail("Dock not mounted"); return .zero }
        return dock.convert(dock.bounds, to: window)
    }

    @MainActor func testHomeMatchesAcceptedBuild293DockPositionWithCarouselOnAndOff() {
        let accepted = frame(LayoutServerProbe(accepted: true, immersive: true))
        for immersive in [true, false] {
            let current = frame(LayoutServerProbe(accepted: false, immersive: immersive))
            XCTAssertEqual(current.minY, accepted.minY, accuracy: 0.5)
            XCTAssertEqual(current.height, 40, accuracy: 0.5)
            XCTAssertEqual(current.maxY, accepted.maxY, accuracy: 0.5)
        }
        XCTAssertGreaterThan(accepted.minY, UIScreen.main.bounds.midY)
    }

    @MainActor func testOversizedContentAndNativeNavigationBarCannotMoveDock() {
        let plain = frame(HostProbe(oversized: false, navigationBar: false))
        for navigationBar in [true, false] {
            let oversized = frame(HostProbe(oversized: true, navigationBar: navigationBar))
            XCTAssertEqual(oversized.minY, plain.minY, accuracy: 0.5)
            XCTAssertEqual(oversized.maxY, plain.maxY, accuracy: 0.5)
            XCTAssertEqual(oversized.height, 40, accuracy: 0.5)
        }
        let (window, host) = fixture(HostProbe(oversized: false, navigationBar: false))
        defer { window.isHidden = true }
        let marker = find(host.view, identifier: "dock-probe")!
        XCTAssertEqual(marker.convert(marker.bounds, to: window).maxY, window.bounds.maxY - window.safeAreaInsets.bottom, accuracy: 0.5)
    }

    @MainActor func testAllTabsAndMaterialStylesKeepIdenticalGeometry() {
        var reference: CGRect?
        for tab in V3ServerTab.allCases {
            for material in [true, false] {
                let measured = frame(GeometryReader { root in
                    Color.clear.serverDockPage()
                        .environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: tab, usesMaterialBackground: material, onSelect: { _ in }))
                        .environment(\.serverDockBottomInset, root.safeAreaInsets.bottom)
                })
                if let reference {
                    XCTAssertEqual(measured.minY, reference.minY, accuracy: 0.5)
                    XCTAssertEqual(measured.height, reference.height, accuracy: 0.5)
                } else { reference = measured }
            }
        }
    }

    @MainActor func testPageVisibilityAndMissingServerContextDoNotMountDock() {
        for configured in [true, false] {
            let configuration: ServerDockConfiguration? = configured ? ServerDockConfiguration(selectedTab: .home, usesMaterialBackground: false, onSelect: { _ in }) : nil
            let (window, host) = fixture(Color.clear.serverDockPage(isVisible: !configured).environment(\.serverDockConfiguration, configuration))
            XCTAssertNil(find(host.view, identifier: "dock-probe"))
            window.isHidden = true
        }
    }

    @MainActor func testRealKeyboardDoesNotLiftSearchDock() {
        let (window, host) = fixture(KeyboardProbe())
        defer { window.isHidden = true }
        let dock = find(host.view, identifier: "dock-probe")!
        let before = dock.convert(dock.bounds, to: window)
        func textField(_ view: UIView) -> UITextField? {
            if let field = view as? UITextField { return field }
            for child in view.subviews { if let field = textField(child) { return field } }
            return nil
        }
        guard let field = textField(host.view) else { XCTFail("Search field missing"); return }
        let keyboard = expectation(description: "Software keyboard produces a nonzero frame")
        let observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, frame.height > 0 { keyboard.fulfill() }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        XCTAssertTrue(field.becomeFirstResponder())
        wait(for: [keyboard], timeout: 3)
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        settle(host.view)
        let after = dock.convert(dock.bounds, to: window)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(after.minY, before.minY, accuracy: 0.5)
        XCTAssertEqual(after.maxY, before.maxY, accuracy: 0.5)
        field.resignFirstResponder()
    }

    @MainActor func testNativePushHidesPageDockAndPopRestoresItsPosition() {
        let model = NavigationProbeModel()
        let (window, host) = fixture(NavigationProbe(model: model))
        defer { window.isHidden = true }
        func visibleFrames(_ view: UIView) -> [CGRect] {
            guard !view.isHidden, view.alpha > 0.01 else { return [] }
            let own = view.convert(view.bounds, to: window)
            let intersection = own.intersection(window.bounds)
            let visible = own.width > 0 && own.height > 0 && intersection.width >= own.width * 0.9 && intersection.height >= own.height * 0.9
            var result: [CGRect] = view.accessibilityIdentifier == "dock-probe" && visible ? [own] : []
            for child in view.subviews { result += visibleFrames(child) }
            return result
        }
        let before = visibleFrames(host.view)
        XCTAssertEqual(before.count, 1)
        model.isActive = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.7))
        settle(host.view)
        XCTAssertTrue(visibleFrames(host.view).isEmpty)
        model.isActive = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.7))
        settle(host.view)
        let returned = visibleFrames(host.view)
        XCTAssertEqual(returned.count, 1)
        if let first = before.first, let last = returned.first { XCTAssertEqual(first.minY, last.minY, accuracy: 0.5) }
    }

    @MainActor func testActualDetailPreferenceUsesSharedDockHost() {
        let key = "ui.detailFullyImmersive"
        let previous = UserDefaults.standard.object(forKey: key)
        defer { if let previous { UserDefaults.standard.set(previous, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) } }
        for immersive in [true, false] {
            UserDefaults.standard.set(immersive, forKey: key)
            let (window, host) = fixture(GeometryReader { root in
                DetailPolicyProbe()
                    .environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: .home, usesMaterialBackground: false, onSelect: { _ in }))
                    .environment(\.serverDockBottomInset, root.safeAreaInsets.bottom)
            })
            XCTAssertEqual(find(host.view, identifier: "dock-probe") == nil, immersive)
            window.isHidden = true
        }
    }

    @MainActor func testRootSelectionPreservesSearchLifetimeAndHomeTapActions() {
        let root = RootActionProbe()
        root.selectTab(.search)
        let original = root.searchModel
        XCTAssertNotNil(original)
        root.selectTab(.search)
        XCTAssertTrue(root.searchModel === original)
        root.selectTab(.favorites)
        XCTAssertNil(root.searchModel)
        root.selectTab(.search)
        XCTAssertFalse(root.searchModel === original)
        root.selectTab(.home)
        root.lastHomeTap = .distantPast
        root.selectTab(.home)
        XCTAssertEqual(root.homeScrollToTopToken, 1)
        root.selectTab(.home)
        XCTAssertEqual(root.homeRefreshToken, 1)
        XCTAssertEqual(root.lastHomeTap, .distantPast)
    }

    func testContentClearanceIncludesDockAndPhysicalBottomInset() {
        XCTAssertEqual(ServerDockMetrics.contentBottomPadding(bottomInset: 34), 86)
        XCTAssertEqual(ServerDockMetrics.contentBottomPadding(bottomInset: 0), 52)
    }
}
