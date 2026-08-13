import SwiftUI
import Combine

struct EmbyServerRootViewV3: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.presentationMode) private var presentationMode
    let session: EmbySession

    @State private var client: EmbyAPIClient?
    @State private var selectedTab: V3ServerTab = .home
    @State private var homeRefreshToken = 0
    @State private var homeScrollToTopToken = 0
    @State private var lastHomeTap = Date.distantPast

    var body: some View {
        Group {
            if let client {
                GeometryReader { geometry in
                    let fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom
                    ZStack {
                        V3EmbyHomeView(session: session, client: client, refreshToken: homeRefreshToken, scrollToTopToken: homeScrollToTopToken, onClose: close, dock: AnyView(serverTabBar))
                            .opacity(selectedTab == .home ? 1 : 0)
                            .allowsHitTesting(selectedTab == .home)
                            .accessibilityHidden(selectedTab != .home)

                        if selectedTab == .favorites { V3EmbyFavoritesView(client: client, onClose: close, dock: AnyView(serverTabBar)) }
                        if selectedTab == .search { V3EmbySearchView(client: client, onClose: close, dock: AnyView(serverTabBar)) }
                        if selectedTab == .settings { V3EmbyServerSettingsView(session: session, onClose: close, dock: AnyView(serverTabBar)) }
                    }
                    .environment(\.serverDockContent, AnyView(serverTabBar))
                    .environment(\.serverDockBottomInset, geometry.safeAreaInsets.bottom)
                    .frame(width: geometry.size.width, height: fullHeight, alignment: .top)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .background(Color(uiColor: .systemBackground).ignoresSafeArea())
                }
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
        .frame(height: 40)
        .background(Color(uiColor: .secondarySystemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func serverTabButton(_ tab: V3ServerTab, title: String, systemImage: String) -> some View {
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
            ZStack {
                Color.clear
                VStack(spacing: 0) {
                    Image(systemName: selectedTab == tab && tab != .search ? systemImage + ".fill" : systemImage).font(.system(size: 19))
                    Text(title).font(.system(size: 10))
                }
                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                .offset(y: 7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private func close() {
        sessionStore.leaveServer()
        presentationMode.wrappedValue.dismiss()
    }
}

private enum V3ServerTab { case home, favorites, search, settings }

private struct V3HomeLibraryPreference: Codable, Identifiable, Equatable {
    let libraryID: String
    var name: String
    var collectionType: String?
    var showOnHome: Bool
    var includeInCarousel: Bool
    var id: String { libraryID }
}

private struct V3EmbyHomeView: View {
    let session: EmbySession
    let client: EmbyAPIClient
    let refreshToken: Int
    let scrollToTopToken: Int
    let onClose: () -> Void
    let dock: AnyView
    @StateObject private var model: V3EmbyHomeViewModel
    @State private var isMediaManagementPresented = false
    @State private var carouselIndex = 0
    private let carouselTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    init(session: EmbySession, client: EmbyAPIClient, refreshToken: Int, scrollToTopToken: Int, onClose: @escaping () -> Void, dock: AnyView) {
        self.session = session
        self.client = client
        self.refreshToken = refreshToken
        self.scrollToTopToken = scrollToTopToken
        self.onClose = onClose
        self.dock = dock
        _model = StateObject(wrappedValue: V3EmbyHomeViewModel(session: session, client: client))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            Color.clear.frame(height: 1).id("v3-home-top")
                            if model.isLoading && model.libraries.isEmpty {
                                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                            } else {
                                if !model.carouselItems.isEmpty { heroCarousel }
                                if !model.visibleLibraries.isEmpty {
                                    sectionTitle("我的媒体")
                                    libraryRow
                                }
                                if !model.resumeItems.isEmpty {
                                    sectionTitle("继续观看")
                                    landscapeRow(model.resumeItems)
                                }
                                ForEach(model.visibleLibraries) { library in
                                    if let items = model.latestByLibrary[library.id], !items.isEmpty {
                                        HStack(spacing: 8) {
                                            sectionTitle(library.name)
                                            Spacer()
                                            NavigationLink("更多", destination: V3LibraryBrowserView(library: library, client: client, dock: dock))
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .padding(.trailing, 16)
                                        }
                                        posterRow(items)
                                    }
                                }
                                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 16) }
                            }
                        }
                        .padding(.bottom, 86)
                    }
                    .refreshable { await model.refresh(userInitiated: true) }
                    .onChange(of: refreshToken) { _ in Task { await model.refresh(userInitiated: true) } }
                    .onChange(of: scrollToTopToken) { _ in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("v3-home-top", anchor: .top) } }
                }
            }
            .navigationBarHidden(true)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .onAppear {
                Task {
                    if !model.hasLoaded { await model.refresh() }
                    else { await model.refreshResumeIfNeeded() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: EmbyUserDataChange.notification)) { notification in
                guard let source = notification.object as? EmbyAPIClient, source === client, let itemID = notification.userInfo?[EmbyUserDataChange.itemIDKey] as? String else { return }
                model.markResumeDirty(itemID)
            }
            .sheet(isPresented: $isMediaManagementPresented) {
                V3MediaManagementView(preferences: model.preferences) { model.savePreferences($0) }
            }
            .onReceive(carouselTimer) { _ in
                guard model.carouselItems.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.35)) { carouselIndex = (carouselIndex + 1) % model.carouselItems.count }
            }
            .onChange(of: model.carouselItems.count) { count in
                if count == 0 || carouselIndex >= count { carouselIndex = 0 }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Menu {
                Button { Task { await model.refresh(userInitiated: true) } } label: { Label("刷新首页", systemImage: "arrow.clockwise") }
                Button { isMediaManagementPresented = true } label: { Label("媒体管理", systemImage: "slider.horizontal.3") }
                Divider()
                Text("当前服务器：\(session.serverName)")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.green)
                    Text(session.serverName).font(.headline).foregroundColor(.primary).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Capsule())
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    .frame(width: 36, height: 36).background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 0)
        .padding(.bottom, 6)
    }

    private var heroCarousel: some View {
        VStack(spacing: 10) {
            TabView(selection: $carouselIndex) {
                ForEach(Array(model.carouselItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) {
                        V3HeroCard(item: item, client: client)
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 330)

            HStack(spacing: 7) {
                ForEach(model.carouselItems.indices, id: \.self) { index in
                    Capsule().fill(index == carouselIndex ? Color.primary : Color.secondary.opacity(0.35)).frame(width: index == carouselIndex ? 16 : 6, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: carouselIndex)
        }
        .padding(.horizontal, 16)
    }

    private func sectionTitle(_ title: String) -> some View { Text(title).font(.title2.weight(.bold)).padding(.horizontal, 16) }

    private var libraryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(model.visibleLibraries) { library in
                    NavigationLink(destination: V3LibraryBrowserView(library: library, client: client, dock: dock)) { V3LibraryTile(item: library, client: client) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func landscapeRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3LandscapeCard(item: item, client: client) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func posterRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3PosterCard(item: item, client: client, width: 118) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

@MainActor
private final class V3EmbyHomeViewModel: ObservableObject {
    @Published var libraries: [LibraryItem] = []
    @Published var resumeItems: [LibraryItem] = []
    @Published var latestByLibrary: [String: [LibraryItem]] = [:]
    @Published var preferences: [V3HomeLibraryPreference] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient
    private let preferenceKey: String
    private(set) var hasLoaded = false
    private var resumeDirty = false
    private var dirtyResumeItemIDs = Set<String>()

    init(session: EmbySession, client: EmbyAPIClient) {
        self.client = client
        preferenceKey = "osplayer.home.library-preferences.\(session.serverId).\(session.user.id)"
    }

    var orderedLibraries: [LibraryItem] {
        let byID = Dictionary(uniqueKeysWithValues: libraries.map { ($0.id, $0) })
        let ordered = preferences.compactMap { byID[$0.libraryID] }
        let known = Set(ordered.map(\.id))
        return ordered + libraries.filter { !known.contains($0.id) }
    }

    var visibleLibraries: [LibraryItem] {
        let visible = Dictionary(uniqueKeysWithValues: preferences.map { ($0.libraryID, $0.showOnHome) })
        return orderedLibraries.filter { visible[$0.id] ?? true }
    }

    var carouselItems: [LibraryItem] {
        let enabled = Set(preferences.filter(\.includeInCarousel).map(\.libraryID))
        var seen = Set<String>()
        var pool: [LibraryItem] = []
        for library in orderedLibraries where enabled.contains(library.id) {
            for item in latestByLibrary[library.id] ?? [] where seen.insert(item.id).inserted { pool.append(item) }
        }
        let backdrop = pool.filter { !$0.backdropImageTags.isEmpty }
        let fallback = pool.filter { $0.backdropImageTags.isEmpty }
        return Array((backdrop + fallback).prefix(6))
    }

    func markResumeDirty(_ itemID: String) {
        resumeDirty = true
        dirtyResumeItemIDs.insert(itemID)
        DiagnosticsLogger.shared.log("HomeRefresh", "resume dirty item=\(itemID)")
    }

    func refreshResumeIfNeeded() async {
        guard resumeDirty else { return }
        await refresh(userInitiated: true)
    }

    func refresh(userInitiated: Bool = false) async {
        if isLoading {
            guard userInitiated else { return }
            DiagnosticsLogger.shared.log("HomeRefresh", "user refresh waiting for active refresh")
            while isLoading { try? await Task.sleep(nanoseconds: 50_000_000) }
        }
        if userInitiated {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await refreshResumeOnly()
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            async let viewsRequest = client.userViews()
            async let resumeRequest = client.resumeItems(limit: 18)
            let (views, resume) = try await (viewsRequest, resumeRequest)
            libraries = uniqueItems(views)
            resumeItems = uniqueItems(resume).filter { ["movie", "episode"].contains($0.type?.lowercased() ?? "") }
            resumeDirty = false
            dirtyResumeItemIDs.removeAll()
            preferences = reconcilePreferences(libraries)
            persistPreferences(preferences)

            var latest: [String: [LibraryItem]] = [:]
            await withTaskGroup(of: (String, [LibraryItem]?).self) { group in
                for library in libraries {
                    let types = Self.browseItemTypes(for: library)
                    group.addTask {
                        do {
                            if types.isEmpty { return (library.id, try await self.client.latestItems(parentId: library.id, limit: 16)) }
                            let page = try await self.client.libraryItems(parentId: library.id, limit: 16, sortBy: "DateCreated", sortOrder: "Descending", includeItemTypes: types)
                            return (library.id, page.items)
                        } catch {
                            return (library.id, nil)
                        }
                    }
                }
                for await result in group { if let items = result.1 { latest[result.0] = uniqueItems(items) } }
            }
            latestByLibrary = latest
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }

    private func refreshResumeOnly() async {
        do {
            let resume = try await client.resumeItems(limit: 18)
            resumeItems = uniqueItems(resume).filter { ["movie", "episode"].contains($0.type?.lowercased() ?? "") }
            DiagnosticsLogger.shared.log("HomeRefresh", "resume refreshed count=\(resumeItems.count) dirty=\(resumeDirty) ids=\(dirtyResumeItemIDs.sorted().joined(separator: ","))")
            resumeDirty = false
            dirtyResumeItemIDs.removeAll()
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }

    private static func browseItemTypes(for library: LibraryItem) -> [String] {
        switch library.collectionType?.lowercased() {
        case "movies": return ["Movie"]
        case "tvshows": return ["Series"]
        case "homevideos": return ["Video"]
        case "mixed": return ["Movie", "Series", "Video"]
        default: return []
        }
    }

    private func uniqueItems(_ items: [LibraryItem]) -> [LibraryItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    func savePreferences(_ next: [V3HomeLibraryPreference]) {
        let validIDs = Set(libraries.map(\.id))
        preferences = next.filter { validIDs.contains($0.libraryID) }
        persistPreferences(preferences)
    }

    private func reconcilePreferences(_ views: [LibraryItem]) -> [V3HomeLibraryPreference] {
        let saved = loadPreferences()
        let byID = Dictionary(uniqueKeysWithValues: views.map { ($0.id, $0) })
        var next = saved.compactMap { preference -> V3HomeLibraryPreference? in
            guard let library = byID[preference.libraryID] else { return nil }
            var updated = preference
            updated.name = library.name
            updated.collectionType = library.collectionType
            return updated
        }
        let known = Set(next.map(\.libraryID))
        for library in views where !known.contains(library.id) {
            next.append(V3HomeLibraryPreference(libraryID: library.id, name: library.name, collectionType: library.collectionType, showOnHome: true, includeInCarousel: defaultCarouselEnabled(library)))
        }
        return next
    }

    private func defaultCarouselEnabled(_ library: LibraryItem) -> Bool {
        switch library.collectionType?.lowercased() {
        case "movies", "tvshows", "mixed", "homevideos": return true
        default: return false
        }
    }

    private func loadPreferences() -> [V3HomeLibraryPreference] {
        guard let data = UserDefaults.standard.data(forKey: preferenceKey), let value = try? JSONDecoder().decode([V3HomeLibraryPreference].self, from: data) else { return [] }
        return value
    }

    private func persistPreferences(_ value: [V3HomeLibraryPreference]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: preferenceKey)
    }
}

private struct V3MediaManagementView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var draft: [V3HomeLibraryPreference]
    let onSave: ([V3HomeLibraryPreference]) -> Void

    init(preferences: [V3HomeLibraryPreference], onSave: @escaping ([V3HomeLibraryPreference]) -> Void) {
        _draft = State(initialValue: preferences)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Button { presentationMode.wrappedValue.dismiss() } label: { Image(systemName: "xmark").font(.system(size: 22, weight: .medium)).frame(width: 44, height: 44) }
                    Spacer()
                    Text("媒体管理").font(.title2.weight(.bold))
                    Spacer()
                    Button("保存") { onSave(draft); presentationMode.wrappedValue.dismiss() }.font(.headline)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                Text("长按拖动可调整首页顺序").font(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 12)

                HStack {
                    Text("媒体库").font(.headline)
                    Spacer()
                    Text("展示").font(.headline).frame(width: 66)
                    Text("轮播图").font(.headline).frame(width: 72)
                    Spacer().frame(width: 34)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                List {
                    ForEach($draft) { $preference in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preference.name).font(.body).lineLimit(1)
                                if let type = preference.collectionType, !type.isEmpty { Text(v3CollectionTypeTitle(type)).font(.caption2).foregroundColor(.secondary) }
                            }
                            Spacer(minLength: 6)
                            Toggle("展示", isOn: $preference.showOnHome).labelsHidden().frame(width: 66)
                            Toggle("轮播图", isOn: $preference.includeInCarousel).labelsHidden().frame(width: 72)
                        }
                        .frame(minHeight: 50)
                    }
                    .onMove { source, destination in draft.move(fromOffsets: source, toOffset: destination) }
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.editMode, .constant(.active))
            }
            .navigationBarHidden(true)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct V3HeroCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            V3RemoteImage(url: client.imageURL(itemId: item.id, imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop", maxWidth: 1280, tag: item.backdropImageTags.first ?? item.primaryImageTag), contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            LinearGradient(colors: [Color.black.opacity(0.02), Color.black.opacity(0.18), Color.black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 9) {
                Text(heroTitle).font(.system(size: 30, weight: .bold)).foregroundColor(.white).lineLimit(2).shadow(radius: 2)
                HStack(spacing: 8) {
                    if let rating = item.communityRating { Text("★ " + String(format: "%.1f", rating)).foregroundColor(.yellow) }
                    if let year = item.productionYear { Text(String(year)) }
                    Text(v3MediaTypeTitle(item))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.95))
                if let overview = item.overview, !overview.isEmpty { Text(overview).font(.subheadline).foregroundColor(.white.opacity(0.88)).lineLimit(2) }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var heroTitle: String {
        if item.type?.caseInsensitiveCompare("Episode") == .orderedSame, let seriesName = item.seriesName, !seriesName.isEmpty { return seriesName }
        return item.name
    }
}

private struct V3LibraryBrowserView: View {
    let library: LibraryItem
    let client: EmbyAPIClient
    let dock: AnyView
    @StateObject private var model: V3LibraryBrowserViewModel

    init(library: LibraryItem, client: EmbyAPIClient, dock: AnyView) {
        self.library = library
        self.client = client
        self.dock = dock
        _model = StateObject(wrappedValue: V3LibraryBrowserViewModel(library: library, client: client))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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
                    } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 20)) }
                }
                .padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding)

                if model.isLoading && model.items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        EmbyPosterDetailLink(item: item, client: client) {
                            V3PosterCard(item: item, client: client, width: nil)
                        }
                    }
                }

                if model.isLoading && !model.items.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12) }
                if let error = model.errorMessage { Text(error).foregroundColor(.red).font(.footnote).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.bottom, 86)
        }
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .overlay(alignment: .bottom) { dock }
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.reload() } } }
    }

    private var contentTitle: String {
        switch library.collectionType?.lowercased() { case "tvshows": return "节目"; case "movies": return "电影"; default: return "内容" }
    }

    private func sortButton(_ title: String, key: String) -> some View {
        Button { Task { await model.changeSort(to: key) } } label: { if model.sortBy == key { Label(title, systemImage: "checkmark") } else { Text(title) } }
    }
}

