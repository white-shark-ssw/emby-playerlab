import AVFoundation
import UIKit

final class PlayerPiPSourceHostView: UIView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func markVideoAvailable() {}

    override func layoutSubviews() {
        super.layoutSubviews()
        guard displayLayer.superlayer === layer else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); displayLayer.frame = bounds; displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale; CATransaction.commit()
    }
}
