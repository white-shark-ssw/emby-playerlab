from pathlib import Path

p = Path("Sources/UI/EmbyServerRootViewV3.swift")
s = p.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    s = s.replace(old, new, 1)


replace_once("import SwiftUI\nimport Combine\n", "import SwiftUI\nimport Combine\nimport UIKit\n", "UIKit import")
replace_once(
    "private struct V3EmbyHomeView: View {\n    let session: EmbySession\n",
    "private struct V3EmbyHomeView: View {\n    @Environment(\\.colorScheme) private var colorScheme\n    let session: EmbySession\n",
    "home color scheme",
)
replace_once(
    "    @StateObject private var model: V3EmbyHomeViewModel\n    @State private var isMediaManagementPresented = false\n    @State private var carouselIndex = 0\n",
    "    @StateObject private var model: V3EmbyHomeViewModel\n    @StateObject private var posterNavigationState = EmbyPosterGridNavigationState()\n    @State private var isMediaManagementPresented = false\n    @State private var carouselIndex = 0\n    @State private var homeRawScrollMinY: CGFloat = 0\n",
    "home state",
)
replace_once(
    '''                Group {
                    if immersive {
                        ZStack(alignment: .top) {
                            homeScroll(heroHeight: heroHeight)
                                .ignoresSafeArea(.container, edges: .top)
                            header(immersive: true)
                        }
                    } else {
                        VStack(spacing: 0) {
                            header(immersive: false)
                            homeScroll(heroHeight: heroHeight)
                        }
                    }
                }
''',
    '''                Group {
                    if immersive {
                        ZStack(alignment: .top) {
                            if let item = currentCarouselItem { homePersistentBackdrop(item: item).allowsHitTesting(false) }
                            homeScroll(heroHeight: heroHeight, immersive: true)
                                .background(Color.clear)
                                .ignoresSafeArea(.container, edges: .top)
                                .zIndex(1)
                            header(immersive: true)
                                .zIndex(30)
                        }
                    } else {
                        VStack(spacing: 0) {
                            header(immersive: false)
                            homeScroll(heroHeight: heroHeight, immersive: false)
                        }
                    }
                }
''',
    "immersive body",
)

start = s.index("    private func homeScroll(heroHeight: CGFloat) -> some View {")
end = s.index("\n    private func header(immersive: Bool) -> some View {", start)
home_scroll = '''    private func homeScroll(heroHeight: CGFloat, immersive: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Group {
                        if !model.carouselItems.isEmpty { heroCarousel(height: heroHeight) }
                        else { Color.clear.frame(height: 1) }
                    }
                    .id("v3-home-top")

                    if model.isLoading && model.libraries.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
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
                .background(
                    Group {
                        if immersive {
                            AdaptiveHeroNativeScrollObserver { value in
                                if abs(homeRawScrollMinY - value) > 0.10 { homeRawScrollMinY = value }
                            }
                        }
                    }
                )
                .background(Group { if immersive { V3HomeRefreshControlLayerBridge() } })
            }
            .background(Color.clear)
            .refreshable { await model.refresh(userInitiated: true) }
            .onChange(of: refreshToken) { _ in Task { await model.refresh(userInitiated: true) } }
            .onChange(of: scrollToTopToken) { _ in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("v3-home-top", anchor: .top) } }
        }
    }
'''
s = s[:start] + home_scroll + s[end:]

start = s.index("    private func heroCarousel(height: CGFloat) -> some View {")
end = s.index("\n    private func sectionTitle", start)
hero = '''    private func heroCarousel(height: CGFloat) -> some View {
        let stretch = max(0, homeRawScrollMinY)
        let upwardScroll = max(0, -homeRawScrollMinY)
        let resistanceSpan: CGFloat = 176
        let pinCompensation = min(upwardScroll, resistanceSpan)
        let visualHeight = height + stretch
        let heroOffset = stretch > 0 ? -stretch : pinCompensation

        return TabView(selection: $carouselIndex) {
            ForEach(Array(model.carouselItems.enumerated()), id: \.element.id) { index, item in
                NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) {
                    V3HeroCard(item: item, client: client)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: visualHeight)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 6) {
                ForEach(model.carouselItems.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == carouselIndex ? Color.white : Color.white.opacity(0.42))
                        .frame(width: index == carouselIndex ? 16 : 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(Color.black.opacity(0.22)))
            .padding(.trailing, 16)
            .padding(.bottom, 18)
            .animation(.easeInOut(duration: 0.2), value: carouselIndex)
        }
        .offset(y: heroOffset)
        .frame(height: height, alignment: .top)
        .allowsHitTesting(upwardScroll < 8)
        .zIndex(0)
    }

    private var currentCarouselItem: LibraryItem? {
        let items = model.carouselItems
        guard !items.isEmpty else { return nil }
        return items[min(max(0, carouselIndex), items.count - 1)]
    }

    private func homePersistentBackdrop(item: LibraryItem) -> some View {
        GeometryReader { proxy in
            ZStack {
                V3RemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: 1600, tag: item.preferredPrimaryImageTag), contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .scaleEffect(1.08)
                    .blur(radius: 30)
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.18 : 0.28),
                        Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.40 : 0.50),
                        Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.60 : 0.68)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
'''
s = s[:start] + hero + s[end:]

