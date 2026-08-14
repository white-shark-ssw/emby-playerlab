import SwiftUI
import Combine
import UIKit

struct V3HomeLibraryPreference: Codable, Identifiable, Equatable {
    let libraryID: String
    var name: String
    var collectionType: String?
    var primaryImageTag: String? = nil
    var showOnHome: Bool
    var includeInCarousel: Bool
    var id: String { libraryID }
}

@MainActor
final class V3EmbyHomeViewModel: ObservableObject {
    @Published var libraries: [LibraryItem] = []
    @Published var resumeItems: [LibraryItem] = []
    @Published var latestByLibrary: [String: [LibraryItem]] = [:]
    @Published var preferences: [V3HomeLibraryPreference] = []
    @Published var carouselEnabled: Bool
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient
    private let preferenceKey: String
    private let carouselEnabledKey: String
    private let carouselSnapshotKey: String
    private let latestSnapshotKey: String
    private let librariesSnapshotKey: String
    private let resumeSnapshotKey: String
    private var cachedCarouselItems: [LibraryItem]
    private var hasResolvedLiveCarouselMetadata = false
    private(set) var hasLoaded = false
    private var resumeDirty = false
    private var dirtyResumeItemIDs = Set<String>()

    init(session: EmbySession, client: EmbyAPIClient) {
        self.client = client
        preferenceKey = "osplayer.home.library-preferences.\(session.serverId).\(session.user.id)"
        let carouselKey = "osplayer.home.carousel-enabled.\(session.serverId).\(session.user.id)"
        carouselEnabledKey = carouselKey
        let snapshotKey = "osplayer.home.carousel-snapshot.v1.\(session.serverId).\(session.user.id)"
        carouselSnapshotKey = snapshotKey
        let latestKey = "osplayer.home.latest-snapshot.v1.\(session.serverId).\(session.user.id)"
        latestSnapshotKey = latestKey
        let librariesKey = "osplayer.home.libraries-snapshot.v1.\(session.serverId).\(session.user.id)"
        librariesSnapshotKey = librariesKey
        let resumeKey = "osplayer.home.resume-snapshot.v1.\(session.serverId).\(session.user.id)"
        resumeSnapshotKey = resumeKey
        latestByLibrary = Self.loadLatestSnapshot(forKey: latestKey)
        cachedCarouselItems = Self.loadCarouselSnapshot(forKey: snapshotKey)
        let savedCarouselEnabled = UserDefaults.standard.object(forKey: carouselKey) as? Bool ?? true
        carouselEnabled = savedCarouselEnabled
        if savedCarouselEnabled {
            let savedPreferences = Self.loadPreferences(forKey: preferenceKey)
            preferences = savedPreferences
            let savedLibraries = Self.loadItemSnapshot(forKey: librariesKey)
            libraries = savedLibraries.isEmpty ? savedPreferences.compactMap(Self.libraryItem(from:)) : savedLibraries
            resumeItems = Self.loadItemSnapshot(forKey: resumeKey)
        }
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
        guard carouselEnabled else { return [] }
        let live = liveCarouselItems()
        if hasResolvedLiveCarouselMetadata || !live.isEmpty { return live }
        return cachedCarouselItems
    }

