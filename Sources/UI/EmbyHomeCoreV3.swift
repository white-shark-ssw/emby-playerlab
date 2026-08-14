import SwiftUI
import Combine
import UIKit

struct V3EmbyHomeView: View {
    @Environment(\.colorScheme) var colorScheme
    let session: EmbySession
    let client: EmbyAPIClient
    let refreshToken: Int
    let scrollToTopToken: Int
    let onClose: () -> Void
    let onCarouselActiveChanged: (Bool) -> Void
    let dock: AnyView
    @StateObject var model: V3EmbyHomeViewModel
    @State var isMediaManagementPresented = false
    @State var currentCarouselItemID: String?
    @State var transitionFromID: String?
    @State var transitionToID: String?
    @State var transitionProgress: CGFloat = 0
    @State var isCarouselDragging = false
    @State var carouselLastSettledAt = Date()
    @State var carouselLightForegroundByID: [String: Bool] = [:]
    @State var carouselSourceSizeByID: [String: CGSize] = [:]
    @State var homeRawScrollMinY: CGFloat = 0
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
        _model = StateObject(wrappedValue: V3EmbyHomeViewModel(session: session, client: client))
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let immersive = !model.carouselItems.isEmpty
                let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top
                ZStack(alignment: .top) {
                    if immersive { persistentCarouselBackdrop(size: CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom)) }
                    else { Color(uiColor: .systemBackground).ignoresSafeArea() }
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
                .overlay(alignment: .bottom) { dock }
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
                .sheet(isPresented: $isMediaManagementPresented) {
                    V3MediaManagementView(preferences: model.preferences, carouselEnabled: model.carouselEnabled) { preferences, carouselEnabled in
                        model.savePreferences(preferences, carouselEnabled: carouselEnabled)
                    }
                }
                .onReceive(carouselTimer) { _ in autoAdvanceCarouselIfNeeded() }
                .onChange(of: model.carouselItems.map(\.id)) { _ in synchronizeCarouselItems() }
                .onDisappear {
                    isHomeActive = false
                    isCarouselDragging = false
                    onCarouselActiveChanged(false)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func homeScroll(width: CGFloat, viewportHeight: CGFloat, immersive: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Group {
                        if immersive { immersiveCarouselHero(width: width, viewportHeight: viewportHeight) }
                        else { Color.clear.frame(height: 1) }
                    }
                    .id("v3-home-top")

                    VStack(alignment: .leading, spacing: 22) {
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
                                            .font(.subheadline).foregroundColor(.blue).padding(.trailing, 16)
                                    }
                                    posterRow(items)
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
                    V3HomeNativeScrollObserver(
                        isRefreshing: isHomeRefreshing,
                        onOffsetChanged: { value in
                            guard isHomeActive else { return }
                            if abs(homeRawScrollMinY - value) > 0.10 { homeRawScrollMinY = value }
                        },
                        onRefresh: { Task { await refreshHome() } }
                    )
                )
            }
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
                Button { isMediaManagementPresented = true } label: { Label("媒体管理", systemImage: "slider.horizontal.3") }
                Divider()
                Text("当前服务器：\(session.serverName)")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.green)
                    Text(session.serverName).font(.headline).foregroundColor(immersive ? .white : .primary).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundColor(immersive ? .white.opacity(0.78) : .secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
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
                    .frame(width: 36, height: 36)
                    .background(
                        Group {
                            if immersive { Circle().fill(.ultraThinMaterial).overlay(Circle().fill(Color.black.opacity(0.18))) }
                            else { Circle().fill(Color(uiColor: .secondarySystemBackground)) }
                        }
                    )
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 0)
        .padding(.bottom, 6)
    }

}
