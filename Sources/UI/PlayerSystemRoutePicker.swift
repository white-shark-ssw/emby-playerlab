import AVKit
import SwiftUI

struct PlayerSystemRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = .white
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = .white
        uiView.activeTintColor = .white
        uiView.prioritizesVideoDevices = true
    }
}
