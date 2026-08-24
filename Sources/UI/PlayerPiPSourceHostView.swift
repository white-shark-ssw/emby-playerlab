import AVFoundation
import UIKit

final class PlayerPiPSourceHostView: UIView {
    let displayLayer = AVSampleBufferDisplayLayer()
    private let placeholderImageView = UIImageView(image: UIImage(systemName: "pip"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        clipsToBounds = true
        placeholderImageView.tintColor = UIColor.white.withAlphaComponent(0.55)
        placeholderImageView.contentMode = .scaleAspectFit
        addSubview(placeholderImageView)
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let iconSide = min(max(min(bounds.width, bounds.height) * 0.18, 56), 110)
        placeholderImageView.frame = CGRect(x: bounds.midX - iconSide * 0.5, y: bounds.midY - iconSide * 0.5, width: iconSide, height: iconSide)
        guard displayLayer.superlayer === layer else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); displayLayer.frame = bounds; displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale; CATransaction.commit()
    }
}
