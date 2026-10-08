import SwiftUI
import UIKit
import Combine

// Controlled session/network boundary. The Search view, model, preloader, wall and Dock are production source.
@MainActor final class SessionStore: ObservableObject {
    @Published var sessions: [EmbySession]
    init(_ sessions: [EmbySession] = []) { self.sessions = sessions }
    func clientForBestRoute(for stored: EmbySession) async throws -> EmbyAPIClient { EmbyAPIClient(baseURL: stored.serverURL, userId: stored.user.id) }
}

@MainActor final class SearchLandingHost: UIViewController {
    private let client = EmbyAPIClient(baseURL: URL(string: "https://search-fixture.example.test")!)
    private let status = UILabel()
    private var lastGeometry = "pending"
    override func viewDidLoad() {
        super.viewDidLoad()
        for key in ["oneplayer.search.global-enabled.v1", "oneplayer.search.recommendations-enabled.v1", "oneplayer.search.selected-server-ids.v1"] { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.set(["History fixture"], forKey: "oneplayer.search.history.v1")
        client.automaticLibraryPages = true
        let session = EmbySession(serverURL: client.baseURL, serverId: "fixture", serverName: "Fixture Server", serverVersion: "test", user: EmbyUser(id: "test", name: "Test"), tokenAccount: "fixture")
        let store = SessionStore([session])
        let root = V3EmbyGlobalSearchView(currentSession: session, currentClient: client, model: V3GlobalSearchViewModel(), onClose: {}).environmentObject(store).environment(\.serverDockBottomInset, 34).environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: .search, usesMaterialBackground: true, onSelect: { _ in }))
        let host = UIHostingController(rootView: root)
        addChild(host); view.addSubview(host.view); host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor), host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        host.didMove(toParent: self)
        status.accessibilityIdentifier = "search-status"; status.font = .systemFont(ofSize: 8); status.numberOfLines = 2; status.backgroundColor = .systemBackground; view.addSubview(status)
        DiagnosticsLogger.shared.onRecord = { [weak self] message in
            guard message.hasPrefix("event=view-appear ") || message.hasPrefix("event=view-disappear ") || message.hasPrefix("event=geometry ") || message.hasPrefix("event=items-after ") else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.lastGeometry = message.split(separator: " ").filter { $0.hasPrefix("wall=") || $0.hasPrefix("offset=") || $0.hasPrefix("count=") }.joined(separator: " ")
                self.status.text = "recommendations=\(self.client.recommendationRequests.count) results=\(self.client.resultRequests.count) \(self.lastGeometry)"
            }
        }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); status.frame = CGRect(x: 0, y: view.bounds.height - 24, width: view.bounds.width, height: 24) }
}
