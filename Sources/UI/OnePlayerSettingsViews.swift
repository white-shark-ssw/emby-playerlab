import SwiftUI
import UIKit

enum AppAppearanceSettings {
    static let interfaceStyleKey = "OnePlayer.Appearance.InterfaceStyle"
}

enum AppInterfaceStyle: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(AppAppearanceSettings.interfaceStyleKey) private var interfaceStyleRaw = AppInterfaceStyle.system.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("通用")
                appearanceCard {
                    HStack(spacing: 14) {
                        Image(systemName: "paintpalette.fill").foregroundColor(.blue).frame(width: 28)
                        Text("界面风格")
                        Spacer()
                        Picker("界面风格", selection: $interfaceStyleRaw) {
                            ForEach(AppInterfaceStyle.allCases) { style in Text(style.title).tag(style.rawValue) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 15)
                    .frame(minHeight: 56)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("外观设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.subheadline).foregroundColor(.secondary).padding(.horizontal, 4)
    }

    @ViewBuilder
    private func appearanceCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct OnePlayerServerSettingsView: View {
    let session: EmbySession
    let onClose: () -> Void
    let dock: AnyView
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    V3PageHeader(title: "设置", onClose: onClose).padding(.horizontal, -16)
                    settingsCard {
                        settingsRow("服务器", value: session.serverName, systemImage: "externaldrive", showsChevron: false)
                        Divider().padding(.leading, 46)
                        settingsRow("用户", value: session.user.name, systemImage: "person", showsChevron: false)
                        Divider().padding(.leading, 46)
                        settingsRow("版本", value: session.serverVersion, systemImage: "info.circle", showsChevron: false)
                    }
                    settingsCard {
                        NavigationLink(destination: AppearanceSettingsView()) { settingsRow("外观设置", value: nil, systemImage: "paintpalette", showsChevron: true) }
                        Divider().padding(.leading, 46)
                        NavigationLink(destination: PlayerSettingsView()) { settingsRow("播放设置", value: nil, systemImage: "playpause", showsChevron: true) }
                        Divider().padding(.leading, 46)
                        NavigationLink(destination: CacheSettingsView()) { settingsRow("缓存管理", value: nil, systemImage: "externaldrive", showsChevron: true) }
                        Divider().padding(.leading, 46)
                        NavigationLink(destination: PlaybackLabView()) { settingsRow("播放器实验室", value: nil, systemImage: "wrench.and.screwdriver", showsChevron: true) }
                    }
                    settingsCard {
                        Button { do { shareURL = try DiagnosticsLogger.shared.export() } catch {} } label: { settingsRow("导出播放日志", value: nil, systemImage: "doc.text", showsChevron: false) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 86)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ActivityView(items: [shareURL]) } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func settingsRow(_ title: String, value: String?, systemImage: String, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundColor(.blue).frame(width: 26)
            Text(title).foregroundColor(.primary)
            Spacer()
            if let value { Text(value).foregroundColor(.secondary).lineLimit(1) }
            if showsChevron { Image(systemName: "chevron.right").font(.caption2).foregroundColor(Color(uiColor: .tertiaryLabel)) }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}
