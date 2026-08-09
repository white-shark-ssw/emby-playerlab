import SwiftUI

struct EmbyServerRootViewV2: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.presentationMode) private var presentationMode
    let session: EmbySession

    @State private var client: EmbyAPIClient?
    @State private var selectedTab: V2ServerTab = .home
    @State private var homeRefreshToken = 0
    @State private var homeScrollToTopToken = 0
    @State private var lastHomeTap = Date.distantPast

    var body: some View {
        Group {
            if let client {
                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case .home:
                            V2EmbyHomeView(session: session, client: client, refreshToken: homeRefreshToken, scrollToTopToken: homeScrollToTopToken, onClose: close)
                        case .favorites:
                            V2EmbyFavoritesView(client: client, onClose: close)
                        case .search:
                            V2EmbySearchView(client: client, onClose: close)
                        case .settings:
                            V2EmbyServerSettingsView(session: session, onClose: close)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    serverTabBar
                }
                .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            } else {
                ProgressView("连接 \(session.serverName)…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        do { client = try sessionStore.client(for: session) }
                        catch { presentationMode.wrappedValue.dismiss() }
                    }
            }
        }
    }

    private var serverTabBar: some View {
        HStack(spacing: 0) {
            serverTabButton(.home, title: "首页", systemImage: "house")
            serverTabButton(.favorites, title: "收藏", systemImage: "heart")
            serverTabButton(.search, title: "搜索", systemImage: "magnifyingglass")
            serverTabButton(.settings, title: "设置", systemImage: "gearshape")
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func serverTabButton(_ tab: V2ServerTab, title: String, systemImage: String) -> some View {
        Button {
            if tab == .home && selectedTab == .home {
                let now = Date()
                if now.timeIntervalSince(lastHomeTap) <= 0.36 {
                    homeRefreshToken += 1
                    lastHomeTap = .distantPast
                } else {
                    homeScrollToTopToken += 1
                    lastHomeTap = now
                }
            } else {
                selectedTab = tab
                if tab == .home { lastHomeTap = Date() }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: selectedTab == tab && tab != .search ? systemImage + ".fill" : systemImage)
                    .font(.system(size: 22))
                Text(title).font(.caption2)
            }
            .foregroundColor(selectedTab == tab ? .blue : .secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func close() {
        sessionStore.leaveServer()
        presentationMode.wrappedValue.dismiss()
    }
}

private enum V2ServerTab {
    case home
    case favorites
    case search
    case settings
}

private struct V2EmbyHomeView: View {
    let session: EmbySession
    let client: EmbyAPIClient
    let refreshToken: Int
    let scrollToTopToken: Int
    let onClose: () -> Void
    @StateObject private var model: V2EmbyHomeViewModel

    init(session: EmbySession, client: EmbyAPIClient, refreshToken: Int, scrollToTopToken: Int, onClose: @escaping () -> Void) {
        self.session = session
        self.client = client
        self.refreshToken = refreshToken
        self.scrollToTopToken = scrollToTopToken
        self.onClose = onClose
        _model = StateObject(wrappedValue: V2EmbyHomeViewModel(client: client))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            Color.clear.frame(height: 1).id("v2-home-top")

                            if model.isLoading && model.libraries.isEmpty {
                                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                            } else {
                                if !model.libraries.isEmpty {
                                    sectionTitle("我的媒体")
                                    libraryRow
                                }

                                if !model.resumeItems.isEmpty {
                                    sectionTitle("继续观看")
                                    landscapeRow(model.resumeItems)
                                }

                                ForEach(model.libraries) { library in
                                    if let items = model.latestByLibrary[library.id], !items.isEmpty {
                                        HStack(spacing: 8) {
                                            sectionTitle(library.name)
                                            Spacer()
                                            NavigationLink("更多", destination: V2LibraryBrowserView(library: library, client: client))
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .padding(.trailing, 16)
                                        }
                                        posterRow(items)
                                    }
                                }

                                if let error = model.errorMessage {
                                    Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 28)
                    }
                    .refreshable { await model.refresh() }
                    .onChange(of: refreshToken) { _ in Task { await model.refresh() } }
                    .onChange(of: scrollToTopToken) { _ in
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("v2-home-top", anchor: .top) }
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 23))
                .foregroundColor(.green)
            Spacer()
            Text(session.serverName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.bold))
            .padding(.horizontal, 16)
    }

    private var libraryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(model.libraries) { library in
                    NavigationLink(destination: V2LibraryBrowserView(library: library, client: client)) {
                        V2LibraryTile(item: library, client: client)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func landscapeRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in V2LandscapeCard(item: item, client: client) }
            }
            .padding(.horizontal, 16)
        }
    }

    private func posterRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(items) { item in V2PosterCard(item: item, client: client, width: 118) }
            }
            .padding(.horizontal, 16)
        }
    }
}

