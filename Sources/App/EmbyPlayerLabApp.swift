import SwiftUI

@main
struct EmbyPlayerLabApp: App {
    @StateObject private var sessionStore = SessionStore()
    @AppStorage(AppAppearanceSettings.interfaceStyleKey) private var interfaceStyleRaw = AppInterfaceStyle.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
                .preferredColorScheme(AppInterfaceStyle(rawValue: interfaceStyleRaw)?.colorScheme)
        }
    }
}
