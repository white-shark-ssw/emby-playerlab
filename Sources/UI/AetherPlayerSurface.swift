#if canImport(AetherEngine)
import SwiftUI
import UIKit

struct AetherPlayerSurface: UIViewRepresentable {
    let playerView: UIView

    func makeUIView(context: Context) -> UIView { playerView }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
