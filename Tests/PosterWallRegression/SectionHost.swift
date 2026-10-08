import SwiftUI
import UIKit

@MainActor final class SectionHost: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let client = EmbyAPIClient(baseURL: URL(string: "https://sections-fixture.example.test")!)
        client.automaticLibraryPages = true
        let root = SectionRoot(client: client, favorites: ProcessInfo.processInfo.arguments.contains("favorites"))
            .environment(\.serverDockBottomInset, 34)
            .environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: .home, usesMaterialBackground: false, onSelect: { _ in }))
        let host = UIHostingController(rootView: root)
        addChild(host); view.addSubview(host.view); host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor), host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        host.didMove(toParent: self)
    }
}

// Actual native presentation/navigation with fixed metadata. The Hero visual is an explicit fixture.
private struct SectionRoot: View {
    let client: EmbyAPIClient
    let favorites: Bool
    @State private var selection: LibraryItem?
    @State private var topToken = 0
    @State private var refreshFinish: (() -> Void)?
    var body: some View {
        if favorites { V3EmbyFavoritesView(client: client, onClose: {}) }
        else {
            NavigationView {
                EmbyPosterSections(sections: sections, queryIdentity: "section-fixture", topHeight: 220, topPadding: 2, sectionGap: 24, bottomPadding: 86, isActive: selection == nil, scrollToTopToken: topToken, onRefresh: { completion in refreshFinish = completion }, onHomeOffset: { _ in }, top: Color.green.opacity(0.1).overlay(Text("Hero fixture")))
                    .background(NavigationLink(isActive: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })) {
                        if let item = selection { EmbyPosterDetailDestination(item: item, client: client) } else { EmptyView() }
                    } label: { EmptyView() }.hidden())
                    .toolbar {
                        Button("回顶") { topToken += 1 }
                        if let finish = refreshFinish { Button("Finish refresh") { finish(); refreshFinish = nil } }
                    }
                    .navigationTitle("Section Fixture")
                    .serverDockPage()
            }
            .navigationViewStyle(.stack)
        }
    }
    private var sections: [EmbyPosterSection] {
        (0..<12).map { index in
            let values = (0..<20).map { card in ["Id": "\(index)-\(card)", "Name": "Card \(index)-\(card)", "Type": "Movie"] }
            let items = try! JSONDecoder().decode([LibraryItem].self, from: JSONSerialization.data(withJSONObject: values))
            let style: EmbyPosterRowStyle = index == 0 ? .library : (index == 1 ? .landscape : .poster)
            return EmbyPosterSection(id: String(index), title: "Section \(index)", items: items, client: client, style: style, onMore: { selection = items[0] }, onSelect: { selection = $0 })
        }
    }
}