@MainActor
private final class V3LibraryBrowserViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasMore = true
    @Published var sortBy = "DateCreated"
    private let library: LibraryItem
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private(set) var hasLoaded = false

    init(library: LibraryItem, client: EmbyAPIClient) { self.library = library; self.client = client }

    func reload() async {
        guard !isLoading else { return }
        items = []
        nextStartIndex = 0
        hasMore = true
        hasLoaded = false
        await fetchNextPage()
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isLoading else { return }
        await fetchNextPage()
    }

    func changeSort(to key: String) async {
        guard key != sortBy else { return }
        sortBy = key
        await reload()
    }

    private func fetchNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        let requestedStartIndex = nextStartIndex
        defer { isLoading = false; hasLoaded = true }
        do {
            let expectedTypes: [String]
            switch library.collectionType?.lowercased() {
            case "movies": expectedTypes = ["Movie"]
            case "tvshows": expectedTypes = ["Series"]
            case "homevideos": expectedTypes = ["Video"]
            case "mixed": expectedTypes = ["Movie", "Series", "Video"]
            default: expectedTypes = []
            }
            let page = try await client.libraryItems(parentId: library.id, limit: pageSize, startIndex: requestedStartIndex, sortBy: sortBy, includeItemTypes: expectedTypes)
            let allowed = Set(expectedTypes.map { $0.lowercased() })
            let filtered = page.items.filter { allowed.isEmpty || allowed.contains($0.type?.lowercased() ?? "") }
            var seen = Set(items.map(\.id))
            items.append(contentsOf: filtered.filter { seen.insert($0.id).inserted })
            nextStartIndex = requestedStartIndex + page.items.count
            if let totalRecordCount = page.totalRecordCount {
                hasMore = nextStartIndex < totalRecordCount
            } else {
                hasMore = page.items.count == pageSize
            }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}

