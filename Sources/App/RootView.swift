import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var startupResolved = false
    @State private var autoStartedSession: EmbySession?
    @State private var autoStartedClient: EmbyAPIClient?

    var body: some View {
        Group {
            if !startupResolved {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    ProgressView()
                }
            } else if let autoStartedSession {
                EmbyServerRootViewV3(session: autoStartedSession, initialClient: autoStartedClient, onClose: {
                    self.autoStartedSession = nil
                    self.autoStartedClient = nil
                })
                .environmentObject(sessionStore)
            } else {
                AppShellView()
            }
        }
        .onAppear {
            guard !startupResolved else { return }
            sessionStore.restore()
            V3SearchRecommendationPreloader.shared.start(sessions: sessionStore.sessions, sessionStore: sessionStore)
            if let stored = sessionStore.autoStartSession {
                sessionStore.activate(stored)
                autoStartedClient = try? sessionStore.client(for: stored)
                autoStartedSession = stored
            }
            startupResolved = true
        }
    }
}
