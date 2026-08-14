import SwiftUI
import Combine

final class V3HomeHeroScrollState: ObservableObject {
    @Published private(set) var rawMinY: CGFloat = 0

    func update(_ value: CGFloat) {
        guard abs(rawMinY - value) > 0.10 else { return }
        rawMinY = value
    }
}

struct V3HomeHeroScrollScope<Content: View>: View {
    @ObservedObject var state: V3HomeHeroScrollState
    let content: () -> Content

    init(state: V3HomeHeroScrollState, @ViewBuilder content: @escaping () -> Content) {
        self.state = state
        self.content = content
    }

    var body: some View { content() }
}

extension V3EmbyHomeView {
    var homeRawScrollMinY: CGFloat { heroScrollState.rawMinY }
}