    private func liveCarouselItems() -> [LibraryItem] {
        let enabled = Set(preferences.filter(\.includeInCarousel).map(\.libraryID))
        var seen = Set<String>()
        var pool: [LibraryItem] = []
        for library in orderedLibraries where enabled.contains(library.id) {
            for item in latestByLibrary[library.id] ?? [] where seen.insert(item.id).inserted { pool.append(item) }
        }
        return Array(pool.prefix(6))
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
            persistItemSnapshot(libraries, forKey: librariesSnapshotKey)
            persistItemSnapshot(resumeItems, forKey: resumeSnapshotKey)
            resumeDirty = false
            dirtyResumeItemIDs.removeAll()
            preferences = reconcilePreferences(libraries)
            persistPreferences(preferences)

            var latest: [String: [LibraryItem]] = [:]
            var publishedFirstCarouselLibrary = false
            let carouselLibraryIDs = Set(preferences.filter(\.includeInCarousel).map(\.libraryID))
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
                for await result in group {
                    guard let items = result.1 else { continue }
                    let unique = uniqueItems(items)
                    latest[result.0] = unique
                    if cachedCarouselItems.isEmpty, !publishedFirstCarouselLibrary, carouselLibraryIDs.contains(result.0), !unique.isEmpty {
                        latestByLibrary = latest
                        publishedFirstCarouselLibrary = true
                    }
                }
            }
            latestByLibrary = latest
            let freshCarouselItems = liveCarouselItems()
            hasResolvedLiveCarouselMetadata = !freshCarouselItems.isEmpty || latest.count == libraries.count
            if latest.count == libraries.count {
                cachedCarouselItems = freshCarouselItems
                persistCarouselSnapshot(freshCarouselItems)
                persistLatestSnapshot(latest)
            }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }

    private func refreshResumeOnly() async {
        do {
            let resume = try await client.resumeItems(limit: 18)
            resumeItems = uniqueItems(resume).filter { ["movie", "episode"].contains($0.type?.lowercased() ?? "") }
            persistItemSnapshot(resumeItems, forKey: resumeSnapshotKey)
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

    func savePreferences(_ next: [V3HomeLibraryPreference], carouselEnabled: Bool) {
        let validIDs = Set(libraries.map(\.id))
        preferences = next.filter { validIDs.contains($0.libraryID) }
        self.carouselEnabled = carouselEnabled
        persistPreferences(preferences)
        UserDefaults.standard.set(carouselEnabled, forKey: carouselEnabledKey)
        if !carouselEnabled || !preferences.contains(where: \.includeInCarousel) {
            cachedCarouselItems = []
            persistCarouselSnapshot([])
        }
    }

    private func reconcilePreferences(_ views: [LibraryItem]) -> [V3HomeLibraryPreference] {
        let saved = loadPreferences()
        let byID = Dictionary(uniqueKeysWithValues: views.map { ($0.id, $0) })
        var next = saved.compactMap { preference -> V3HomeLibraryPreference? in
            guard let library = byID[preference.libraryID] else { return nil }
            var updated = preference
            updated.name = library.name
            updated.collectionType = library.collectionType
            updated.primaryImageTag = library.primaryImageTag
            return updated
        }
        let known = Set(next.map(\.libraryID))
        for library in views where !known.contains(library.id) {
            next.append(V3HomeLibraryPreference(libraryID: library.id, name: library.name, collectionType: library.collectionType, primaryImageTag: library.primaryImageTag, showOnHome: true, includeInCarousel: defaultCarouselEnabled(library)))
        }
        return next
    }

    private func defaultCarouselEnabled(_ library: LibraryItem) -> Bool {
        switch library.collectionType?.lowercased() {
        case "movies", "tvshows", "mixed", "homevideos": return true
        default: return false
        }
    }

    private func loadPreferences() -> [V3HomeLibraryPreference] { Self.loadPreferences(forKey: preferenceKey) }

    private static func loadPreferences(forKey key: String) -> [V3HomeLibraryPreference] {
        guard let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode([V3HomeLibraryPreference].self, from: data) else { return [] }
        return value
    }

    private func persistPreferences(_ value: [V3HomeLibraryPreference]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: preferenceKey)
    }

    private func persistItemSnapshot(_ items: [LibraryItem], forKey key: String) {
        let snapshot = items.map(V3HomeItemSnapshot.init)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadItemSnapshot(forKey key: String) -> [LibraryItem] {
        guard let data = UserDefaults.standard.data(forKey: key), let snapshot = try? JSONDecoder().decode([V3HomeItemSnapshot].self, from: data) else { return [] }
        return snapshot.compactMap(\.libraryItem)
    }

    private static func libraryItem(from preference: V3HomeLibraryPreference) -> LibraryItem? {
        var payload: [String: Any] = ["Id": preference.libraryID, "Name": preference.name, "Type": "CollectionFolder"]
        if let collectionType = preference.collectionType { payload["CollectionType"] = collectionType }
        if let primaryImageTag = preference.primaryImageTag { payload["ImageTags"] = ["Primary": primaryImageTag] }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return try? JSONDecoder().decode(LibraryItem.self, from: data)
    }

    private func persistLatestSnapshot(_ latest: [String: [LibraryItem]]) {
        let snapshot = latest.mapValues { Array($0.prefix(16)).map(V3HomeItemSnapshot.init) }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: latestSnapshotKey)
    }

    private static func loadLatestSnapshot(forKey key: String) -> [String: [LibraryItem]] {
        guard let data = UserDefaults.standard.data(forKey: key), let snapshot = try? JSONDecoder().decode([String: [V3HomeItemSnapshot]].self, from: data) else { return [:] }
        return snapshot.mapValues { $0.compactMap(\.libraryItem) }.filter { !$0.value.isEmpty }
    }

    private func persistCarouselSnapshot(_ items: [LibraryItem]) {
        let snapshot = items.map(V3HomeItemSnapshot.init)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: carouselSnapshotKey)
    }

    private static func loadCarouselSnapshot(forKey key: String) -> [LibraryItem] {
        guard let data = UserDefaults.standard.data(forKey: key), let snapshot = try? JSONDecoder().decode([V3HomeItemSnapshot].self, from: data) else { return [] }
        return snapshot.compactMap(\.libraryItem)
    }
}

