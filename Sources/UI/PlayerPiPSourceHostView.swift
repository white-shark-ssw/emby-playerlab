import AVFoundation
import CoreImage
import UIKit

final class PlayerPiPSourceHostView: UIView {
    let displayLayer = AVSampleBufferDisplayLayer()
    private static let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let fallbackImageView = UIImageView()
    private let placeholderImageView = UIImageView(image: UIImage(systemName: "pip"))
    private(set) var hasFallbackFrame = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        clipsToBounds = true

        fallbackImageView.backgroundColor = .black
        fallbackImageView.contentMode = .scaleAspectFit
        fallbackImageView.isHidden = true
        fallbackImageView.layer.zPosition = 20
        addSubview(fallbackImageView)

        placeholderImageView.tintColor = UIColor.white.withAlphaComponent(0.55)
        placeholderImageView.contentMode = .scaleAspectFit
        placeholderImageView.layer.zPosition = 10
        addSubview(placeholderImageView)

        displayLayer.zPosition = 0
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func markVideoAvailable() { placeholderImageView.isHidden = true }

    func showFallbackFrame(from sampleBuffer: CMSampleBuffer?) {
        guard let sampleBuffer, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = Self.ciContext.createCGImage(image, from: image.extent) else { return }
        fallbackImageView.image = UIImage(cgImage: cgImage)
        fallbackImageView.isHidden = false
        placeholderImageView.isHidden = true
        hasFallbackFrame = true
    }

    func clearFallbackFrame() {
        fallbackImageView.image = nil
        fallbackImageView.isHidden = true
        hasFallbackFrame = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fallbackImageView.frame = bounds
        let iconSide = min(max(min(bounds.width, bounds.height) * 0.18, 56), 110)
        placeholderImageView.frame = CGRect(x: bounds.midX - iconSide * 0.5, y: bounds.midY - iconSide * 0.5, width: iconSide, height: iconSide)
        guard displayLayer.superlayer === layer else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); displayLayer.frame = bounds; displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale; CATransaction.commit()
    }
}
