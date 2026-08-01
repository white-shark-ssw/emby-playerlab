import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.session == nil {
                LoginView()
            } else {
                PlaybackLabView()
            }
        }
        .onAppear {
            sessionStore.restore()
        }
    }
}