private struct V3EmbyFavoritesView: View {
    let client: EmbyAPIClient
    let onClose: () -> Void
    let dock: AnyView
    @StateObject private var model: V3FavoritesViewModel

    init(client: EmbyAPIClient, onClose: @escaping () -> Void, dock: AnyView) {
        self.client = client
        self.onClose = onClose
        self.dock = dock
        _model = StateObject(wrappedValue: V3FavoritesViewModel(client: client))
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    V3PageHeader(title: "收藏", onClose: onClose)
                    favoriteSection("电影", items: model.movies)
                    favoriteSection("剧集", items: model.series)
                    favoritePeople
                    favoriteSection("合集", items: model.collections)
                    if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                    if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 16) }
                }
                .padding(.bottom, 86)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .refreshable { await model.load() }
            .onAppear { if !model.hasLoaded { Task { await model.load() } } }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func favoriteSection(_ title: String, items: [LibraryItem]) -> some View {
        if !items.isEmpty {
            Text(title).font(.title2.weight(.bold)).padding(.horizontal, 16)
            EmbyPosterGrid(items: items) { item in
                EmbyPosterDetailLink(item: item, client: client) {
                    V3PosterCard(item: item, client: client, width: nil)
                }
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
                            V3RemoteImage(url: client.imageURL(itemId: person.id, maxWidth: 260, tag: person.primaryImageTag), contentMode: .fill).frame(width: 92, height: 92).clipShape(Circle())
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
private final class V3FavoritesViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(client: EmbyAPIClient) { self.client = client }
    var movies: [LibraryItem] { items.filter { $0.type?.caseInsensitiveCompare("Movie") == .orderedSame } }
    var series: [LibraryItem] { items.filter { $0.type?.caseInsensitiveCompare("Series") == .orderedSame } }
    var people: [LibraryItem] { items.filter { $0.type?.caseInsensitiveCompare("Person") == .orderedSame } }
    var collections: [LibraryItem] { items.filter { ["boxset", "collectionfolder"].contains($0.type?.lowercased() ?? "") } }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do { items = try await client.favoriteItems() }
        catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }
}

private struct V3EmbySearchView: View {
    let client: EmbyAPIClient
    let onClose: () -> Void
    let dock: AnyView
    @StateObject private var model: V3SearchViewModel
    @State private var searchText = ""

    init(client: EmbyAPIClient, onClose: @escaping () -> Void, dock: AnyView) {
        self.client = client
        self.onClose = onClose
        self.dock = dock
        _model = StateObject(wrappedValue: V3SearchViewModel(client: client))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                V3PageHeader(title: "搜索", onClose: onClose)
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("搜索当前 Emby", text: $searchText, onCommit: { Task { await model.search(searchText) } }).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !searchText.isEmpty { Button { searchText = ""; model.items = [] } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) } }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    EmbyPosterGrid(items: model.items) { item in
                        EmbyPosterDetailLink(item: item, client: client) {
                            V3PosterCard(item: item, client: client, width: nil)
                        }
                    }
                    .padding(.bottom, 86)
                }
                if model.isLoading { ProgressView().padding(.bottom, 8) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

@MainActor
private final class V3SearchViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isLoading = false
    private let client: EmbyAPIClient
    init(client: EmbyAPIClient) { self.client = client }

    func search(_ term: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do { items = try await client.searchItems(term: term) }
        catch { if !isEmbyRequestCancellation(error) { items = [] } }
    }
}

