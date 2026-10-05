import SwiftUI
import Combine

final class V3HomeCarouselProgressState: ObservableObject {
    @Published var value: CGFloat = 0
}

struct V3HomeCarouselProgressOpacity<Content: View>: View {
    @ObservedObject var progress: V3HomeCarouselProgressState
    let resolveOpacity: (CGFloat) -> Double
    let content: Content

    init(progress: V3HomeCarouselProgressState, resolveOpacity: @escaping (CGFloat) -> Double, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.resolveOpacity = resolveOpacity
        self.content = content()
    }

    var body: some View { content.opacity(resolveOpacity(progress.value)) }
}

struct V3HomeCarouselProgressOffsetX<Content: View>: View {
    @ObservedObject var progress: V3HomeCarouselProgressState
    let resolveOffsetX: (CGFloat) -> CGFloat
    let content: Content

    init(progress: V3HomeCarouselProgressState, resolveOffsetX: @escaping (CGFloat) -> CGFloat, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.resolveOffsetX = resolveOffsetX
        self.content = content()
    }

    var body: some View { content.offset(x: resolveOffsetX(progress.value)) }
}

struct V3HomeCarouselProgressReadScope<Content: View>: View {
    @ObservedObject var progress: V3HomeCarouselProgressState
    let content: (CGFloat) -> Content

    init(progress: V3HomeCarouselProgressState, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.progress = progress
        self.content = content
    }

    var body: some View { content(progress.value) }
}
