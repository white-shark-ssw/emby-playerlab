import SwiftUI
import Combine
import UIKit

struct EmbyServerRootViewV3: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.presentationMode) private var presentationMode
    let session: EmbySession
    let onClose: (() -> Void)?
    private let keepsCachedHomeOnRouteFailure: Bool

    @State private var client: EmbyAPIClient?
    @State private var homeClientGeneration = 0
    @State private var selectedTab: V3ServerTab = .home
    @State private var searchModel: V3GlobalSearchViewModel?
    @State private var homeRefreshToken = 0
    @State private var homeScrollToTopToken = 0
    @State private var homeCarouselActive = false
    @State private var lastHomeTap = Date.distantPast

    init(session: EmbySession, initialClient: EmbyAPIClient? = nil, onClose: (() -> Void)? = nil) {
        self.session = session
        self.onClose = onClose
        keepsCachedHomeOnRouteFailure = initialClient != nil
        _client = State(initialValue: initialClient)
    }

    var body: some View {
        Group {
            if let client {
                GeometryReader { geometry in
                    let fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom
                    ZStack {
                        V3EmbyHomeView(session: session, client: client, refreshToken: homeRefreshToken, scrollToTopToken: homeScrollToTopToken, onClose: close, onCarouselActiveChanged: { active in homeCarouselActive = active })
                            .id(homeClientGeneration)
                            .opacity(selectedTab == .home ? 1 : 0)
                            .allowsHitTesting(selectedTab == .home)
                            .accessibilityHidden(selectedTab != .home)

                        if selectedTab == .favorites { V3EmbyFavoritesView(client: client, onClose: close) }
                        if selectedTab == .search, let searchModel { V3EmbyGlobalSearchView(currentSession: session, currentClient: client, model: searchModel, onClose: close) }
                        if selectedTab == .settings { OnePlayerServerSettingsView(session: session, onClose: close) }
                    }
                    .environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: selectedTab, usesMaterialBackground: selectedTab == .home && homeCarouselActive, onSelect: selectTab))
                    .environment(\.serverDockBottomInset, geometry.safeAreaInsets.bottom)
                    .frame(width: geometry.size.width, height: fullHeight, alignment: .top)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .background(Color(uiColor: .systemBackground).ignoresSafeArea())
                }
                .ignoresSafeArea(.keyboard, edges: selectedTab == .search ? .bottom : [])
            } else {
                ProgressView("连接 \(session.serverName)…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await resolveClient() }
    }

    private func resolveClient() async {
        do {
            let resolved = try await sessionStore.clientForBestRoute(for: session)
            let routeChanged = client?.baseURL != resolved.baseURL
            client = resolved
            if routeChanged { homeClientGeneration += 1 }
        } catch {
            DiagnosticsLogger.shared.log("Session", "Route selection failed server=\(session.serverName): \(error.localizedDescription)")
            if !keepsCachedHomeOnRouteFailure { close() }
        }
    }

    private func selectTab(_ tab: V3ServerTab) {
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
            if selectedTab != tab {
                if selectedTab == .search { searchModel = nil }
                if tab == .search { searchModel = V3GlobalSearchViewModel() }
            }
            selectedTab = tab
            if tab == .home { lastHomeTap = Date() }
        }
    }

    private func close() {
        sessionStore.leaveServer()
        if let onClose { onClose() }
        else { presentationMode.wrappedValue.dismiss() }
    }
}
