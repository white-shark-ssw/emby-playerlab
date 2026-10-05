import SwiftUI
import UIKit

// Only unrelated delivery/diagnostic services are stubbed; native geometry, bridge and runtime are real source.
struct EmbyCachedRemoteImage: View {
    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String = "photo", showsLoadingIndicator: Bool = true, onImageLoaded: ((UIImage) -> Void)? = nil) {}
    var body: some View { Color.clear }
}
enum EmbyImageContrastAnalyzer { static func prefersLightForeground(for image: UIImage) -> Bool { true } }
final class V3HomeCarouselCadenceDiagnostics {
    static let shared = V3HomeCarouselCadenceDiagnostics()
    func recordImageCallback(role: String, itemID: String) {}
    func recordSwiftUIUpdate(progress: CGFloat) {}
    func recordProgressPublish(_ progress: CGFloat) {}
    func end(reason: String) {}
}
final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()
    func app(_ category: String, _ message: String) {}
    func log(_ category: String, _ message: String) {}
}
