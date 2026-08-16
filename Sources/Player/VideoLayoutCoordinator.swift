import CoreGraphics
import Foundation

/// Engine-agnostic video presentation contract.
///
/// Player UI supplies only the viewport, source display aspect ratio and user-selected mode.
/// The coordinator returns one deterministic layout plan. Renderer submission, refresh and
/// acknowledgement are owned by RendererLayoutCoordinator so engines do not own orientation policy.
struct VideoLayoutPlan: Equatable {
    enum ContentMode: String {
        case aspectFit
        case aspectFill
        case stretch
    }

    let viewport: CGSize
    let surfaceFrame: CGRect
    let contentMode: ContentMode
    let sourceAspectRatio: Double?
    let aspectOverride: Double?

    var mpvPanscan: Double { contentMode == .aspectFill ? 1 : 0 }

    var mpvAspectOverride: String? {
        guard let aspectOverride, aspectOverride > 0 else { return nil }
        if abs(aspectOverride - (16.0 / 9.0)) < 0.001 { return "16:9" }
        if abs(aspectOverride - (4.0 / 3.0)) < 0.001 { return "4:3" }
        return String(format: "%.6f", aspectOverride)
    }
}

struct VideoLayoutCoordinator {
    func makePlan(viewport: CGSize, sourceAspectRatio: Double?, mode: PlayerVideoScaleMode) -> VideoLayoutPlan {
        let safeViewport = CGSize(width: max(0, viewport.width), height: max(0, viewport.height))
        let fullFrame = CGRect(origin: .zero, size: safeViewport)

        switch mode {
        case .fit, .source:
            return VideoLayoutPlan(viewport: safeViewport, surfaceFrame: fullFrame, contentMode: .aspectFit, sourceAspectRatio: sourceAspectRatio, aspectOverride: nil)
        case .fill:
            return VideoLayoutPlan(viewport: safeViewport, surfaceFrame: fullFrame, contentMode: .aspectFill, sourceAspectRatio: sourceAspectRatio, aspectOverride: nil)
        case .ratio16x9:
            return fixedAspectPlan(viewport: safeViewport, ratio: 16.0 / 9.0, sourceAspectRatio: sourceAspectRatio)
        case .ratio4x3:
            return fixedAspectPlan(viewport: safeViewport, ratio: 4.0 / 3.0, sourceAspectRatio: sourceAspectRatio)
        }
    }

    private func fixedAspectPlan(viewport: CGSize, ratio: Double, sourceAspectRatio: Double?) -> VideoLayoutPlan {
        guard viewport.width > 0, viewport.height > 0, ratio > 0 else {
            return VideoLayoutPlan(viewport: viewport, surfaceFrame: CGRect(origin: .zero, size: viewport), contentMode: .stretch, sourceAspectRatio: sourceAspectRatio, aspectOverride: ratio)
        }

        let targetRatio = CGFloat(ratio)
        let size: CGSize
        if viewport.width / viewport.height > targetRatio {
            size = CGSize(width: viewport.height * targetRatio, height: viewport.height)
        } else {
            size = CGSize(width: viewport.width, height: viewport.width / targetRatio)
        }
        let origin = CGPoint(x: (viewport.width - size.width) / 2, y: (viewport.height - size.height) / 2)
        return VideoLayoutPlan(viewport: viewport, surfaceFrame: CGRect(origin: origin, size: size), contentMode: .stretch, sourceAspectRatio: sourceAspectRatio, aspectOverride: ratio)
    }
}
