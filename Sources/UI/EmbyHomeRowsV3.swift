import SwiftUI
import Combine
import UIKit

extension V3EmbyHomeView {
    func sectionTitle(_ title: String) -> some View { Text(title).font(.title2.weight(.bold)).padding(.horizontal, 16) }

    var libraryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(model.visibleLibraries) { library in
                    NavigationLink(destination: V3LibraryBrowserView(library: library, client: client, dock: dock)) { V3LibraryTile(item: library, client: client) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    func landscapeRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    EmbyPosterDetailLink(item: item, client: client) { V3LandscapeCard(item: item, client: client) }
                        .frame(width: 212, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    func posterRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(items) { item in
                    EmbyPosterDetailLink(item: item, client: client) {
                        V3PosterCard(item: item, client: client, width: 118).contentShape(Rectangle())
                    }
                    .frame(width: 118, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
