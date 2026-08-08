import SwiftUI

struct EmbyServerRootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.presentationMode) private var presentationMode
    let session: EmbySession

    @State private var client: EmbyAPIClient?
    @State private var selectedTab: ServerTab = .home
    @State private var homeRefreshToken = 0
    @State private var homeScrollToTopToken = 0
    @State private var lastHomeTap = Date.distantPast

    var body: some View {
        Group {
            if let client {
                VStack(spacing: 0) {
                    ZStack {
                        switch selectedTab {
                        case .home:
                            EmbyHomeView(session: session, client: client, refreshToken: homeRefreshToken, scrollToTopToken: homeScrollToTopToken, onClose: close)
                        case .favorites:
                            EmbyFavoritesView(session: session, client: client, onClose: close)
                        case .search:
                            EmbySearchView(session: session, client: client, onClose: close)
                        case .settings:
                            EmbyServerSettingsView(session: session, client: client, onClose: close)
                                .environmentObject(sessionStore)
                        }
                    }
                    serverTabBar
                }
                .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            } else {
                ProgressView("连接 \(session.serverName)…")
                    .onAppear {
                        do { client = try sessionStore.client(for: session) }
                        catch { presentationMode.wrappedValue.dismiss() }
                    }
            }
        }
    }

    private var serverTabBar: some View {
        HStack {
            serverTabButton(.home, title: "首页", systemImage: "house")
            serverTabButton(.favorites, title: "收藏", systemImage: "heart")
            serverTabButton(.search, title: "搜索", systemImage: "magnifyingglass")
            serverTabButton(.settings, title: "设置", systemImage: "gearshape")
        }
        .padding(.top, 7)
        .padding(.bottom, 5)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func serverTabButton(_ tab: ServerTab, title: String, systemImage: String) -> some View {
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
            VStack(spacing: 3) {
                Image(systemName: selectedTab == tab ? systemImage + ".fill" : systemImage)
                    .font(.system(size: 26, weight: .regular))
                Text(title).font(.caption)
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

private enum ServerTab {
    case home
    case favorites
    case search
    case settings
}

private struct EmbyHomeView: View {
    let session: EmbySession
    let client: EmbyAPIClient
    let refreshToken: Int
    let scrollToTopToken: Int
    let onClose: () -> Void
    @StateObject private var model: EmbyHomeViewModel

    init(session: EmbySession, client: EmbyAPIClient, refreshToken: Int, scrollToTopToken: Int, onClose: @escaping () -> Void) {
        self.session = session
        self.client = client
        self.refreshToken = refreshToken
        self.scrollToTopToken = scrollToTopToken
        self.onClose = onClose
        _model = StateObject(wrappedValue: EmbyHomeViewModel(client: client))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                RefreshableScrollView(refreshToken: refreshToken, scrollToTopToken: scrollToTopToken, onRefresh: { await model.refresh() }) {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        serverHeader

                        if model.isLoading && model.libraries.isEmpty {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                        } else {
                            if !model.libraries.isEmpty {
                                homeSectionTitle("我的媒体")
                                horizontalLibraries
                            }

                            if !model.resumeItems.isEmpty {
                                homeSectionTitle("继续观看")
                                horizontalLandscapeItems(model.resumeItems)
                            }

                            ForEach(model.libraries.prefix(6)) { library in
                                if let items = model.latestByLibrary[library.id], !items.isEmpty {
                                    HStack {
                                        homeSectionTitle(library.name)
                                        Spacer()
                                        NavigationLink("更多", destination: LibraryBrowserView(library: library, client: client))
                                            .foregroundColor(.blue)
                                    }
                                    posterRow(items)
                                }
                            }

                            if let error = model.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 34)
                }
            }
            .navigationBarHidden(true)
            .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }
            .onChange(of: refreshToken) { _ in }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var serverHeader: some View {
        HStack {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)
            Spacer()
            Text(session.serverName)
                .font(.system(size: 23, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 42, height: 42)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private func homeSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 27, weight: .bold))
            .padding(.horizontal, 16)
    }

    private var horizontalLibraries: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(model.libraries) { library in
                    NavigationLink(destination: LibraryBrowserView(library: library, client: client)) {
                        LibraryTile(item: library, client: client)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func horizontalLandscapeItems(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    MediaLandscapeCard(item: item, client: client)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func posterRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(items) { item in
                    MediaPosterCard(item: item, client: client, width: 126)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

@MainActor
private final class EmbyHomeViewModel: ObservableObject {
    @Published var libraries: [LibraryItem] = []
    @Published var resumeItems: [LibraryItem] = []
    @Published var latestByLibrary: [String: [LibraryItem]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(client: EmbyAPIClient) {
        self.client = client
    }

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
                for library in views.prefix(6) {
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

private struct LibraryBrowserView: View {
    let library: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: LibraryBrowserViewModel
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(library: LibraryItem, client: EmbyAPIClient) {
        self.library = library
        self.client = client
        _model = StateObject(wrappedValue: LibraryBrowserViewModel(library: library, client: client))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(contentTitle)
                        .font(.headline)
                        .foregroundColor(.blue)
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
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 23))
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    ForEach(model.items) { item in
                        MediaPosterCard(item: item, client: client, width: nil)
                    }
                }

                if model.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
                if let error = model.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
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
private final class LibraryBrowserViewModel: ObservableObject {
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

private struct EmbyFavoritesView: View {
    let session: EmbySession
    let client: EmbyAPIClient
    let onClose: () -> Void
    @StateObject private var model: EmbyFavoritesViewModel

    init(session: EmbySession, client: EmbyAPIClient, onClose: @escaping () -> Void) {
        self.session = session
        self.client = client
        self.onClose = onClose
        _model = StateObject(wrappedValue: EmbyFavoritesViewModel(client: client))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                pageHeader(title: "收藏", onClose: onClose)
                favoriteSection("电影", items: model.movies)
                favoriteSection("剧集", items: model.series)
                favoritePeopleSection
                favoriteSection("合集", items: model.collections)
                if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                if let error = model.errorMessage { Text(error).foregroundColor(.red).padding(.horizontal, 16) }
            }
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .onAppear { if !model.hasLoaded { Task { await model.load() } } }
    }

    @ViewBuilder
    private func favoriteSection(_ title: String, items: [LibraryItem]) -> some View {
        if !items.isEmpty {
            Text(title).font(.system(size: 27, weight: .bold)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(items) { item in MediaPosterCard(item: item, client: client, width: 126) }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var favoritePeopleSection: some View {
        if !model.people.isEmpty {
            Text("演员").font(.system(size: 27, weight: .bold)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(model.people) { person in
                        VStack(spacing: 8) {
                            RemoteEmbyImage(url: client.imageURL(itemId: person.id, maxWidth: 300, tag: person.primaryImageTag), contentMode: .fill)
                                .frame(width: 104, height: 104)
                                .clipShape(Circle())
                            Text(person.name).lineLimit(1).frame(width: 110)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

@MainActor
private final class EmbyFavoritesViewModel: ObservableObject {
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
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do { items = try await client.favoriteItems() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct EmbySearchView: View {
    let session: EmbySession
    let client: EmbyAPIClient
    let onClose: () -> Void
    @StateObject private var model: EmbySearchViewModel
    @State private var searchText = ""
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(session: EmbySession, client: EmbyAPIClient, onClose: @escaping () -> Void) {
        self.session = session
        self.client = client
        self.onClose = onClose
        _model = StateObject(wrappedValue: EmbySearchViewModel(client: client))
    }

    var body: some View {
        VStack(spacing: 14) {
            pageHeader(title: "搜索", onClose: onClose)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索当前 Emby", text: $searchText, onCommit: { Task { await model.search(searchText) } })
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = ""; model.items = [] } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(model.items) { item in MediaPosterCard(item: item, client: client, width: nil) }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 30)
            }
            if model.isLoading { ProgressView().padding(.bottom, 10) }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }
}

@MainActor
private final class EmbySearchViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    private let client: EmbyAPIClient
    init(client: EmbyAPIClient) { self.client = client }

    func search(_ term: String) async {
        isLoading = true
        defer { isLoading = false }
        do { items = try await client.searchItems(term: term) }
        catch { items = [] }
    }
}

private struct EmbyServerSettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let session: EmbySession
    let client: EmbyAPIClient
    let onClose: () -> Void
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    pageHeader(title: "设置", onClose: onClose)
                    settingsCard {
                        serverSettingRow("服务器", value: session.serverName, systemImage: "externaldrive")
                        Divider().padding(.leading, 48)
                        serverSettingRow("用户", value: session.user.name, systemImage: "person")
                        Divider().padding(.leading, 48)
                        serverSettingRow("版本", value: session.serverVersion, systemImage: "info.circle")
                    }

                    settingsCard {
                        NavigationLink(destination: PlayerSettingsView()) {
                            serverSettingRow("播放设置", value: nil, systemImage: "playpause")
                        }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlaybackLabView()) {
                            serverSettingRow("播放器实验室", value: nil, systemImage: "wrench.and.screwdriver")
                        }
                    }

                    settingsCard {
                        Button {
                            do { shareURL = try DiagnosticsLogger.shared.export() } catch {}
                        } label: {
                            serverSettingRow("导出播放日志", value: nil, systemImage: "doc.text")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let shareURL { ActivityView(items: [shareURL]) }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func serverSettingRow(_ title: String, value: String?, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage).foregroundColor(.blue).frame(width: 28)
            Text(title).foregroundColor(.primary)
            Spacer()
            if let value { Text(value).foregroundColor(.secondary).lineLimit(1) }
            Image(systemName: "chevron.right").font(.caption).foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 62)
        .contentShape(Rectangle())
    }
}

private struct LibraryTile: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View {
        VStack(spacing: 8) {
            RemoteEmbyImage(url: client.imageURL(itemId: item.id, maxWidth: 520, tag: item.primaryImageTag), contentMode: .fill)
                .frame(width: 176, height: 100)
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 176)
        }
    }
}

private struct MediaLandscapeCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                RemoteEmbyImage(url: client.imageURL(itemId: item.id, imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop", maxWidth: 700, tag: item.backdropImageTags.first ?? item.primaryImageTag), contentMode: .fill)
                    .frame(width: 230, height: 132)
                    .clipped()
                if item.playbackProgress > 0 {
                    GeometryReader { proxy in
                        VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 4) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.name).font(.headline).lineLimit(1).frame(width: 230, alignment: .leading)
            Text(mediaSubtitle(item)).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
        }
    }
}

private struct MediaPosterCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    let width: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomLeading) {
                RemoteEmbyImage(url: client.imageURL(itemId: item.id, maxWidth: 480, tag: item.primaryImageTag), contentMode: .fill)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: width)
                    .clipped()
                if item.playbackProgress > 0 {
                    GeometryReader { proxy in
                        VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) }
                    }
                }
                if let count = item.userData?.unplayedItemCount, count > 0 {
                    VStack { HStack { Spacer(); Text("\(count)").font(.caption.weight(.bold)).foregroundColor(.white).padding(7).background(Color.blue).clipShape(Circle()) }; Spacer() }
                        .padding(6)
                } else if item.isPlayed {
                    VStack { HStack { Spacer(); Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundColor(.white).padding(7).background(Color.green).clipShape(Circle()) }; Spacer() }
                        .padding(6)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name).font(.system(size: 16)).lineLimit(1)
            if let year = item.productionYear { Text(String(year)).font(.subheadline).foregroundColor(.secondary) }
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct RemoteEmbyImage: View {
    let url: URL?
    let contentMode: ContentMode

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
            case .empty:
                ZStack { placeholder; ProgressView() }
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "play.rectangle")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
        }
    }
}

private func pageHeader(title: String, onClose: @escaping () -> Void) -> some View {
    HStack {
        Spacer().frame(width: 42)
        Spacer()
        Text(title).font(.system(size: 40, weight: .bold))
        Spacer()
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 42, height: 42)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Circle())
        }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
}

private func mediaSubtitle(_ item: LibraryItem) -> String {
    if let seriesName = item.seriesName, let season = item.parentIndexNumber, let episode = item.indexNumber {
        return "\(seriesName) · S\(season):E\(episode)"
    }
    if let year = item.productionYear { return String(year) }
    return item.type ?? ""
}
