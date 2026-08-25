import SwiftUI
import Combine
import UIKit

struct V3EmbyHomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.serverDockBottomInset) private var serverDockBottomInset
    let session: EmbySession
    let client: EmbyAPIClient
    let refreshToken: Int
    let scrollToTopToken: Int
    let onClose: () -> Void
    let onCarouselActiveChanged: (Bool) -> Void
    let dock: AnyView
    let carouselDisplayRangeKey: String
    @StateObject var model: V3EmbyHomeViewModel
    @State var isMediaManagementPresented = false
    @State var carouselDisplayRange: Double
    @State var currentCarouselItemID: String?
    @State var carouselTransitionState = V3HomeCarouselTransitionState()
    @State var carouselLastSettledAt = Date()
    @State var carouselLightForegroundByID: [String: Bool] = [:]
    @State var carouselSourceSizeByID: [String: CGSize] = [:]
    @State var carouselLogoByID: [String: EmbyImageInfo] = [:]
    @State var carouselLogoResolvedIDs = Set<String>()
    @State var carouselDetailItem: LibraryItem?
    @State var isCarouselDetailPresented = false
    @State var heroScrollState = V3HomeHeroScrollState()
    @State var isHomeRefreshing = false
    @State var isHomeActive = false
    private let carouselTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: EmbySession, client: EmbyAPIClient, refreshToken: Int, scrollToTopToken: Int, onClose: @escaping () -> Void, onCarouselActiveChanged: @escaping (Bool) -> Void, dock: AnyView) {
        self.session = session
        self.client = client
        self.refreshToken = refreshToken
        self.scrollToTopToken = scrollToTopToken
        self.onClose = onClose
        self.onCarouselActiveChanged = onCarouselActiveChanged
        self.dock = dock
        let rangeKey = "osplayer.home.carousel-display-range.\(session.serverId).\(session.user.id)"
        carouselDisplayRangeKey = rangeKey
        let savedRange = UserDefaults.standard.object(forKey: rangeKey) as? Double ?? 0.30
        _carouselDisplayRange = State(initialValue: min(1, max(0, savedRange)))
        let homeModel = V3EmbyHomeViewModel(session: session, client: client)
        _model = StateObject(wrappedValue: homeModel)
        _currentCarouselItemID = State(initialValue: homeModel.carouselItems.first?.id)
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let immersive = !model.carouselItems.isEmpty
                let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top
                ZStack(alignment: .top) {
                    if immersive {
                        V3HomeCarouselTransitionScope(state: carouselTransitionState) {
                            persistentCarouselBackdrop(size: CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom))
                        }
                    } else {
                        Color(uiColor: .systemBackground).ignoresSafeArea()
                    }
                    if immersive { carouselPreloadLayer }

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
                .overlay(alignment: .bottom) {
                    if immersive { dock.padding(.bottom, serverDockBottomInset) }
                    else { dock }
                }
                .onAppear {
                    isHomeActive = true
                    synchronizeCarouselItems()
                    carouselLastSettledAt = Date()
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
                    isCarouselDragging = false
                    carouselTransitionState.resetDragDiagnostics()
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
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func homeScroll(width: CGFloat, viewportHeight: CGFloat, immersive: Bool) -> some View {
        ScrollViewReader { proxy in
            let heroTrackingLimit = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + min(132, viewportHeight * 0.16) + 24
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Group {
                        if immersive {
                            V3HomeHeroScrollScope(state: heroScrollState) {
                                V3HomeCarouselTransitionScope(state: carouselTransitionState) {
                                    immersiveCarouselHero(width: width, viewportHeight: viewportHeight)
                                }
                                .overlay {
                                    V3HomeCarouselNativeDragCapture(
                                        onBegan: { beginNativeCarouselDrag() },
                                        onSample: { translation in handleNativeCarouselDrag(translation, width: width) }
                                    )
                                }
                            }
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                    .id("v3-home-top")

                    VStack(alignment: .leading, spacing: 24) {
                        if model.isLoading && model.libraries.isEmpty {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                        } else {
                            if !model.visibleLibraries.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionTitle("我的媒体")
                                    libraryRow
                                }
                            }
                            if !model.resumeItems.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionTitle("继续观看")
                                    landscapeRow(model.resumeItems)
                                }
                            }
                            ForEach(model.visibleLibraries) { library in
                                if let items = model.latestByLibrary[library.id], !items.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            sectionTitle(library.name)
                                            Spacer()
                                            NavigationLink("更多", destination: V3LibraryBrowserView(library: library, client: client, dock: dock))
                                                .font(.subheadline).foregroundColor(.blue).padding(.trailing, 16)
                                        }
                                        posterRow(items)
                                    }
                                }
                            }
                            if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 16) }
                        }
                    }
                    .padding(.top, immersive ? 2 : 18)
                    .padding(.bottom, 86)
                }
                .frame(width: width)
                .background(
                    ZStack {
                        V3HomeScrollOffsetObserver { value in
                            guard immersive, isHomeActive else { return }
                            let clampedValue = max(-heroTrackingLimit, value)
                            heroScrollState.update(clampedValue)
                        }
                        if immersive {
                            V3HomeOwnedRefreshControl { completion in
                                Task { await refreshHome(); completion() }
                            }
                        } else {
                            V3HomeRefreshControlStyler(immersive: false)
                        }
                    }
                )
            }
            .modifier(V3HomeRefreshModifier(immersive: immersive, action: refreshHome))
            .frame(width: width)
            .background(Color.clear)
            .onChange(of: refreshToken) { _ in Task { await refreshHome() } }
            .onChange(of: scrollToTopToken) { _ in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("v3-home-top", anchor: .top) } }
        }
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