private struct V3HomeItemSnapshot: Codable {
    let id: String
    let name: String
    let type: String?
    let overview: String?
    let productionYear: Int?
    let runTimeTicks: Int64?
    let communityRating: Double?
    let officialRating: String?
    let seriesName: String?
    let seriesId: String?
    let primaryImageTag: String?
    let primaryImageItemId: String?
    let seriesPrimaryImageTag: String?
    let collectionType: String?
    let playbackPositionTicks: Int64?
    let played: Bool?
    let unplayedItemCount: Int?

    init(_ item: LibraryItem) {
        id = item.id
        name = item.name
        type = item.type
        overview = item.overview
        productionYear = item.productionYear
        runTimeTicks = item.runTimeTicks
        communityRating = item.communityRating
        officialRating = item.officialRating
        seriesName = item.seriesName
        seriesId = item.seriesId
        primaryImageTag = item.primaryImageTag
        primaryImageItemId = item.primaryImageItemId
        seriesPrimaryImageTag = item.seriesPrimaryImageTag
        collectionType = item.collectionType
        playbackPositionTicks = item.userData?.playbackPositionTicks
        played = item.userData?.played
        unplayedItemCount = item.userData?.unplayedItemCount
    }

    var libraryItem: LibraryItem? {
        var payload: [String: Any] = ["Id": id, "Name": name]
        if let type { payload["Type"] = type }
        if let overview { payload["Overview"] = overview }
        if let productionYear { payload["ProductionYear"] = productionYear }
        if let runTimeTicks { payload["RunTimeTicks"] = runTimeTicks }
        if let communityRating { payload["CommunityRating"] = communityRating }
        if let officialRating { payload["OfficialRating"] = officialRating }
        if let seriesName { payload["SeriesName"] = seriesName }
        if let seriesId { payload["SeriesId"] = seriesId }
        if let primaryImageTag { payload["ImageTags"] = ["Primary": primaryImageTag] }
        if let primaryImageItemId { payload["PrimaryImageItemId"] = primaryImageItemId }
        if let seriesPrimaryImageTag { payload["SeriesPrimaryImageTag"] = seriesPrimaryImageTag }
        if let collectionType { payload["CollectionType"] = collectionType }
        if playbackPositionTicks != nil || played != nil || unplayedItemCount != nil {
            var userData: [String: Any] = [:]
            if let playbackPositionTicks { userData["PlaybackPositionTicks"] = playbackPositionTicks }
            if let played { userData["Played"] = played }
            if let unplayedItemCount { userData["UnplayedItemCount"] = unplayedItemCount }
            payload["UserData"] = userData
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return try? JSONDecoder().decode(LibraryItem.self, from: data)
    }
}

struct V3MediaManagementView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var draft: [V3HomeLibraryPreference]
    @State private var carouselEnabled: Bool
    let onSave: ([V3HomeLibraryPreference], Bool) -> Void