@MainActor
private final class V2EmbyHomeViewModel: ObservableObject {
    @Published var libraries: [LibraryItem] = []
    @Published var resumeItems: [LibraryItem] = []
    @Published var latestByLibrary: [String: [LibraryItem]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(client: EmbyAPIClient) { self.client = client }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            async let viewsRequest = client.userViews()
            async let resumeRequest = client.resumeItems(limit: 18)
            let (views, resume) = try await (viewsRequest, resumeRequest)
            libraries = views
            resumeItems = resume

            var latest: [String: [LibraryItem]] = [:]
            await withTaskGroup(of: (String, [LibraryItem]?).self) { group in
                for library in views {
                    group.addTask {
                        do { return (library.id, try await self.client.latestItems(parentId: library.id, limit: 16)) }
                        catch { return (library.id, nil) }
                    }
                }
                for await result in group {
                    if let items = result.1 { latest[result.0] = items }
                }
            }
            latestByLibrary = latest
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct V2LibraryBrowserView: View {
    let library: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: V2LibraryBrowserViewModel
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    init(library: LibraryItem, client: EmbyAPIClient) {
        self.library = library
        self.client = client
        _model = StateObject(wrappedValue: V2LibraryBrowserViewModel(library: library, client: client))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(contentTitle).font(.headline).foregroundColor(.blue)
                    Spacer()
                    Menu {
                        sortButton("加入日期", key: "DateCreated")
                        sortButton("标题", key: "SortName")
                        sortButton("发行日期", key: "PremiereDate")
                        sortButton("播放日期", key: "DatePlayed")
                        sortButton("播放次数", key: "PlayCount")
                        sortButton("播放时长", key: "Runtime")
                        sortButton("随机", key: "Random")
                    } label: {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 20))
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(model.items) { item in V2PosterCard(item: item, client: client, width: nil) }
                }

                if model.isLoading { ProgressView().frame(maxWidth: .infinity).padding() }
                if let error = model.errorMessage { Text(error).foregroundColor(.red).font(.footnote) }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
        }
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .onAppear { if !model.hasLoaded { Task { await model.load() } } }
    }

    private var contentTitle: String {
        switch library.collectionType?.lowercased() {
        case "tvshows": return "节目"
        case "movies": return "电影"
        default: return "内容"
        }
    }

    private func sortButton(_ title: String, key: String) -> some View {
        Button {
            model.sortBy = key
            Task { await model.load() }
        } label: {
            if model.sortBy == key { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }
}

@MainActor
private final class V2LibraryBrowserViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    var sortBy = "DateCreated"
    private let library: LibraryItem
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(library: LibraryItem, client: EmbyAPIClient) {
        self.library = library
        self.client = client
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do { items = try await client.libraryItems(parentId: library.id, limit: 120, sortBy: sortBy).items }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct V2EmbyFavoritesView: View {
    let client: EmbyAPIClient
    let onClose: () -> Void
    @StateObject private var model: V2FavoritesViewModel

    init(client: EmbyAPIClient, onClose: @escaping () -> Void) {
        self.client = client
        self.onClose = onClose
        _model = StateObject(wrappedValue: V2FavoritesViewModel(client: client))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                V2PageHeader(title: "收藏", onClose: onClose)
                favoriteSection("电影", items: model.movies)
                favoriteSection("剧集", items: model.series)
                favoritePeople
                favoriteSection("合集", items: model.collections)
                if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 16) }
            }
            .padding(.bottom, 26)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .refreshable { await model.load() }
        .onAppear { if !model.hasLoaded { Task { await model.load() } } }
    }

    @ViewBuilder
    private func favoriteSection(_ title: String, items: [LibraryItem]) -> some View {
        if !items.isEmpty {
            Text(title).font(.title2.weight(.bold)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in V2PosterCard(item: item, client: client, width: 118) }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var favoritePeople: some View {
        if !model.people.isEmpty {
            Text("演员").font(.title2.weight(.bold)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(model.people) { person in
                        VStack(spacing: 6) {
                            V2RemoteImage(url: client.imageURL(itemId: person.id, maxWidth: 260, tag: person.primaryImageTag), contentMode: .fill)
                                .frame(width: 92, height: 92)
                                .clipShape(Circle())
                            Text(person.name).font(.subheadline).lineLimit(1).frame(width: 102)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

@MainActor
private final class V2FavoritesViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(client: EmbyAPIClient) { self.client = client }
    var movies: [LibraryItem] { items.filter { ["movie", "video", "episode"].contains($0.type?.lowercased() ?? "") } }
    var series: [LibraryItem] { items.filter { $0.type?.caseInsensitiveCompare("Series") == .orderedSame } }
    var people: [LibraryItem] { items.filter { $0.type?.caseInsensitiveCompare("Person") == .orderedSame } }
    var collections: [LibraryItem] { items.filter { ["boxset", "collectionfolder"].contains($0.type?.lowercased() ?? "") } }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do { items = try await client.favoriteItems() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct V2EmbySearchView: View {
    let client: EmbyAPIClient
    let onClose: () -> Void
    @StateObject private var model: V2SearchViewModel
    @State private var searchText = ""
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    init(client: EmbyAPIClient, onClose: @escaping () -> Void) {
        self.client = client
        self.onClose = onClose
        _model = StateObject(wrappedValue: V2SearchViewModel(client: client))
    }

    var body: some View {
        VStack(spacing: 10) {
            V2PageHeader(title: "搜索", onClose: onClose)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索当前 Emby", text: $searchText, onCommit: { Task { await model.search(searchText) } })
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = ""; model.items = [] } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(model.items) { item in V2PosterCard(item: item, client: client, width: nil) }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
            }
            if model.isLoading { ProgressView().padding(.bottom, 8) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }
}

@MainActor
private final class V2SearchViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    private let client: EmbyAPIClient

    init(client: EmbyAPIClient) { self.client = client }

    func search(_ term: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do { items = try await client.searchItems(term: term) }
        catch { items = [] }
    }
}

private struct V2EmbyServerSettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let session: EmbySession
    let onClose: () -> Void
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    V2PageHeader(title: "设置", onClose: onClose)
                    V2SettingsCard {
                        settingRow("服务器", value: session.serverName, systemImage: "externaldrive")
                        Divider().padding(.leading, 46)
                        settingRow("用户", value: session.user.name, systemImage: "person")
                        Divider().padding(.leading, 46)
                        settingRow("版本", value: session.serverVersion, systemImage: "info.circle")
                    }

                    V2SettingsCard {
                        NavigationLink(destination: PlayerSettingsView()) { settingRow("播放设置", value: nil, systemImage: "playpause") }
                        Divider().padding(.leading, 46)
                        NavigationLink(destination: PlaybackLabView()) { settingRow("播放器实验室", value: nil, systemImage: "wrench.and.screwdriver") }
                    }

                    V2SettingsCard {
                        Button {
                            do { shareURL = try DiagnosticsLogger.shared.export() } catch {}
                        } label: {
                            settingRow("导出播放日志", value: nil, systemImage: "doc.text")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let shareURL { ActivityView(items: [shareURL]) }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func settingRow(_ title: String, value: String?, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundColor(.blue).frame(width: 26)
            Text(title).foregroundColor(.primary)
            Spacer()
            if let value { Text(value).foregroundColor(.secondary).lineLimit(1) }
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct V2SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct V2PageHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Spacer().frame(width: 36)
            Spacer()
            Text(title).font(.title2.weight(.bold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct V2LibraryTile: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View {
        VStack(spacing: 6) {
            V2RemoteImage(url: client.imageURL(itemId: item.id, maxWidth: 480, tag: item.primaryImageTag), contentMode: .fill)
                .frame(width: 164, height: 92)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name).font(.subheadline.weight(.medium)).foregroundColor(.primary).lineLimit(1).frame(width: 164)
        }
    }
}

private struct V2LandscapeCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomLeading) {
                V2RemoteImage(url: client.imageURL(itemId: item.id, imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop", maxWidth: 650, tag: item.backdropImageTags.first ?? item.primaryImageTag), contentMode: .fill)
                    .frame(width: 212, height: 120)
                    .clipped()
                if item.playbackProgress > 0 {
                    GeometryReader { proxy in
                        VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(1).frame(width: 212, alignment: .leading)
            Text(v2MediaSubtitle(item)).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
    }
}

private struct V2PosterCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    let width: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                V2RemoteImage(url: client.imageURL(itemId: item.id, maxWidth: 440, tag: item.primaryImageTag), contentMode: .fill)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: width)
                    .clipped()
                if item.playbackProgress > 0 {
                    GeometryReader { proxy in
                        VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) }
                    }
                }
                if let count = item.userData?.unplayedItemCount, count > 0 {
                    VStack { HStack { Spacer(); Text("\(count)").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.blue).clipShape(Circle()) }; Spacer() }.padding(5)
                } else if item.isPlayed {
                    VStack { HStack { Spacer(); Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.green).clipShape(Circle()) }; Spacer() }.padding(5)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(item.name).font(.subheadline).lineLimit(1)
            if let year = item.productionYear { Text(String(year)).font(.caption).foregroundColor(.secondary) }
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct V2RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().aspectRatio(contentMode: contentMode)
            case .failure: placeholder
            case .empty: ZStack { placeholder; ProgressView() }
            @unknown default: placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "play.rectangle").font(.system(size: 24)).foregroundColor(.secondary)
        }
    }
}

private func v2MediaSubtitle(_ item: LibraryItem) -> String {
    if let seriesName = item.seriesName, let season = item.parentIndexNumber, let episode = item.indexNumber {
        return "\(seriesName) · S\(season):E\(episode)"
    }
    if let year = item.productionYear { return String(year) }
    return item.type ?? ""
}