private struct V3EmbyServerSettingsView: View {
    let session: EmbySession
    let onClose: () -> Void
    let dock: AnyView
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    V3PageHeader(title: "设置", onClose: onClose)
                    V3SettingsCard {
                        settingRow("服务器", value: session.serverName, systemImage: "externaldrive")
                        Divider().padding(.leading, 46)
                        settingRow("用户", value: session.user.name, systemImage: "person")
                        Divider().padding(.leading, 46)
                        settingRow("版本", value: session.serverVersion, systemImage: "info.circle")
                    }
                    V3SettingsCard {
                        NavigationLink(destination: PlayerSettingsView()) { settingRow("播放设置", value: nil, systemImage: "playpause") }
                        Divider().padding(.leading, 46)
                        NavigationLink(destination: PlaybackLabView()) { settingRow("播放器实验室", value: nil, systemImage: "wrench.and.screwdriver") }
                    }
                    V3SettingsCard {
                        Button { do { shareURL = try DiagnosticsLogger.shared.export() } catch {} } label: { settingRow("导出播放日志", value: nil, systemImage: "doc.text") }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 86)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ActivityView(items: [shareURL]) } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .ignoresSafeArea(.container, edges: .bottom)
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

private struct V3SettingsCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { VStack(spacing: 0) { content }.background(Color(uiColor: .secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous)) }
}