replace_once(
    '''    private func landscapeRow(_ items: [LibraryItem]) -> some View {
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
''',
    '''    private func landscapeRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    EmbyPosterDetailLink(item: item, client: client) { V3LandscapeCard(item: item, client: client) }
                        .frame(width: 212, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .environment(\.embyPosterGridNavigationState, posterNavigationState)
            .padding(.horizontal, 16)
        }
    }

    private func posterRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(items) { item in
                    EmbyPosterDetailLink(item: item, client: client) {
                        V3PosterCard(item: item, client: client, width: 118)
                            .contentShape(Rectangle())
                    }
                    .frame(width: 118, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
            .environment(\.embyPosterGridNavigationState, posterNavigationState)
            .padding(.horizontal, 16)
        }
    }
''',
    "horizontal media routing",
)
replace_once(
    '''        let backdrop = pool.filter { !$0.backdropImageTags.isEmpty }
        let fallback = pool.filter { $0.backdropImageTags.isEmpty }
        return Array((backdrop + fallback).prefix(6))
''',
    '''        return Array(pool.prefix(6))
''',
    "carousel ordering",
)
replace_once(
    '''                    Section {
                        ForEach($draft) { $preference in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preference.name).font(.body).lineLimit(1)
                                    if let type = preference.collectionType, !type.isEmpty { Text(v3CollectionTypeTitle(type)).font(.caption2).foregroundColor(.secondary) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(spacing: 3) {
                                    Text("首页").font(.caption2).foregroundColor(.secondary)
                                    Toggle("首页", isOn: $preference.showOnHome).labelsHidden().tint(.green)
                                }
                                .frame(width: 62)

                                VStack(spacing: 3) {
                                    Text("轮播").font(.caption2).foregroundColor(carouselEnabled ? .secondary : .secondary.opacity(0.55))
                                    Toggle("轮播", isOn: $preference.includeInCarousel).labelsHidden().tint(.green)
                                }
                                .frame(width: 62)
                                .opacity(carouselEnabled ? 1 : 0.55)
                            }
                            .frame(minHeight: 44)
                            .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 12))
                        }
                        .onMove { source, destination in draft.move(fromOffsets: source, toOffset: destination) }
                    }
''',
    '''                    Section {
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
''',
    "media management columns",
)

start = s.index("private struct V3HeroCard: View {")
end = s.index("\nprivate struct V3LibraryBrowserView: View {", start)
hero_card = '''private struct V3HeroCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                V3RemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: 1400, tag: item.preferredPrimaryImageTag), contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.26), location: 0.00),
                        .init(color: Color.black.opacity(0.04), location: 0.30),
                        .init(color: Color.black.opacity(0.18), location: 0.58),
                        .init(color: Color.black.opacity(0.64), location: 0.88),
                        .init(color: Color.black.opacity(0.10), location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.00),
                        .init(color: .black, location: 0.86),
                        .init(color: .black.opacity(0.72), location: 0.93),
                        .init(color: .clear, location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 9) {
                Text(heroTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(radius: 2)
                HStack(spacing: 8) {
                    if let rating = item.communityRating { Text("★ " + String(format: "%.1f", rating)).foregroundColor(.yellow) }
                    if let year = item.productionYear { Text(String(year)) }
                    Text(v3MediaTypeTitle(item))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 86)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
    }

    private var heroTitle: String {
        if item.type?.caseInsensitiveCompare("Episode") == .orderedSame, let seriesName = item.seriesName, !seriesName.isEmpty { return seriesName }
        return item.name
    }
}
'''
s = s[:start] + hero_card + s[end:]

marker = "private struct V3PageHeader: View {\n"
if marker not in s:
    raise SystemExit("refresh bridge marker missing")
