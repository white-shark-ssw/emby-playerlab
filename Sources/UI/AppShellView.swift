import SwiftUI

struct AppShellView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ServerListView()
                .tabItem { Label("服务器", systemImage: "externaldrive.connected.to.line.below") }
                .tag(0)

            GlobalSettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(1)
        }
        .accentColor(.blue)
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
                        NavigationLink(destination: PlaceholderSettingsView(title: "通用")) { settingsRow("通用", systemImage: "slider.horizontal.3") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlayerSettingsView()) { settingsRow("播放", systemImage: "playpause") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlaceholderSettingsView(title: "音频")) { settingsRow("音频", systemImage: "waveform") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlaceholderSettingsView(title: "字幕")) { settingsRow("字幕", systemImage: "captions.bubble") }
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: PlaceholderSettingsView(title: "缓存")) { settingsRow("缓存", systemImage: "externaldrive") }
                    }

                    settingsGroup {
                        Button {
                            do { shareURL = try DiagnosticsLogger.shared.export() } catch {}
                        } label: {
                            settingsRow("导出播放日志", systemImage: "doc.text")
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 48)
                        NavigationLink(destination: AboutOSPlayerView()) { settingsRow("关于 OS player", systemImage: "info.circle") }
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

private struct PlaceholderSettingsView: View {
    let title: String

    var body: some View {
        List {
            Section {
                Text("该设置页已经进入 OS player 的正式结构，具体选项会在对应功能实现时接入。")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(title)
    }
}

private struct AboutOSPlayerView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("\(AppIdentity.version) (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
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
        .navigationTitle("关于 OS player")
    }
}
