import UIKit

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MotionHost(); window.makeKeyAndVisible(); self.window = window
        return true
    }
}

// Test-only metadata gate. Real UIKit inertia and the production collection/update path are used.
@MainActor final class MotionHost: UIViewController {
    private let wall = EmbyPosterWallController()
    private let client = EmbyAPIClient(baseURL: URL(string: "https://motion.example.test")!)
    private let release = UIButton(type: .system)
    private let status = UILabel()
    private var count = 60
    private var revision = 1
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        release.setTitle("Release metadata", for: .normal); release.accessibilityIdentifier = "release-metadata"
        release.addTarget(self, action: #selector(releaseMetadata), for: .touchUpInside)
        status.accessibilityIdentifier = "motion-status"; status.text = "pending"
        view.addSubview(release); view.addSubview(status)
        addChild(wall); view.addSubview(wall.view); wall.didMove(toParent: self)
        wall.collection.accessibilityIdentifier = "poster-wall"
        update(loading: true)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.safeAreaInsets.top
        release.frame = CGRect(x: 8, y: top, width: 180, height: 44)
        status.frame = CGRect(x: 188, y: top, width: view.bounds.width - 196, height: 44)
        wall.view.frame = CGRect(x: 0, y: top + 48, width: view.bounds.width, height: view.bounds.height - top - 48)
    }
    private func update(loading: Bool) {
        let items = (0..<count).map { index -> LibraryItem in
            let data = try! JSONSerialization.data(withJSONObject: ["Id": String(index), "Name": "Movie \(index)", "Type": "Movie"])
            return try! JSONDecoder().decode(LibraryItem.self, from: data)
        }
        wall.update(EmbyPosterWall(items: items, revision: revision, replacement: 1, client: client, isLoading: loading, hasLoaded: true, error: nil, emptyText: "empty", bottomPadding: 86, isActive: true, onApproachingEnd: {}, onRefresh: {}, onSelect: { _ in }))
    }
    @objc private func releaseMetadata() {
        let moving = wall.collection.isDecelerating
        let offset = wall.collection.contentOffset.y
        let height = wall.collection.contentSize.height
        count += 60; revision += 1; update(loading: false)
        wall.collection.layoutIfNeeded()
        let after = wall.collection.contentOffset.y
        let expanded = wall.collection.contentSize.height > height
        status.text = "decel=\(moving ? 1 : 0) after_decel=\(wall.collection.isDecelerating ? 1 : 0) expanded=\(expanded ? 1 : 0) jump=\(abs(after - offset) < 1 ? 0 : 1) count=\(wall.collection.numberOfItems(inSection: 0))"
        status.accessibilityLabel = status.text
    }
}
