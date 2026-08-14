import SwiftUI
import Combine
import UIKit

struct EmbyServerRootViewV3: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.presentationMode) private var presentationMode
    let session: EmbySession

    @State private var client: EmbyAPIClient?
    @State private var selectedTab: V3ServerTab = .home
    @State private var homeRefreshToken = 0
    @State private var homeScrollToTopToken = 0
    @State private var homeCarouselActive = false
    @State private var lastHomeTap = Date.distantPast

    var body: some View {
        Group {
            if let client {
                GeometryReader { geometry in
                    let dock = AnyView(serverTabBar)
                    ZStack {
                        V3EmbyHomeView(session: session, client: client, refreshToken: homeRefreshToken, scrollToTopToken: homeScrollToTopToken, onClose: close, onCarouselActiveChanged: { active in homeCarouselActive = active }, dock: dock)
                            .opacity(selectedTab == .home ? 1 : 0)
                            .allowsHitTesting(selectedTab == .home)
                            .accessibilityHidden(selectedTab != .home)

                        if selectedTab == .favorites { V3EmbyFavoritesView(client: client, onClose: close, dock: dock) }
                        if selectedTab == .search { V3EmbySearchView(client: client, onClose: close, dock: dock) }
                        if selectedTab == .settings { V3EmbyServerSettingsView(session: session, onClose: close, dock: dock) }
                    }
                    .environment(\.serverDockContent, dock)
                    .environment(\.serverDockBottomInset, geometry.safeAreaInsets.bottom)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
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
        .frame(height: ImmersiveUIMetrics.serverDockHeight)
        .background(
            Group {
                if selectedTab == .home && homeCarouselActive {
                    Rectangle().fill(.ultraThinMaterial)
                        .overlay(Color(uiColor: .systemBackground).opacity(0.10))
                        .overlay(alignment: .top) { Color.primary.opacity(0.08).frame(height: 0.5) }
                } else {
                    Color(uiColor: .secondarySystemBackground)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        )
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
        .frame(maxWidth: .infinity, minHeight: ImmersiveUIMetrics.serverDockHeight, maxHeight: ImmersiveUIMetrics.serverDockHeight)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private func close() {
        sessionStore.leaveServer()
        presentationMode.wrappedValue.dismiss()
    }
}

private enum V3ServerTab { case home, favorites, search, settings }
