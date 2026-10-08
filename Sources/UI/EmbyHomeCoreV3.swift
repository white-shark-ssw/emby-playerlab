import SwiftUI
import Combine
import UIKit

struct V3EmbyHomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.serverDockBottomInset) var dockBottomInset
    let session: EmbySession
    let client: EmbyAPIClient
    let refreshToken: Int
    let scrollToTopToken: Int
    let onClose: () -> Void
    let onCarouselActiveChanged: (Bool) -> Void
    let carouselDisplayRangeKey: String
    @StateObject var model: V3EmbyHomeViewModel
    @State var isMediaManagementPresented = false
    @State var carouselDisplayRange: Double
    @State var carouselRuntimeState: V3HomeCarouselRuntimeState
    @State var carouselPresentationBridge: V3HomeCarouselPresentationBridge
    @State var carouselPresentationItems: [V3HomeCarouselPresentationItem] = []
    @State var carouselLogoByID: [String: EmbyImageInfo] = [:]
    @State var carouselLogoResolvedIDs = Set<String>()
    @State var carouselDetailItem: LibraryItem?
    @State var isCarouselDetailPresented = false
    @State var heroScrollState: V3HomeHeroScrollState
    @State var isHomeRefreshing = false
    @State var isHomeActive = false
    @State var posterDetailItem: LibraryItem?
    @State var posterLibrary: LibraryItem?
    private let carouselTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: EmbySession, client: EmbyAPIClient, refreshToken: Int, scrollToTopToken: Int, onClose: @escaping () -> Void, onCarouselActiveChanged: @escaping (Bool) -> Void) {
        self.session = session
        self.client = client
        self.refreshToken = refreshToken
        self.scrollToTopToken = scrollToTopToken
        self.onClose = onClose
        self.onCarouselActiveChanged = onCarouselActiveChanged
        let rangeKey = "osplayer.home.carousel-display-range.\(session.serverId).\(session.user.id)"
        carouselDisplayRangeKey = rangeKey
        let savedRange = UserDefaults.standard.object(forKey: rangeKey) as? Double ?? 0.30
        _carouselDisplayRange = State(initialValue: min(1, max(0, savedRange)))
        let homeModel = V3EmbyHomeViewModel(session: session, client: client)
        _model = StateObject(wrappedValue: homeModel)
        let bridge = V3HomeCarouselPresentationBridge()
        _carouselPresentationBridge = State(initialValue: bridge)
        _carouselRuntimeState = State(initialValue: V3HomeCarouselRuntimeState(currentID: homeModel.carouselItems.first?.id))
        _heroScrollState = State(initialValue: V3HomeHeroScrollState(presentation: bridge))
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let immersive = !model.carouselItems.isEmpty
                let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top
                let nativeSurfaceHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                ZStack(alignment: .top) {
                    if immersive {
                        // Keep Build286's layout extent; the native top overscan is render-only.
                        Color.clear.frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom)
                            .overlay(alignment: .top) {
                                V3HomeCarouselNativeSurface(bridge: carouselPresentationBridge, width: geometry.size.width, viewportHeight: viewportHeight, surfaceHeight: nativeSurfaceHeight, displayRange: carouselDisplayRange)
                                    .frame(width: geometry.size.width, height: nativeSurfaceHeight)
                                    .offset(y: -geometry.safeAreaInsets.top)
                                    .allowsHitTesting(false)
                            }
                    } else {
                        Color(uiColor: .systemBackground).ignoresSafeArea()
                    }

                    if immersive { V3HomeCarouselResourcePreparationView(items: carouselPresentationItems, bridge: carouselPresentationBridge) }

                    if immersive {
                        homeScroll(width: geometry.size.width, viewportHeight: viewportHeight, immersive: true)
                            .background(Color.clear)
                            .ignoresSafeArea(.container, edges: .top)
                            .zIndex(1)
                        header(immersive: true).zIndex(30)
                    } else {
                        VStack(spacing: 0) {
                            header(immersive: false)
                            homeScroll(width: geometry.size.width, viewportHeight: viewportHeight, immersive: false)
                        }
                        .zIndex(1)
                    }
                }
                .background(Color(uiColor: .systemBackground).ignoresSafeArea())
                .onAppear {
                    isHomeActive = true
                    carouselRuntimeState.bind(presentation: carouselPresentationBridge)
                    heroScrollState.bind(presentation: carouselPresentationBridge)
                    synchronizeCarouselItems()
                    carouselRuntimeState.lastSettledAt = Date()
                    onCarouselActiveChanged(immersive)
                    Task {
                        if !model.hasLoaded { await model.refresh() }
                        else { await model.refreshResumeIfNeeded() }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: EmbyUserDataChange.notification)) { notification in
                    guard let source = notification.object as? EmbyAPIClient, source === client, let itemID = notification.userInfo?[EmbyUserDataChange.itemIDKey] as? String else { return }
                    model.markResumeDirty(itemID)
                }
                .onReceive(carouselTimer) { _ in autoAdvanceCarouselIfNeeded() }
                .onChange(of: model.carouselItems.map(\.id)) { _ in synchronizeCarouselItems() }
                .onDisappear {
                    isHomeActive = false
                    carouselRuntimeState.deactivate()
                    onCarouselActiveChanged(false)
                }
                .overlay(alignment: .center) {
                    if isMediaManagementPresented {
                        V3MediaManagementOverlayView(
                            preferences: model.preferences,
                            carouselEnabled: model.carouselEnabled,
                            carouselDisplayRange: $carouselDisplayRange,
                            onClose: { withAnimation(.easeOut(duration: 0.16)) { isMediaManagementPresented = false } },
                            onPreferencesChanged: { preferences, carouselEnabled in model.savePreferences(preferences, carouselEnabled: carouselEnabled) },
                            onRangeCommit: { value in UserDefaults.standard.set(min(1, max(0, value)), forKey: carouselDisplayRangeKey) }
                        )
                        .transition(.opacity)
                        .zIndex(100)
                    }
                }
            }
            .serverDockPage()
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func homeScroll(width: CGFloat, viewportHeight: CGFloat, immersive: Bool) -> some View {
        let heroTrackingLimit = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + min(132, viewportHeight * 0.16) + 24
        let heroHeight = immersive ? AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + V3HomeCarouselNativeLayout.displayHeightAdjustment(displayRange: carouselDisplayRange, viewportHeight: viewportHeight) : 1
        return EmbyPosterSections(sections: homePosterSections, queryIdentity: "home|\(session.serverId)|\(session.user.id)", topHeight: heroHeight, topPadding: immersive ? 2 : 18, sectionGap: 24, bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), isLoading: model.isLoading && model.libraries.isEmpty, error: model.errorMessage, isActive: isHomeActive && posterDetailItem == nil && posterLibrary == nil && !isCarouselDetailPresented, scrollToTopToken: scrollToTopToken, onRefresh: immersive ? nil : { Task { await refreshHome() } }, onHomeOffset: { value in
            guard immersive, isHomeActive else { return }
            heroScrollState.update(max(-heroTrackingLimit, value))
        }, onHomeRefresh: immersive ? { completion in Task { await refreshHome(); completion() } } : nil, top: Group {
            if immersive { immersiveCarouselHero(width: width, viewportHeight: viewportHeight) }
            else { Color.clear.frame(height: 1) }
        })
        .frame(width: width)
        .background(Color.clear)
        .background(homePosterNavigation)
        .onChange(of: refreshToken) { _ in Task { await refreshHome() } }
    }

    private var homePosterSections: [EmbyPosterSection] {
        var sections: [EmbyPosterSection] = []
        if !model.visibleLibraries.isEmpty {
            sections.append(EmbyPosterSection(id: "libraries", title: "我的媒体", items: model.visibleLibraries, client: client, style: .library, titleGap: 8, onSelect: { posterLibrary = $0 }))
        }
        if !model.resumeItems.isEmpty {
            sections.append(EmbyPosterSection(id: "resume", title: "继续观看", items: model.resumeItems, client: client, style: .landscape, titleGap: 8, onSelect: { posterDetailItem = $0 }))
        }
        for library in model.visibleLibraries {
            if let items = model.latestByLibrary[library.id], !items.isEmpty {
                sections.append(EmbyPosterSection(id: "latest|\(library.id)", title: library.name, items: items, client: client, titleGap: 8, onMore: { posterLibrary = library }, onSelect: { posterDetailItem = $0 }))
            }
        }
        return sections
    }

    private var homePosterNavigation: some View {
        ZStack {
            NavigationLink(isActive: Binding(get: { posterLibrary != nil }, set: { if !$0 { posterLibrary = nil } })) {
                if let library = posterLibrary { V3LibraryBrowserView(library: library, client: client) }
                else { EmptyView() }
            } label: { EmptyView() }
            NavigationLink(isActive: Binding(get: { posterDetailItem != nil }, set: { if !$0 { posterDetailItem = nil } })) {
                if let item = posterDetailItem { EmbyPosterDetailDestination(item: item, client: client) }
                else { EmptyView() }
            } label: { EmptyView() }
        }
        .frame(width: 0, height: 0).hidden().allowsHitTesting(false)
    }

    @MainActor
    private func refreshHome() async {
        guard !isHomeRefreshing else { return }
        isHomeRefreshing = true
        await model.refresh(userInitiated: true)
        isHomeRefreshing = false
    }

    private func header(immersive: Bool) -> some View {
        HStack(spacing: 12) {
            Menu {
                Button { Task { await refreshHome() } } label: { Label("刷新首页", systemImage: "arrow.clockwise") }
                Button { withAnimation(.easeOut(duration: 0.16)) { isMediaManagementPresented = true } } label: { Label("媒体管理", systemImage: "slider.horizontal.3") }
                Divider()
                Text("当前服务器：\(session.serverName)")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.green)
                    Text(session.serverName).font(.headline).foregroundColor(immersive ? .white : .primary).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundColor(immersive ? .white.opacity(0.78) : .secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: V3ServerHeaderMetrics.controlHeight)
                .background(
                    Group {
                        if immersive { Capsule().fill(.ultraThinMaterial).overlay(Capsule().fill(Color.black.opacity(0.18))) }
                        else { Capsule().fill(Color(uiColor: .secondarySystemBackground)) }
                    }
                )
                .clipShape(Capsule())
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(immersive ? .white : .primary)
                    .frame(width: V3ServerHeaderMetrics.closeButtonSize, height: V3ServerHeaderMetrics.closeButtonSize)
                    .background(
                        Group {
                            if immersive { Circle().fill(.ultraThinMaterial).overlay(Circle().fill(Color.black.opacity(0.18))) }
                            else { Circle().fill(Color(uiColor: .secondarySystemBackground)) }
                        }
                    )
                    .clipShape(Circle())
            }
        }
        .frame(height: V3ServerHeaderMetrics.controlHeight)
        .padding(.horizontal, V3ServerHeaderMetrics.horizontalPadding)
        .padding(.bottom, V3ServerHeaderMetrics.bottomPadding)
    }
}

private struct V3HomeRefreshModifier: ViewModifier {
    let immersive: Bool
    let action: @MainActor () async -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if immersive { content }
        else { content.refreshable { await action() } }
    }
}