private struct V3PageHeader: View {
    let title: String
    let onClose: () -> Void
    var body: some View {
        HStack {
            Spacer().frame(width: 36)
            Spacer()
            Text(title).font(.title2.weight(.bold))
            Spacer()
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary).frame(width: 36, height: 36).background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle()) }
        }
        .padding(.horizontal, 16)
        .padding(.top, 5)
    }
}

private struct V3LibraryTile: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    var body: some View {
        VStack(spacing: 6) {
            V3RemoteImage(url: client.imageURL(itemId: item.id, maxWidth: 480, tag: item.primaryImageTag), contentMode: .fill).frame(width: 164, height: 92).clipped().clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name).font(.subheadline.weight(.medium)).foregroundColor(.primary).lineLimit(1).frame(width: 164)
        }
    }
}

private struct V3LandscapeCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomLeading) {
                V3RemoteImage(url: client.imageURL(itemId: item.id, imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop", maxWidth: 650, tag: item.backdropImageTags.first ?? item.primaryImageTag), contentMode: .fill).frame(width: 212, height: 120).clipped()
                if item.playbackProgress > 0 { GeometryReader { proxy in VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) } } }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(1).frame(width: 212, alignment: .leading)
            Text(v3MediaSubtitle(item)).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
    }
}