    init(preferences: [V3HomeLibraryPreference], carouselEnabled: Bool, onSave: @escaping ([V3HomeLibraryPreference], Bool) -> Void) {
        _draft = State(initialValue: preferences)
        _carouselEnabled = State(initialValue: carouselEnabled)
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
                    Button("保存") { onSave(draft, carouselEnabled); presentationMode.wrappedValue.dismiss() }.font(.headline)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                Text("长按拖动可调整首页顺序").font(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 8)

                List {
                    Section {
                        Toggle(isOn: $carouselEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("轮播图").font(.body.weight(.semibold))
                                Text("一键控制首页沉浸轮播，关闭不会清除下方媒体库选择").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .tint(.green)
                        .padding(.vertical, 3)
                    }

                    Section {
                        ForEach($draft) { $preference in
                            HStack(spacing: 12) {
                                Text(preference.name)
                                    .font(.body)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Toggle("首页", isOn: $preference.showOnHome)
                                    .labelsHidden()
                                    .tint(.green)
                                    .frame(width: 62)

                                Toggle("轮播", isOn: $preference.includeInCarousel)
                                    .labelsHidden()
                                    .tint(.green)
                                    .frame(width: 62)
                                    .opacity(carouselEnabled ? 1 : 0.55)
                            }
                            .frame(minHeight: 44)
                            .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 12))
                        }
                        .onMove { source, destination in draft.move(fromOffsets: source, toOffset: destination) }
                    } header: {
                        HStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Text("首页").font(.caption2).foregroundColor(.secondary).frame(width: 62)
                            Text("轮播").font(.caption2).foregroundColor(.secondary).frame(width: 62)
                            Spacer().frame(width: 30)
                        }
                        .textCase(nil)
                    }
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

struct V3HeroCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    let usesLightForeground: Bool

    private var primaryForeground: Color { usesLightForeground ? .white : .black }
    private var secondaryForeground: Color { usesLightForeground ? .white.opacity(0.90) : .black.opacity(0.80) }
    private var foregroundShadow: Color { usesLightForeground ? .black.opacity(0.52) : .white.opacity(0.24) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()
            Text(heroTitle)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(primaryForeground)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: foregroundShadow, radius: 3, y: 1)

            HStack(spacing: 8) {
                if let rating = item.communityRating { Text("★ " + String(format: "%.1f", rating)).foregroundColor(.yellow) }
                if let year = item.productionYear { Text(String(year)) }
                if let official = item.officialRating, !official.isEmpty { Text(official) }
                Text(v3MediaTypeTitle(item))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(secondaryForeground)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let overview = item.overview, !overview.isEmpty {
                Text(overview)
                    .font(.subheadline)
                    .foregroundColor(secondaryForeground)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(color: foregroundShadow, radius: 2, y: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, 20)
        .padding(.bottom, 58)
        .contentShape(Rectangle())
    }

    private var heroTitle: String {
        if item.type?.caseInsensitiveCompare("Episode") == .orderedSame, let seriesName = item.seriesName, !seriesName.isEmpty { return seriesName }
        return item.name
    }
}
