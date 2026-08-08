import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        AppShellView()
            .onAppear { sessionStore.restore() }
    }
}
