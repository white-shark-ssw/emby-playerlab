import SwiftUI
import UIKit

struct PlayerScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var controller: PlayerController
    @AppStorage(PlayerPreferenceKeys.backwardSeconds) private var backwardSeconds = 10
    @AppStorage(PlayerPreferenceKeys.forwardSeconds) private var forwardSeconds = 10
    @AppStorage(PlayerPreferenceKeys.bufferPreset) private var bufferPresetRaw = BufferPreset.balanced.rawValue
    @AppStorage(PlayerPreferenceKeys.volumeHapticsEnabled) private var volumeHapticsEnabled = true
    @AppStorage(PlayerPreferenceKeys.independentBrightnessEnabled) private var independentBrightnessEnabled = false
    @AppStorage(PlayerPreferenceKeys.independentBrightnessValue) private var independentBrightnessValue = 0.5
    @AppStorage(PlayerPreferenceKeys.defaultScaleMode) private var scaleModeRaw = PlayerVideoScaleMode.fit.rawValue
    @AppStorage(PlayerPreferenceKeys.controlsAutoHideSeconds) private var controlsAutoHideSeconds = 3.0

    @State private var showSettings = false
    @State private var isClosing = false
    @State private var controlsVisible = true
    @State private var centerFeedbackSymbol: String?
    @State private var adjustmentHUD: AdjustmentHUDState?
    @State private var controlsHideWorkItem: DispatchWorkItem?
    @State private var feedbackHideWorkItem: DispatchWorkItem?
    @State private var adjustmentHideWorkItem: DispatchWorkItem?
    @State private var originalScreenBrightness: CGFloat?

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, preference: PlayerEnginePreference) {
        _controller = StateObject(wrappedValue: PlayerController(source: source, client: client, preference: preference))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !isClosing { playerSurface.ignoresSafeArea() }

            PlaybackGestureOverlay(
                volumeHapticsEnabled: volumeHapticsEnabled,
                onSingleTap: toggleControls,
                onLeftDoubleTap: { controller.seek(by: -Double(backwardSeconds)) },
                onCenterDoubleTap: togglePlayPauseFromGesture,
                onRightDoubleTap: { controller.seek(by: Double(forwardSeconds)) },
                onAdjustmentBegan: { adjustment, value in showAdjustmentHUD(adjustment, value: value, autoHide: false) },
                onAdjustmentChanged: { adjustment, value in showAdjustmentHUD(adjustment, value: value, autoHide: false) },
                onAdjustmentEnded: { adjustment, value in showAdjustmentHUD(adjustment, value: value, autoHide: true) }
            )
            .ignoresSafeArea()

            if let feedback = controller.seekFeedback { feedbackView(feedback) }
            if let feedback = controller.scrubFeedback { feedbackView(feedback) }
            if let centerFeedbackSymbol { symbolFeedbackView(centerFeedbackSymbol) }

            if let adjustmentHUD { adjustmentHUDView(adjustmentHUD) }

            controls

            if controller.snapshot.isBuffering { bufferingIndicator }

            statusMessages
        }
        .statusBar(hidden: true)
        .onAppear {
            originalScreenBrightness = UIScreen.main.brightness
            if independentBrightnessEnabled { UIScreen.main.brightness = CGFloat(min(1, max(0, independentBrightnessValue))) }
            let preset = BufferPreset(rawValue: bufferPresetRaw) ?? .balanced
            controller.start(preferredForwardBuffer: preset.seconds)
            scheduleControlsHide()
        }
        .onDisappear {
            controlsHideWorkItem?.cancel()
            feedbackHideWorkItem?.cancel()
            adjustmentHideWorkItem?.cancel()
            if independentBrightnessEnabled, let originalScreenBrightness { UIScreen.main.brightness = originalScreenBrightness }
            controller.stop()
        }
        .onChange(of: controller.snapshot.isPlaying) { isPlaying in
            if isPlaying { scheduleControlsHide() }
            else { showControls(autoHide: false) }
        }
        .sheet(isPresented: $showSettings) { PlayerSettingsView() }
    }

    @ViewBuilder
    private var playerSurface: some View {
        GeometryReader { geometry in
            let mode = currentScaleMode
            let surfaceSize = playerSurfaceSize(container: geometry.size, mode: mode)
            Group {
                if controller.engineKind == .mpv, let layer = controller.mpvDisplayLayer {
                    MPVPlayerSurface(displayLayer: layer)
                } else if let player = controller.avPlayer {
                    AVPlayerSurface(player: player, scaleMode: mode).id("avplayer")
                } else {
                    Color.black
                }
            }
            .frame(width: surfaceSize.width, height: surfaceSize.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .clipped()
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            topControls
            Spacer()
            centerControls
            bottomControls
        }
        .foregroundColor(.white)
        .opacity(controlsVisible ? 1 : 0)
        .allowsHitTesting(controlsVisible)
        .animation(.easeOut(duration: 0.18), value: controlsVisible)
    }

    private var topControls: some View {
        HStack(spacing: 8) {
            Button(action: closePlayer) {
                Image(systemName: "xmark").font(.system(size: 19, weight: .semibold)).frame(width: 42, height: 42)
            }

            Text(controller.source.itemName)
                .lineLimit(1)
                .font(.headline)

            Spacer(minLength: 12)

            Button {
                rotatePlayer()
                showControls()
            } label: {
                Image(systemName: "rotate.right").font(.system(size: 19, weight: .semibold)).frame(width: 42, height: 42)
            }
            .accessibilityLabel("旋转画面")

            Menu {
                ForEach(PlayerVideoScaleMode.allCases) { mode in
                    Button {
                        scaleModeRaw = mode.rawValue
                        DiagnosticsLogger.shared.playback("PlayerUI", "picture size mode=\(mode.rawValue)")
                        showControls()
                    } label: {
                        if mode == currentScaleMode { Label(mode.title, systemImage: "checkmark") }
                        else { Text(mode.title) }
                    }
                }
            } label: {
                Image(systemName: "aspectratio").font(.system(size: 19, weight: .semibold)).frame(width: 42, height: 42)
            }
            .accessibilityLabel("画面尺寸")

            Button {
                controlsHideWorkItem?.cancel()
                showSettings = true
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 21, weight: .semibold)).frame(width: 42, height: 42)
            }
            .accessibilityLabel("更多播放设置")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(LinearGradient(colors: [Color.black.opacity(0.72), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom))
    }

    private var centerControls: some View {
        HStack(spacing: 54) {
            Button {
                controller.seek(by: -Double(backwardSeconds))
                showControls()
            } label: {
                seekButtonLabel(systemName: "gobackward", seconds: backwardSeconds)
            }

            Button {
                controller.togglePlayPause()
                showControls(autoHide: controller.playbackControlIsPlaying)
            } label: {
                Image(systemName: controller.playbackControlIsPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .frame(width: 64, height: 64)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }

            Button {
                controller.seek(by: Double(forwardSeconds))
                showControls()
            } label: {
                seekButtonLabel(systemName: "goforward", seconds: forwardSeconds)
            }
        }
        .padding(.bottom, 18)
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            Text(formatTime(controller.displayedPosition)).monospacedDigit().font(.caption)
            BufferedTimelineSlider(
                value: Binding(get: { controller.displayedPosition }, set: { controller.updateScrubbing(to: $0) }),
                range: 0...max(controller.effectiveDuration, 1),
                downloadCacheRanges: controller.transportCacheRanges,
                onEditingChanged: { editing in
                    if editing {
                        controlsHideWorkItem?.cancel()
                        controller.beginScrubbing()
                    } else {
                        controller.endScrubbing()
                        scheduleControlsHide()
                    }
                }
            )
            Text(formatTime(controller.effectiveDuration)).monospacedDigit().font(.caption)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .background(LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.82)], startPoint: .top, endPoint: .bottom))
    }

    private var bufferingIndicator: some View {
        VStack(spacing: 8) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.1)
            Text("正在缓冲").font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.58))
        .foregroundColor(.white)
        .cornerRadius(12)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var statusMessages: some View {
        VStack(spacing: 8) {
            if let message = controller.prematureEOFMessage { statusBanner(title: "疑似提前结束", message: message, color: .red) }
            if let message = controller.stallMessage { statusBanner(title: "播放停滞恢复", message: message, color: .orange) }
            Spacer()
        }
        .padding(.top, 54)
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }

    private func seekButtonLabel(systemName: String, seconds: Int) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemName).font(.system(size: 27, weight: .semibold))
            Text("\(seconds)").font(.caption2.bold()).monospacedDigit()
        }
        .frame(width: 58, height: 58)
        .background(Color.black.opacity(0.32))
        .clipShape(Circle())
    }

    private func feedbackView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 27, weight: .bold))
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(Color.black.opacity(0.62))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .allowsHitTesting(false)
    }

    private func symbolFeedbackView(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 34, weight: .bold))
            .frame(width: 76, height: 76)
            .background(Color.black.opacity(0.62))
            .foregroundColor(.white)
            .clipShape(Circle())
            .allowsHitTesting(false)
    }

    private func adjustmentHUDView(_ state: AdjustmentHUDState) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: state.adjustment == .volume ? "speaker.wave.2.fill" : "sun.max.fill")
                    .frame(width: 24)
                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<21, id: \.self) { index in
                        Capsule()
                            .fill(index <= Int((state.value * 20).rounded()) ? Color.white : Color.white.opacity(0.28))
                            .frame(width: 2.5, height: index % 5 == 0 ? 16 : 9)
                    }
                }
                Text("\(Int((state.value * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 42, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.62))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding(.top, 54)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func statusBanner(title: String, message: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.headline)
            Text(message).font(.caption).multilineTextAlignment(.center)
        }
        .padding()
        .background(color.opacity(0.88))
        .foregroundColor(.white)
        .cornerRadius(12)
    }

    private var currentScaleMode: PlayerVideoScaleMode { PlayerVideoScaleMode(rawValue: scaleModeRaw) ?? .fit }

    private func playerSurfaceSize(container: CGSize, mode: PlayerVideoScaleMode) -> CGSize {
        let targetRatio: CGFloat?
        switch mode {
        case .ratio16x9: targetRatio = 16.0 / 9.0
        case .ratio4x3: targetRatio = 4.0 / 3.0
        default: targetRatio = nil
        }
        guard let targetRatio, container.width > 0, container.height > 0 else { return container }
        if container.width / container.height > targetRatio { return CGSize(width: container.height * targetRatio, height: container.height) }
        return CGSize(width: container.width, height: container.width / targetRatio)
    }

    private func toggleControls() {
        if controlsVisible {
            controlsHideWorkItem?.cancel()
            controlsVisible = false
        } else {
            showControls()
        }
    }

    private func showControls(autoHide: Bool = true) {
        controlsVisible = true
        controlsHideWorkItem?.cancel()
        controlsHideWorkItem = nil
        if autoHide { scheduleControlsHide() }
    }

    private func scheduleControlsHide() {
        controlsHideWorkItem?.cancel()
        controlsHideWorkItem = nil
        guard controlsAutoHideSeconds > 0, controller.playbackControlIsPlaying else { return }
        let workItem = DispatchWorkItem { controlsVisible = false }
        controlsHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + controlsAutoHideSeconds, execute: workItem)
    }

    private func togglePlayPauseFromGesture() {
        let willPause = controller.playbackControlIsPlaying
        controller.togglePlayPause()
        centerFeedbackSymbol = willPause ? "pause.fill" : "play.fill"
        feedbackHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { centerFeedbackSymbol = nil }
        feedbackHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        if willPause { showControls(autoHide: false) }
        else if controlsVisible { scheduleControlsHide() }
    }

    private func showAdjustmentHUD(_ adjustment: PlaybackVerticalAdjustment, value: Double, autoHide: Bool) {
        adjustmentHideWorkItem?.cancel()
        adjustmentHideWorkItem = nil
        let clamped = min(1, max(0, value))
        adjustmentHUD = AdjustmentHUDState(adjustment: adjustment, value: clamped)
        if adjustment == .brightness, independentBrightnessEnabled { independentBrightnessValue = clamped }
        guard autoHide else { return }
        let workItem = DispatchWorkItem { adjustmentHUD = nil }
        adjustmentHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: workItem)
    }

    private func closePlayer() {
        guard !isClosing else { return }
        isClosing = true
        DiagnosticsLogger.shared.playback("Lifecycle", "close button tapped")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            controller.stop()
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func rotatePlayer() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) else { return }
        let landscape = scene.interfaceOrientation.isLandscape
        let targetOrientation: UIInterfaceOrientation = landscape ? .portrait : .landscapeRight
        if #available(iOS 16.0, *) {
            let mask: UIInterfaceOrientationMask = landscape ? .portrait : .landscapeRight
            scene.windows.first(where: { $0.isKeyWindow })?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                DiagnosticsLogger.shared.playback("PlayerUI", "rotation failed error=\(error.localizedDescription)")
            }
        } else {
            UIDevice.current.setValue(targetOrientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        DiagnosticsLogger.shared.playback("PlayerUI", "rotation requested target=\(targetOrientation.rawValue)")
    }

    private struct AdjustmentHUDState {
        let adjustment: PlaybackVerticalAdjustment
        let value: Double
    }
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "00:00" }
    let total = Int(seconds.rounded(.down))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    return hours > 0 ? String(format: "%02d:%02d:%02d", hours, minutes, secs) : String(format: "%02d:%02d", minutes, secs)
}
