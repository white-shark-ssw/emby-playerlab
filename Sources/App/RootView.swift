import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var startupResolved = false
    @State private var autoStartedSession: EmbySession?

    var body: some View {
        Group {
            if !startupResolved {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    ProgressView()
                }
            } else if let autoStartedSession {
                EmbyServerRootViewV3(session: autoStartedSession, onClose: {
                    sessionStore.leaveServer()
                    self.autoStartedSession = nil
                })
                .environmentObject(sessionStore)
            } else {
                AppShellView()
            }
        }
        .onAppear {
            guard !startupResolved else { return }
            sessionStore.restore()
            if let stored = sessionStore.autoStartSession {
                sessionStore.activate(stored)
                autoStartedSession = stored
            }
            startupResolved = true
        }
    }
}
