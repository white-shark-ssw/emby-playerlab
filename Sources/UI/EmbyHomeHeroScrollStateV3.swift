import SwiftUI
import Combine
import UIKit

final class V3HomeHeroScrollState: ObservableObject {
    @Published private(set) var rawMinY: CGFloat = 0
    private weak var verticalScrollView: UIScrollView?

    func update(_ value: CGFloat) {
        guard abs(rawMinY - value) > 0.10 else { return }
        rawMinY = value
    }

    func attachVerticalScrollView(_ scrollView: UIScrollView?) { verticalScrollView = scrollView }

    var isVerticalMotionActive: Bool {
        guard let verticalScrollView else { return false }
        return verticalScrollView.isDragging || verticalScrollView.isDecelerating
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
