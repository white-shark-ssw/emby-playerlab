import SwiftUI
import UIKit

struct DockMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { let view = UIView(); view.accessibilityIdentifier = "dock-probe"; return view }
    func updateUIView(_ view: UIView, context: Context) {}
}

final class V3GlobalSearchViewModel {}

struct LayoutServerProbe: View {
    let accepted: Bool
    let immersive: Bool

    var body: some View {
        GeometryReader { geometry in
            let fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom
            ZStack {
                if accepted { AcceptedHomeProbe(immersive: immersive, serverDockBottomInset: geometry.safeAreaInsets.bottom) }
                else { CurrentHomeProbe(immersive: immersive, serverDockBottomInset: geometry.safeAreaInsets.bottom) }
            }
            .environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: .home, usesMaterialBackground: immersive, onSelect: { _ in }))
            .environment(\.serverDockBottomInset, geometry.safeAreaInsets.bottom)
            .frame(width: geometry.size.width, height: fullHeight, alignment: .top)
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

struct HostProbe: View {
    let oversized: Bool
    let navigationBar: Bool

    var body: some View {
        GeometryReader { root in
            NavigationView {
                ServerDockHost(bottomInset: root.safeAreaInsets.bottom, dock: DockMarker().frame(height: ServerDockMetrics.height)) {
                    Color.clear.frame(width: 430, height: oversized ? 1600 : 200)
                }
                .navigationTitle("资料库")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarHidden(!navigationBar)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

struct KeyboardProbe: View {
    @State private var text = ""
    var body: some View {
        GeometryReader { root in
            NavigationView {
                VStack {
                    TextField("搜索", text: $text)
                    Spacer()
                }
                .serverDockPage()
                .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: .search, usesMaterialBackground: false, onSelect: { _ in }))
            .environment(\.serverDockBottomInset, root.safeAreaInsets.bottom)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

final class NavigationProbeModel: ObservableObject {
    @Published var isActive = false
}

struct NavigationProbe: View {
    @ObservedObject var model: NavigationProbeModel
    var body: some View {
        GeometryReader { root in
            NavigationView {
                VStack {
                    NavigationLink(isActive: $model.isActive) {
                        Color.clear.serverDockPage(isVisible: false).navigationTitle("沉浸详情")
                    } label: { Text("进入详情") }
                    Spacer()
                }
                .serverDockPage()
                .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .environment(\.serverDockConfiguration, ServerDockConfiguration(selectedTab: .home, usesMaterialBackground: false, onSelect: { _ in }))
            .environment(\.serverDockBottomInset, root.safeAreaInsets.bottom)
        }
    }
}