private struct V3PosterCard: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient
    let width: CGFloat?

    private var resolvedWidth: CGFloat { width ?? gridCellWidth ?? 118 }
    private var posterHeight: CGFloat { floor(resolvedWidth / EmbyPosterGridMetrics.posterAspectRatio) }
    private var yearText: String { item.productionYear.map(String.init) ?? " " }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                V3RemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: 440, tag: item.preferredPrimaryImageTag), contentMode: .fill)
                    .frame(width: resolvedWidth, height: posterHeight)
                    .clipped()
                if item.playbackProgress > 0 { GeometryReader { proxy in VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) } } }
                if let count = item.userData?.unplayedItemCount, count > 0 {
                    VStack { HStack { Spacer(); Text("\(count)").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.blue).clipShape(Circle()) }; Spacer() }.padding(5)
                } else if item.isPlayed {
                    VStack { HStack { Spacer(); Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.green).clipShape(Circle()) }; Spacer() }.padding(5)
                }
            }
            .frame(width: resolvedWidth, height: posterHeight)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).lineLimit(1).frame(width: resolvedWidth, height: 20, alignment: .leading)
                Text(yearText).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: resolvedWidth, height: 16, alignment: .leading).opacity(item.productionYear == nil ? 0 : 1)
            }
            .frame(width: resolvedWidth, height: 38, alignment: .topLeading)
        }
        .frame(width: resolvedWidth, alignment: .leading)
    }
}

private struct V3RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: "play.rectangle", showsLoadingIndicator: false) }
}

private func v3MediaSubtitle(_ item: LibraryItem) -> String {
    if let seriesName = item.seriesName, let season = item.parentIndexNumber, let episode = item.indexNumber { return "\(seriesName) · S\(season):E\(episode)" }
    if let year = item.productionYear { return String(year) }
    return item.type ?? ""
}

private func v3MediaTypeTitle(_ item: LibraryItem) -> String {
    switch item.type?.lowercased() {
    case "movie": return "电影"
    case "series": return "剧集"
    case "episode": return "剧集"
    case "video": return "视频"
    default: return item.type ?? ""
    }
}

private func v3CollectionTypeTitle(_ value: String) -> String {
    switch value.lowercased() {
    case "movies": return "电影"
    case "tvshows": return "电视剧"
    case "music": return "音乐"
    case "homevideos": return "家庭视频"
    case "mixed": return "混合内容"
    default: return value
    }
}
