#if canImport(AetherEngine)
import AetherEngine
import SwiftUI
import UIKit

struct AetherPlayerSurface: UIViewRepresentable {
    let playerView: AetherPlayerView

    func makeUIView(context: Context) -> AetherPlayerView { playerView }
    func updateUIView(_ uiView: AetherPlayerView, context: Context) {}
}
#endif