bridge = '''private final class V3HomeRefreshControlProbeView: UIView {
    var hierarchyDidChange: ((UIView) -> Void)?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        hierarchyDidChange?(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        hierarchyDidChange?(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hierarchyDidChange?(self)
    }
}

private struct V3HomeRefreshControlLayerBridge: UIViewRepresentable {
    func makeUIView(context: Context) -> V3HomeRefreshControlProbeView {
        let view = V3HomeRefreshControlProbeView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { probe in elevateRefreshControl(from: probe) }
        DispatchQueue.main.async { [weak view] in if let view { elevateRefreshControl(from: view) } }
        return view
    }

    func updateUIView(_ uiView: V3HomeRefreshControlProbeView, context: Context) {
        DispatchQueue.main.async { [weak uiView] in if let uiView { elevateRefreshControl(from: uiView) } }
    }

    private func elevateRefreshControl(from probe: UIView) {
        var current: UIView? = probe
        while let view = current {
            if let scrollView = view as? UIScrollView {
                guard let refreshControl = scrollView.refreshControl else { return }
                refreshControl.tintColor = .label
                refreshControl.layer.zPosition = 1_000
                scrollView.bringSubviewToFront(refreshControl)
                return
            }
            current = view.superview
        }
    }
}

'''
s = s.replace(marker, bridge + marker, 1)
p.write_text(s)

Path("scripts/check_home_ui_polish.py").write_text('''from pathlib import Path

s = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()

assert 'header(immersive: true)\\n                                .padding(.top, geometry.safeAreaInsets.top)' not in s
assert 'V3MediaManagementView(preferences: model.preferences, carouselEnabled: model.carouselEnabled)' in s
assert '@Published var carouselEnabled: Bool' in s
assert 'guard carouselEnabled else { return [] }' in s
assert 'osplayer.home.carousel-enabled.' in s
assert 'UserDefaults.standard.set(carouselEnabled, forKey: carouselEnabledKey)' in s
assert 'Text("一键控制首页沉浸轮播，关闭不会清除下方媒体库选择")' in s
media = s[s.index('private struct V3MediaManagementView'):s.index('private struct V3HeroCard')]
assert 'if let type = preference.collectionType' not in media
assert media.count('Text("首页").font(.caption2).foregroundColor(.secondary)') == 1
assert media.count('Text("轮播").font(.caption2).foregroundColor(.secondary)') == 1
assert '} header: {' in media
assert 'Toggle("首页", isOn: $preference.showOnHome)' in media
assert 'Toggle("轮播", isOn: $preference.includeInCarousel)' in media
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Home UI polish checks passed")
''')

Path("scripts/check_home_immersive_carousel.py").write_text('''from pathlib import Path

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()

assert "@State private var homeCarouselActive = false" in v3
assert "onCarouselActiveChanged" in v3
assert "selectedTab == .home && homeCarouselActive" in v3
assert "Rectangle().fill(.ultraThinMaterial)" in v3
assert "homeScroll(heroHeight: heroHeight, immersive: true)" in v3
assert ".ignoresSafeArea(.container, edges: .top)" in v3
assert "header(immersive: true)" in v3
assert "header(immersive: true)\\n                                .padding(.top, geometry.safeAreaInsets.top)" not in v3
assert "private func homePersistentBackdrop(item: LibraryItem)" in v3
assert "AdaptiveHeroNativeScrollObserver" in v3
assert "let resistanceSpan: CGFloat = 176" in v3
assert ".allowsHitTesting(upwardScroll < 8)" in v3
assert "V3HomeRefreshControlLayerBridge" in v3 and "bringSubviewToFront(refreshControl)" in v3
assert 'item.preferredPrimaryImageItemId, maxWidth: 1400' in v3
hero = v3[v3.index('private struct V3HeroCard'):v3.index('private struct V3LibraryBrowserView')]
assert 'imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop"' not in hero
assert '.clipShape(RoundedRectangle(cornerRadius: 18' not in v3
assert "Capsule().fill(.ultraThinMaterial)" in v3
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Immersive home carousel checks passed")
''')

Path("scripts/check_home_horizontal_tap_routing.py").write_text(r'''from pathlib import Path

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
shared = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text()
project = Path("project.yml").read_text()

start = v3.index("    private func landscapeRow")
end = v3.index("\n}", v3.index("    private func posterRow", start))
rows = v3[start:end]
assert "EmbyPosterDetailLink(item: item, client: client)" in rows
assert rows.count(".environment(\\.embyPosterGridNavigationState, posterNavigationState)") == 2
assert '.frame(width: 118, alignment: .leading)' in rows
assert 'NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3PosterCard' not in rows
assert 'EmbyGridPosterNavigationLink' in shared
assert 'route=cell-link' in Path("Sources/UI/EmbyPosterGrid.swift").read_text()
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Home horizontal poster tap routing checks passed")
''')
