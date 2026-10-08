import SwiftUI

// One native vertical host and one resident system navigation link. Queries and paging remain in the caller's model.
struct EmbyPosterResultsPage: View {
    let items: [LibraryItem]
    let revision: Int
    let replacement: Int
    let client: EmbyAPIClient
    var content: EmbyPosterWallContent = .media
    let queryIdentity: String
    let isLoading: Bool
    let hasLoaded: Bool
    let error: String?
    let emptyText: String
    let bottomPadding: CGFloat
    let onApproachingEnd: () -> Void
    var horizontalPadding: CGFloat = 14
    var topPadding: CGFloat = 8
    var imagePixelWidth: Int? = nil
    var loadAheadItemCount: Int = EmbyPosterGridMetrics.loadAheadItemCount
    var landingHeader: EmbyPosterLandingHeaderInput? = nil
    var emptyFooterHeight: CGFloat = 132
    var isActive: Bool = true
    @State private var selection: LibraryItem?

    var body: some View {
        EmbyPosterWall(items: items, revision: revision, replacement: replacement, client: client, content: content, queryIdentity: queryIdentity, allowsRefresh: false, horizontalPadding: horizontalPadding, topPadding: topPadding, imagePixelWidth: imagePixelWidth, loadAheadItemCount: loadAheadItemCount, landingHeader: landingHeader, emptyFooterHeight: emptyFooterHeight, isLoading: isLoading, hasLoaded: hasLoaded, error: error, emptyText: emptyText, bottomPadding: bottomPadding, isActive: isActive && selection == nil, onApproachingEnd: onApproachingEnd, onRefresh: {}, onSelect: { selection = $0 })
            .background(
                NavigationLink(isActive: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })) {
                    if let item = selection {
                        if content == .people {
                            EmbyPersonMediaView(person: EmbyPerson(itemId: item.id, name: item.name, role: nil, type: item.type, primaryImageTag: item.primaryImageTag), client: client)
                        } else {
                            EmbyPosterDetailDestination(item: item, client: client)
                        }
                    }
                } label: { EmptyView() }
                .hidden()
            )
    }
}
