import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0
    @State private var selectedSession: EmbySession?

    var body: some View {
        TabView(selection: $selection) {
            ServerListView { stored in
                DiagnosticsLogger.shared.log("NavigationRace", "event=open-server server=\(stored.serverName)")
                sessionStore.activate(stored)
                selectedSession = stored
            }
            .tabItem { Label("服务器", systemImage: "externaldrive.connected.to.line.below") }
            .tag(0)

            GlobalSettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(1)
        }
        .accentColor(.blue)
        .fullScreenCover(item: $selectedSession, onDismiss: {
            DiagnosticsLogger.shared.log("NavigationRace", "event=server-cover-dismissed")
            sessionStore.leaveServer()
        }) { stored in
            EmbyServerRootViewV3(session: stored)
                .environmentObject(sessionStore)
                .nativeInteractivePop()
        }
        .onChange(of: scenePhase) { phase in
            DiagnosticsLogger.shared.log("SceneLifecycle", "phase=\(scenePhaseName(phase)) serverOpen=\(selectedSession != nil) outerTab=\(selection)")
        }
    }

    private func scenePhaseName(_ phase: ScenePhase) -> String {
        switch phase {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}

struct GlobalSettingsView: View {
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("设置")
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 14)

                    settingsGroup {
                        NavigationLink(destination: AppearanceSettingsView()) { settingsRow("外观", systemImage: "paintpalette") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: GeneralSettingsView()) { settingsRow("通用", systemImage: "slider.horizontal.3") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlayerSettingsView()) { settingsRow("播放", systemImage: "playpause") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlaceholderSettingsView(title: "音频")) { settingsRow("音频", systemImage: "waveform") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlaceholderSettingsView(title: "字幕")) { settingsRow("字幕", systemImage: "captions.bubble") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: CacheSettingsView()) { settingsRow("缓存", systemImage: "externaldrive") }
                    }

                    settingsGroup {
                        Button {
                            do { shareURL = try DiagnosticsLogger.shared.export() } catch {}
                        } label: {
                            settingsRow("导出播放日志", systemImage: "doc.text")
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: AboutOnePlayerView()) { settingsRow("关于 OnePlayer", systemImage: "info.circle") }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let shareURL { ActivityView(items: [shareURL]) }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 26)
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(DetailPresentationSettingsKey.fullyImmersive) private var fullyImmersiveDetail = true

    var body: some View {
        Form {
            Section(header: Text("详情页")) {
                Toggle("详情页完全沉浸", isOn: $fullyImmersiveDetail)
                Text(fullyImmersiveDetail ? "开启后，详情页和完整选集页使用整屏可视、滚动和操作区域，并隐藏服务器 Dock。" : "关闭后，详情页和完整选集页保留服务器 Dock，方便直接切换首页、收藏、搜索和设置。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("通用")
    }
}

private struct PlaceholderSettingsView: View {
    let title: String

    var body: some View {
        List {
            Section {
                Text("该设置页已经进入 OnePlayer 的正式结构，具体选项会在对应功能实现时接入。")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(title)
    }
}

private struct AboutOnePlayerView: View {
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("\(AppIdentity.version) (\(buildNumber))")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("最低系统")
                    Spacer()
                    Text("iOS 15.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("关于 OnePlayer")
    }
}
