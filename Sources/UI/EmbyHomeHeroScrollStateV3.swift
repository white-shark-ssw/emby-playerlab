import UIKit

final class V3HomeHeroScrollState {
    private(set) var rawMinY: CGFloat = 0
    private weak var presentation: V3HomeCarouselPresentationBridge?

    init(presentation: V3HomeCarouselPresentationBridge? = nil) {
        self.presentation = presentation
    }

    func bind(presentation: V3HomeCarouselPresentationBridge) {
        self.presentation = presentation
        presentation.updateRawScrollMinY(rawMinY)
    }

    func update(_ value: CGFloat) {
        guard abs(rawMinY - value) > 0.01 else { return }
        rawMinY = value
        presentation?.updateRawScrollMinY(value)
    }
}
