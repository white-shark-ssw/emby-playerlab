import SwiftUI

enum V3ServerTab: CaseIterable, Hashable {
    case home, favorites, search, settings

    var title: String {
        switch self {
        case .home: return "首页"
        case .favorites: return "收藏"
        case .search: return "搜索"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .favorites: return "heart"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}

enum ServerDockMetrics {
    static let height: CGFloat = 40
    static let contentGap: CGFloat = 12
    static func contentBottomPadding(bottomInset: CGFloat) -> CGFloat { height + bottomInset + contentGap }
}

struct ServerDockConfiguration {
    let selectedTab: V3ServerTab
    let usesMaterialBackground: Bool
    let onSelect: (V3ServerTab) -> Void
}

private struct ServerDockConfigurationKey: EnvironmentKey {
    static let defaultValue: ServerDockConfiguration? = nil
}

private struct ServerDockBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var serverDockConfiguration: ServerDockConfiguration? {
        get { self[ServerDockConfigurationKey.self] }
        set { self[ServerDockConfigurationKey.self] = newValue }
    }

    var serverDockBottomInset: CGFloat {
        get { self[ServerDockBottomInsetKey.self] }
        set { self[ServerDockBottomInsetKey.self] = newValue }
    }
}

struct ServerDockBar: View {
    let configuration: ServerDockConfiguration

    var body: some View {
        HStack(spacing: 0) {
            ForEach(V3ServerTab.allCases, id: \.self) { tab in
                Button { configuration.onSelect(tab) } label: {
                    ZStack {
                        Color.clear
                        VStack(spacing: 0) {
                            Image(systemName: configuration.selectedTab == tab && tab != .search ? tab.systemImage + ".fill" : tab.systemImage).font(.system(size: 19))
                            Text(tab.title).font(.system(size: 10))
                        }
                        .foregroundColor(configuration.selectedTab == tab ? .blue : .secondary)
                        .offset(y: 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, minHeight: ServerDockMetrics.height, maxHeight: ServerDockMetrics.height)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .frame(height: ServerDockMetrics.height)
        .background(
            Group {
                if configuration.usesMaterialBackground {
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
}

/// The viewport owns Dock placement. Oversized page backgrounds may render beyond it without moving the bar.
struct ServerDockHost<Content: View, Dock: View>: View {
    let bottomInset: CGFloat
    let dock: Dock
    let content: Content

    init(bottomInset: CGFloat, dock: Dock, @ViewBuilder content: () -> Content) {
        self.bottomInset = bottomInset
        self.dock = dock
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .overlay(alignment: .bottom) { dock.padding(.bottom, bottomInset) }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct ServerDockPageModifier: ViewModifier {
    @Environment(\.serverDockConfiguration) private var configuration
    @Environment(\.serverDockBottomInset) private var bottomInset
    let isVisible: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if isVisible, let configuration {
            ServerDockHost(bottomInset: bottomInset, dock: ServerDockBar(configuration: configuration)) { content }
        } else {
            content
        }
    }
}

private struct ServerDockContentPaddingModifier: ViewModifier {
    @Environment(\.serverDockBottomInset) private var bottomInset

    func body(content: Content) -> some View { content.padding(.bottom, ServerDockMetrics.contentBottomPadding(bottomInset: bottomInset)) }
}

extension View {
    func serverDockPage(isVisible: Bool = true) -> some View { modifier(ServerDockPageModifier(isVisible: isVisible)) }
    func serverDockContentPadding() -> some View { modifier(ServerDockContentPaddingModifier()) }
}
