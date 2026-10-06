import SwiftUI
import UIKit

// Production Library view/model/wall/Dock are compiled unchanged. Only non-pilot destinations and
// non-pilot tab cards are fixtures. Pages use the requested60-item boundary, with no synthetic offset.
@MainActor final class LibraryReturnHost: UIViewController {
    private let client = EmbyAPIClient(baseURL: URL(string: "https://\(UUID().uuidString).example.test")!)
    private let status = UILabel()
    private var appearances = 0
    private var cancelledPops = 0
    private var lastGeometry = "pending"

    override func viewDidLoad() {
        super.viewDidLoad()
        client.automaticLibraryPages = true
        let data = try! JSONSerialization.data(withJSONObject: ["Id": "lib", "Name": "Fixture Library", "Type": "CollectionFolder", "CollectionType": "movies"])
        let item = try! JSONDecoder().decode(LibraryItem.self, from: data)
        let host = UIHostingController(rootView: NavigationView { V3LibraryBrowserView(library: item, client: client) }.navigationViewStyle(.stack))
        addChild(host); view.addSubview(host.view); host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor), host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        host.didMove(toParent: self)
        status.accessibilityIdentifier = "return-status"; status.font = .systemFont(ofSize: 8)
        status.backgroundColor = .systemBackground; status.numberOfLines = 2; view.addSubview(status)
        DiagnosticsLogger.shared.onRecord = { [weak self] message in
            guard message.hasPrefix("event=view-appear ") || message.hasPrefix("event=view-disappear ") || message.hasPrefix("event=geometry ") || message.hasPrefix("event=items-after ") || message == "event=test-pop-cancel" else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                if message.hasPrefix("event=view-appear ") { self.appearances += 1 }
                if message == "event=test-pop-cancel" { self.cancelledPops += 1 }
                else { self.lastGeometry = message.split(separator: " ").filter { $0.hasPrefix("wall=") || $0.hasPrefix("offset=") || $0.hasPrefix("count=") }.joined(separator: " ") }
                self.status.text = "requests=\(self.client.requests.count) appear=\(self.appearances) cancelled=\(self.cancelledPops) \(self.lastGeometry)"
            }
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        status.frame = CGRect(x: 0, y: view.bounds.height - view.safeAreaInsets.bottom - 28, width: view.bounds.width, height: 28)
    }
}

struct EmbyPosterDetailDestination: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    var body: some View { Text("Fixture Detail \(item.id)").navigationTitle("Fixture Detail").background(ReturnTransitionProbe()) }
}
// Observe the real system coordinator; never install a delegate, drive progress or own the transition.
private struct ReturnTransitionProbe: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Probe { Probe() }
    func updateUIViewController(_ controller: Probe, context: Context) {}
    final class Probe: UIViewController {
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let coordinator = transitionCoordinator, coordinator.isInteractive else { return }
            coordinator.notifyWhenInteractionChanges { context in
                if context.isCancelled { DiagnosticsLogger.shared.log("TestNavigation", "event=test-pop-cancel") }
            }
        }
    }
}
struct EmbyUserDataChange {
    static let notification = Notification.Name("TestUserData")
    static let itemIDKey = "itemID"
}
extension View { func nativeInteractivePop() -> some View { self } }
struct EmbyPosterGrid<Content: View>: View {
    let items: [LibraryItem]
    var onApproachingEnd: (() -> Void)? = nil
    @ViewBuilder let content: (LibraryItem) -> Content
    var body: some View { EmptyView() }
}
struct EmbyPosterDetailLink<Content: View>: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    @ViewBuilder let content: () -> Content
    var body: some View { content() }
}
struct V3PosterCard: View {
    let item: LibraryItem; let client: EmbyAPIClient; let width: CGFloat?
    var body: some View { EmptyView() }
}
struct V3LandscapeCard: View {
    let item: LibraryItem; let client: EmbyAPIClient
    var body: some View { EmptyView() }
}
struct V3LibraryGenreGridView: View {
    let library: LibraryItem; let genre: LibraryItem; let client: EmbyAPIClient
    var body: some View { EmptyView() }
}
struct V3LibraryGenreCard: View {
    let item: LibraryItem; let client: EmbyAPIClient
    var body: some View { EmptyView() }
}
struct V3LibraryFolderGrid: View {
    let items: [LibraryItem]; let client: EmbyAPIClient
    var body: some View { EmptyView() }
}
