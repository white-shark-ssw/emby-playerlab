import AVFoundation
import Combine
import Foundation
import SwiftUI
import UIKit

struct PlayerScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller: PlayerController
    @StateObject private var sessionOverrides: PlaybackSessionOverrides
    @StateObject private var pictureInPictureController: PlayerPictureInPictureController
    @StateObject private var presentationCoordinator: PlaybackPresentationCoordinator
    @StateObject private var displayRefreshMonitor: DisplayRefreshRateMonitor
    @AppStorage(PlayerPreferenceKeys.backwardSeconds) private var backwardSeconds = 10
    @AppStorage(PlayerPreferenceKeys.forwardSeconds) private var forwardSeconds = 10
    @AppStorage(PlayerPreferenceKeys.bufferPreset) private var bufferPresetRaw = BufferPreset.balanced.rawValue
    @AppStorage(PlayerPreferenceKeys.orientationPolicy) private var orientationPolicyRaw = PlaybackOrientationPolicy.adaptive.rawValue
    @AppStorage(PlayerPreferenceKeys.temporaryPlaybackRate) private var temporaryPlaybackRate = 2.0
    @AppStorage(PlayerPreferenceKeys.volumeHapticsEnabled) private var volumeHapticsEnabled = true
    @AppStorage(PlayerPreferenceKeys.independentBrightnessEnabled) private var independentBrightnessEnabled = false
    @AppStorage(PlayerPreferenceKeys.independentBrightnessValue) private var independentBrightnessValue = 0.5
    @AppStorage(PlayerPreferenceKeys.pauseWhenBackgrounded) private var pauseWhenBackgrounded = true
    @AppStorage(PlayerPreferenceKeys.resumeWhenForegrounded) private var resumeWhenForegrounded = false
    @AppStorage(PlayerPreferenceKeys.controlsAutoHideSeconds) private var controlsAutoHideSeconds = 3.0
    @AppStorage(PlayerPresentationPreferenceKeys.motionSmoothingMode) private var motionSmoothingRaw = MotionSmoothingMode.off.rawValue
    @AppStorage(PlayerPresentationPreferenceKeys.videoEnhancementEnabled) private var videoEnhancementEnabled = false

    @State private var activePanel: PlayerControlPanel?
    @State private var playbackSettingsPresented = false
    @State private var isClosing = false
    @State private var orientationReady = false
    @State private var playbackStarted = false
    @State private var initialOrientationStarted = false
    @State private var controlsVisible = true
    @State private var centerFeedbackVisible = false
    @State private var centerFeedbackScale: CGFloat = 1
    @State private var temporaryRateHUD: Double?
    @State private var adjustmentHUD: AdjustmentHUDState?
    @State private var controlsHideWorkItem: DispatchWorkItem?
    @State private var feedbackHideWorkItem: DispatchWorkItem?
    @State private var adjustmentHideWorkItem: DispatchWorkItem?
    @State private var initialOrientationWorkItem: DispatchWorkItem?
    @State private var closeDismissWorkItem: DispatchWorkItem?
    @State private var originalScreenBrightness: CGFloat?
    @State private var wasAutoPausedForBackground = false
    @State private var audioInterruptionActive = false
    @State private var gestureResetGeneration = 0
    @State private var bufferingDownloadSpeed: Double = 0
    @State private var pipCloseDismissPending = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, preference: PlayerEnginePreference) {
        let storedEngineRaw = UserDefaults.standard.string(forKey: PlayerPreferenceKeys.enginePreference)
        let effectivePreference = preference.isAutomatic ? PlayerEnginePreference.persisted(rawValue: storedEngineRaw) : preference
        _controller = StateObject(wrappedValue: PlayerController(source: source, client: client, preference: effectivePreference))
        let defaultScaleRaw = UserDefaults.standard.string(forKey: PlayerPreferenceKeys.defaultScaleMode) ?? PlayerVideoScaleMode.fit.rawValue
        let defaultScale = PlayerVideoScaleMode(rawValue: defaultScaleRaw) ?? .fit
        _sessionOverrides = StateObject(wrappedValue: PlaybackSessionOverrides(defaultScaleMode: defaultScale))
        _pictureInPictureController = StateObject(wrappedValue: PlayerPictureInPictureController())
        _presentationCoordinator = StateObject(wrappedValue: PlaybackPresentationCoordinator(source: source))
        _displayRefreshMonitor = StateObject(wrappedValue: DisplayRefreshRateMonitor())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            playerSurface.ignoresSafeArea()

            if isClosing { Color.black.ignoresSafeArea().allowsHitTesting(false) }

            if !isClosing {
                PlaybackGestureOverlay(
                    volumeHapticsEnabled: volumeHapticsEnabled,
                    resetGeneration: gestureResetGeneration,
                    onSingleTap: toggleControls,
                    onLeftDoubleTap: { controller.seek(by: -Double(backwardSeconds)) },
                    onCenterDoubleTap: togglePlayPauseFromGesture,
                    onRightDoubleTap: { controller.seek(by: Double(forwardSeconds)) },
                    onTemporaryRateBegan: beginTemporaryRate,
                    onTemporaryRateEnded: endTemporaryRate,
                    onScreenScrubBegan: beginScreenScrub,
                    onScreenScrubChanged: { translationX, viewWidth in controller.updateScreenScrubbing(translationX: translationX, viewWidth: viewWidth) },
                    onScreenScrubEnded: endScreenScrub,
                    onScreenScrubCancelled: cancelScreenScrub,
                    onAdjustmentBegan: { adjustment, value in showAdjustmentHUD(adjustment, value: value, autoHide: false) },
                    onAdjustmentChanged: { adjustment, value in showAdjustmentHUD(adjustment, value: value, autoHide: false) },
                    onAdjustmentEnded: { adjustment, value in showAdjustmentHUD(adjustment, value: value, autoHide: true) }
                )
                .ignoresSafeArea()
                .allowsHitTesting(!isClosing && !playbackSettingsPresented)

                if let feedback = controller.scrubFeedback {
                    VStack {
                        Spacer()
                        screenScrubFeedbackView(feedback).padding(.bottom, 116)
                    }
                    .allowsHitTesting(false)
                    .zIndex(40)
                }
                if let temporaryRateHUD { rateFeedbackView(temporaryRateHUD) }
                if let adjustmentHUD { adjustmentHUDView(adjustmentHUD) }

                controls
                centerPlaybackControls

                if let feedback = controller.seekFeedback {
                    VStack {
                        Spacer()
                        feedbackView(feedback).scaleEffect(0.55).padding(.bottom, 50)
                    }
                    .allowsHitTesting(false)
                    .zIndex(12)
                }

                if controller.networkBufferingVisible { bufferingIndicator }
                statusMessages
                if let message = controller.engineSwitchNotice { automaticEngineSwitchToast(message) }

                if playbackSettingsPresented {
                    PlayerPlaybackSettingsPopover(
                        isPresented: $playbackSettingsPresented,
                        motionSmoothingRaw: $motionSmoothingRaw,
                        videoEnhancementEnabled: $videoEnhancementEnabled,
                        onPreferencesChanged: applyPresentationPreferences
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }

            PlayerPresentationDidAppearProbe(onDidAppear: handlePresentationDidAppear)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .statusBar(hidden: true)
        .onAppear {
            setPlaybackIdleTimerDisabled(true, reason: "player-appear")
            originalScreenBrightness = UIScreen.main.brightness
            applyIndependentBrightnessIfNeeded()
            displayRefreshMonitor.start()
            controller.prewarmStartup()
            AppOrientationCoordinator.shared.beginPlayerPresentation(source: controller.source)
            DispatchQueue.main.async { beginInitialOrientationIfNeeded(reason: "onAppear") }
        }
        .onDisappear {
            setPlaybackIdleTimerDisabled(false, reason: "player-disappear")
            controlsHideWorkItem?.cancel()
            feedbackHideWorkItem?.cancel()
            adjustmentHideWorkItem?.cancel()
            initialOrientationWorkItem?.cancel()
            closeDismissWorkItem?.cancel()
            displayRefreshMonitor.stop()
            playbackSettingsPresented = false
            if !isClosing { AppOrientationCoordinator.shared.restoreMainInterfaceOrientation() }
            resetTransientInteractions(reason: "disappear")
            wasAutoPausedForBackground = false
            pictureInPictureController.stopAndDetach()
            restoreOriginalBrightnessIfNeeded()
            DiagnosticsLogger.shared.app("PlayerLifecycle", "onDisappear immediate stop closing=\(isClosing)")
            controller.stop()
        }
        .onChange(of: controller.snapshot.isPlaying) { isPlaying in
            if !isPlaying, sessionOverrides.temporaryPlaybackRate != nil { endTemporaryRate() }
            if isPlaying {
                applyPresentationPreferences()
                scheduleControlsHide()
            } else { showControls(autoHide: false) }
        }
        .onChange(of: controller.engineKind) { kind in
            if !PlayerCapabilities.resolve(for: kind).supportsPictureInPicture { pictureInPictureController.stopAndDetach() }
            if playbackStarted { applyPresentationPreferences() }
        }
        .onChange(of: displayRefreshMonitor.framesPerSecond) { _ in
            if playbackStarted { applyPresentationPreferences() }
        }
        .onChange(of: motionSmoothingRaw) { _ in
            if playbackStarted { applyPresentationPreferences() }
        }
        .onChange(of: videoEnhancementEnabled) { _ in
            if playbackStarted { applyPresentationPreferences() }
        }
        .onChange(of: pictureInPictureController.isActive) { _ in updateIndependentBrightnessForPlaybackContext() }
        .onChange(of: pictureInPictureController.closePlaybackGeneration) { _ in handlePiPPlaybackClosureRequest() }
        .onChange(of: scenePhase) { phase in handleScenePhase(phase) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if pipCloseDismissPending { finalizePiPClosedPlaybackDismissal() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in handleAudioInterruption(notification) }
        .sheet(item: $activePanel, onDismiss: { scheduleControlsHide() }) { panel in
            PlayerControlPanelSheet(
                panel: panel,
                source: controller.source,
                currentRate: sessionOverrides.basePlaybackRate,
                onRateSelected: applyBasePlaybackRate,
                trackProvider: { controller.selectableTracks() },
                onTrackSelected: { controller.selectTrack($0) }
            )
        }
    }

    @ViewBuilder
    private var playerSurface: some View {
        GeometryReader { geometry in
            let plan = VideoLayoutCoordinator().makePlan(viewport: geometry.size, sourceAspectRatio: sourceDisplayAspectRatio(), mode: currentScaleMode)
            Group {
                if controller.engineKind == .mpv, let layer = controller.mpvDisplayLayer {
                    MPVPlayerSurface(displayLayer: layer, onGeometrySettled: controller.rendererSurfaceDidSettle)
                } else if controller.engineKind == .ksAVIO, let view = controller.ksAVIOView {
                    KSAVIOPlayerSurface(playerView: view).id(ObjectIdentifier(view))
                } else if let player = controller.avPlayer {
                    AVPlayerSurface(player: player, layoutPlan: plan, onPlayerLayerReady: pictureInPictureController.attach).id("avplayer")
                } else { Color.black }
            }
            .frame(width: plan.surfaceFrame.width, height: plan.surfaceFrame.height)
            .position(x: plan.surfaceFrame.midX, y: plan.surfaceFrame.midY)
            .clipped()
            .background(
                PlayerSurfaceMountProbe(onMounted: handlePlayerSurfaceMounted)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
            )
            .onAppear { controller.applyVideoLayout(plan) }
            .onChange(of: plan) { controller.applyVideoLayout($0) }
            .onChange(of: controller.engineKind) { _ in controller.applyVideoLayout(plan) }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            topControls
            Spacer()
            bottomControls
        }
        .foregroundColor(.white)
        .opacity(controlsVisible ? 1 : 0)
        .allowsHitTesting(controlsVisible && !isClosing && !playbackSettingsPresented)
        .animation(.easeOut(duration: 0.18), value: controlsVisible)
    }

    private var topControls: some View {
        HStack(spacing: 4) {
            Button(action: closePlayer) { Image(systemName: "xmark").font(.system(size: 19, weight: .semibold)).frame(width: 42, height: 42) }
            Text(controller.source.itemName).lineLimit(1).font(.headline)
            Spacer(minLength: 8)

            if capabilities.supportsSystemRoutePicker { PlayerSystemRoutePicker().frame(width: 42, height: 42).accessibilityLabel("投屏") }

            if capabilities.supportsPictureInPicture {
                Button {
                    pictureInPictureController.toggle(using: controller)
                    controlsHideWorkItem?.cancel()
                    controlsHideWorkItem = nil
                    controlsVisible = false
                } label: {
                    Image(systemName: "pip").font(.system(size: 19, weight: .semibold)).frame(width: 42, height: 42)
                }
                .disabled(!pictureInPictureController.isPossible && !pictureInPictureController.isActive)
                .accessibilityLabel(pictureInPictureController.isActive ? "退出画中画" : "进入画中画")
            }

            Button {
                rotatePlayer()
                showControls()
            } label: {
                Image(systemName: "rectangle.landscape.rotate").font(.system(size: 19, weight: .semibold)).frame(width: 42, height: 42)
            }
            .disabled(!capabilities.supportsRotation)
            .accessibilityLabel("旋转画面")

            Menu {
                ForEach(PlayerVideoScaleMode.allCases) { mode in
                    Button {
                        sessionOverrides.scaleMode = mode
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
            .disabled(!capabilities.supportsPictureSize)
            .accessibilityLabel("画面尺寸")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(LinearGradient(colors: [Color.black.opacity(0.72), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom))
    }

    private var centerPlaybackControls: some View {
        GeometryReader { geometry in
            HStack(spacing: 54) {
                Button {
                    controller.seek(by: -Double(backwardSeconds))
                    showControls()
                } label: { seekButtonLabel(systemName: "gobackward", seconds: backwardSeconds) }
                .opacity(controlsVisible ? 1 : 0)
                .allowsHitTesting(controlsVisible && !playbackSettingsPresented)

                Button(action: togglePlayPauseFromControl) {
                    Image(systemName: controller.playbackControlIsPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .frame(width: 64, height: 64)
                        .background(Color.black.opacity(0.35))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(controlsVisible || centerFeedbackVisible ? 1 : 0)
                .scaleEffect(centerFeedbackScale)
                .allowsHitTesting(controlsVisible && !playbackSettingsPresented)

                Button {
                    controller.seek(by: Double(forwardSeconds))
                    showControls()
                } label: { seekButtonLabel(systemName: "goforward", seconds: forwardSeconds) }
                .opacity(controlsVisible ? 1 : 0)
                .allowsHitTesting(controlsVisible && !playbackSettingsPresented)
            }
            .foregroundColor(.white)
            .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.46)
            .animation(.easeOut(duration: 0.18), value: controlsVisible)
        }
        .allowsHitTesting(controlsVisible && !isClosing && !playbackSettingsPresented)
    }

    private var bottomControls: some View {
        VStack(spacing: 2) {
            if !presentationCoordinator.activeFeatureBadges.isEmpty {
                HStack(spacing: 7) {
                    Spacer()
                    ForEach(presentationCoordinator.activeFeatureBadges, id: \.self) { badge in
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.42))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 2)
            }

            HStack(spacing: 12) {
                Text(formatTime(controller.displayedPosition)).monospacedDigit().font(.caption)
                BufferedTimelineSlider(
                    value: Binding(get: { controller.displayedPosition }, set: { controller.updateScrubbing(to: $0) }),
                    range: 0...max(controller.effectiveDuration, 1),
                    bufferState: controller.bufferState,
                    cacheByteRanges: controller.transportCacheRanges,
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

            PlayerBottomFunctionBar(
                tracksEnabled: hasTrackInfo && controller.supportsInteractiveTrackSelection,
                currentRate: sessionOverrides.basePlaybackRate,
                settingsPresented: playbackSettingsPresented,
                onSelect: openControlPanel,
                onSettings: togglePlaybackSettings
            )
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
        .background(LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.82)], startPoint: .top, endPoint: .bottom))
    }

    private var bufferingIndicator: some View {
        VStack(spacing: 6) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.1)
            Text("正在缓冲").font(.caption)
            if bufferingDownloadSpeed > 0 { Text(bufferingSpeedText).font(.caption2.monospacedDigit()).foregroundColor(.white.opacity(0.82)) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.58))
        .foregroundColor(.white)
        .cornerRadius(12)
        .allowsHitTesting(false)
        .task {
            bufferingDownloadSpeed = 0
            while !Task.isCancelled && controller.networkBufferingVisible {
                bufferingDownloadSpeed = await controller.currentDownloadBytesPerSecond()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .onDisappear { bufferingDownloadSpeed = 0 }
    }

    private var bufferingSpeedText: String { ByteCountFormatter.string(fromByteCount: Int64(bufferingDownloadSpeed.rounded()), countStyle: .file) + "/s" }

    @ViewBuilder
    private var statusMessages: some View {
        VStack(spacing: 8) {
            // Premature EOF stays diagnostic-only while automatic fallback is enabled.
            // Stall recovery stays diagnostic-only; automatic recovery/fallback remains active.
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
            .background(.ultraThinMaterial)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .allowsHitTesting(false)
    }

    private func screenScrubFeedbackView(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        let timeParts = (lines.first ?? "").components(separatedBy: " / ")
        let current = timeParts.first ?? ""
        let duration = timeParts.count > 1 ? timeParts[1] : ""
        let deltaRaw = lines.count > 1 ? lines[1] : ""
        let deltaText = deltaRaw.replacingOccurrences(of: " 秒", with: "s")
        let isBackward = deltaText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("-")

        return VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text(current).foregroundColor(.white)
                if !duration.isEmpty { Text("/ " + duration).foregroundColor(.white.opacity(0.58)) }
            }
            .font(.system(size: 16, weight: .semibold))
            .monospacedDigit()

            if !deltaText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: isBackward ? "backward.fill" : "forward.fill")
                    Text(deltaText).monospacedDigit()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.11, green: 0.91, blue: 0.32))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 142)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(red: 0.45, green: 0.43, blue: 0.42).opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .allowsHitTesting(false)
    }

    private func rateFeedbackView(_ rate: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "forward.fill")
            Text(String(format: "%.2gx", rate)).monospacedDigit()
        }
        .font(.system(size: 20, weight: .semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color.black.opacity(0.62))
        .foregroundColor(.white)
        .clipShape(Capsule())
        .allowsHitTesting(false)
    }

    private func automaticEngineSwitchToast(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.5))
            Spacer()
        }
        .padding(.top, 64)
        .allowsHitTesting(false)
        .zIndex(30)
    }

    private func adjustmentHUDView(_ state: AdjustmentHUDState) -> some View { PlayerAdjustmentRulerHUD(adjustment: state.adjustment, value: state.value) }

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

    private var capabilities: PlayerCapabilities { PlayerCapabilities.resolve(for: controller.engineKind) }
    private var currentScaleMode: PlayerVideoScaleMode { sessionOverrides.scaleMode }
    private var currentMotionSmoothingMode: MotionSmoothingMode { MotionSmoothingMode(rawValue: motionSmoothingRaw) ?? .off }
    private var isExternalPlaybackActive: Bool { controller.avPlayer?.isExternalPlaybackActive == true }
    private var hasTrackInfo: Bool {
        (controller.source.mediaSource.mediaStreams ?? []).contains { $0.type?.caseInsensitiveCompare("Audio") == .orderedSame || $0.type?.caseInsensitiveCompare("Subtitle") == .orderedSame }
    }

    private func handlePresentationDidAppear() { beginInitialOrientationIfNeeded(reason: "viewDidAppear-fallback") }

    private func beginInitialOrientationIfNeeded(reason: String) {
        guard !initialOrientationStarted, !isClosing else { return }
        initialOrientationStarted = true
        DiagnosticsLogger.shared.playback("Lifecycle", "initial orientation begin trigger=\(reason) playerUIAlreadyVisible=true")
        prepareInitialOrientation()
    }

    private func handlePlayerSurfaceMounted() {
        guard !isClosing, !playbackStarted else { return }
        DiagnosticsLogger.shared.playback("PlayerUI", "persistent player surface mounted; engine activation begins in parallel orientationReady=\(orientationReady)")
        startPlaybackIfNeeded()
    }

    private func prepareInitialOrientation() {
        guard let target = resolvedInitialOrientation() else {
            DiagnosticsLogger.shared.playback("PlayerUI", "initial orientation kept because media display aspect is unavailable")
            orientationReady = true
            AppOrientationCoordinator.shared.playerOrientationDidSettle()
            startPlaybackIfNeeded()
            return
        }
        beginOrientationTransition(to: target, reason: "initial", shouldStartPlayback: false)
    }

    private func beginOrientationTransition(to target: UIInterfaceOrientation, reason: String, shouldStartPlayback: Bool) {
        initialOrientationWorkItem?.cancel()
        orientationReady = false
        let current = activeWindowScene()?.interfaceOrientation
        DiagnosticsLogger.shared.playback("PlayerUI", "rotation transition begin reason=\(reason) target=\(target.rawValue) current=\(current?.rawValue ?? 0) surfaceLifecycle=persistent rendererLayout=coordinated")
        if current == target, settledSurfaceMatchesCurrentLayout() {
            finishOrientationTransition(target: target, reason: reason, shouldStartPlayback: shouldStartPlayback, timedOut: false)
            return
        }
        if current != target { requestInterfaceOrientation(target, reason: reason) }
        waitForOrientation(target, reason: reason, shouldStartPlayback: shouldStartPlayback, attempt: 0)
    }

    private func waitForOrientation(_ target: UIInterfaceOrientation, reason: String, shouldStartPlayback: Bool, attempt: Int) {
        guard !isClosing else { return }
        let actual = activeWindowScene()?.interfaceOrientation
        let rendererReady = actual == target && settledSurfaceMatchesCurrentLayout()
        if rendererReady {
            finishOrientationTransition(target: target, reason: reason, shouldStartPlayback: shouldStartPlayback, timedOut: false)
            return
        }
        if attempt >= 24 {
            DiagnosticsLogger.shared.playback("PlayerUI", "rotation renderer wait timeout reason=\(reason) target=\(target.rawValue) actual=\(actual?.rawValue ?? 0) rendererReady=\(rendererReady)")
            finishOrientationTransition(target: target, reason: reason, shouldStartPlayback: shouldStartPlayback, timedOut: true)
            return
        }
        if actual != target && (attempt == 5 || attempt == 12) { requestInterfaceOrientation(target, reason: "\(reason)-retry\(attempt)") }
        if actual == target && !rendererReady && (attempt == 0 || attempt == 6 || attempt == 12) { logSurfaceWaitState(reason: reason, target: target, attempt: attempt) }
        let workItem = DispatchWorkItem { waitForOrientation(target, reason: reason, shouldStartPlayback: shouldStartPlayback, attempt: attempt + 1) }
        initialOrientationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func finishOrientationTransition(target: UIInterfaceOrientation, reason: String, shouldStartPlayback: Bool, timedOut: Bool) {
        initialOrientationWorkItem?.cancel()
        initialOrientationWorkItem = nil
        if let plan = settledLayoutPlan() { controller.applyVideoLayout(plan) }
        orientationReady = true
        AppOrientationCoordinator.shared.playerOrientationDidSettle()
        DiagnosticsLogger.shared.playback("PlayerUI", "rotation settled reason=\(reason) target=\(target.rawValue) actual=\(activeWindowScene()?.interfaceOrientation.rawValue ?? 0) timeout=\(timedOut) surfaceLifecycle=persistent rendererLayout=coordinated")
        if shouldStartPlayback { startPlaybackIfNeeded() }
        else { showControls() }
    }

    private func settledLayoutPlan() -> VideoLayoutPlan? {
        guard let scene = activeWindowScene(), let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else { return nil }
        return VideoLayoutCoordinator().makePlan(viewport: window.bounds.size, sourceAspectRatio: sourceDisplayAspectRatio(), mode: currentScaleMode)
    }

    private func settledSurfaceMatchesCurrentLayout() -> Bool {
        guard let plan = settledLayoutPlan() else { return false }
        return controller.rendererLayoutMatches(plan)
    }

    private func logSurfaceWaitState(reason: String, target: UIInterfaceOrientation, attempt: Int) {
        guard let plan = settledLayoutPlan() else { return }
        DiagnosticsLogger.shared.playback("PlayerUI", "rotation renderer wait reason=\(reason) target=\(target.rawValue) attempt=\(attempt) \(controller.rendererLayoutWaitDescription(plan))")
    }

    private func startPlaybackIfNeeded() {
        guard !playbackStarted, !isClosing else { return }
        playbackStarted = true
        let preset = BufferPreset(rawValue: bufferPresetRaw) ?? .balanced
        DiagnosticsLogger.shared.playback("PlayerUI", "startup engine activation after persistent surface mount orientationReady=\(orientationReady)")
        controller.start(preferredForwardBuffer: preset.seconds)
        scheduleControlsHide()
    }

    private func resolvedInitialOrientation() -> UIInterfaceOrientation? {
        let policy = PlaybackOrientationPolicy(rawValue: orientationPolicyRaw) ?? .adaptive
        switch policy {
        case .landscape: return .landscapeRight
        case .portrait: return .portrait
        case .adaptive:
            guard let ratio = sourceDisplayAspectRatio() else { return nil }
            if ratio > 1.02 { return .landscapeRight }
            if ratio < 0.98 { return .portrait }
            return nil
        }
    }

    private func sourceDisplayAspectRatio() -> Double? {
        controller.source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame })?.displayAspectRatio
    }

    private func setPlaybackIdleTimerDisabled(_ disabled: Bool, reason: String) {
        if UIApplication.shared.isIdleTimerDisabled != disabled { UIApplication.shared.isIdleTimerDisabled = disabled }
        DiagnosticsLogger.shared.playback("PlayerIdleTimer", "disabled=\(disabled) reason=\(reason)")
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first(where: { $0.activationState == .foregroundInactive })
    }

    private func requestInterfaceOrientation(_ targetOrientation: UIInterfaceOrientation, reason: String) {
        guard let scene = activeWindowScene() else {
            DiagnosticsLogger.shared.playback("PlayerUI", "rotation skipped reason=\(reason) scene=unavailable")
            return
        }
        if #available(iOS 16.0, *) {
            let mask: UIInterfaceOrientationMask = targetOrientation.isPortrait ? .portrait : (targetOrientation == .landscapeLeft ? .landscapeLeft : .landscapeRight)
            if let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                root.setNeedsUpdateOfSupportedInterfaceOrientations()
                var presented = root.presentedViewController
                while let controller = presented {
                    controller.setNeedsUpdateOfSupportedInterfaceOrientations()
                    presented = controller.presentedViewController
                }
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                DiagnosticsLogger.shared.playback("PlayerUI", "rotation failed reason=\(reason) error=\(error.localizedDescription)")
            }
        } else {
            UIDevice.current.setValue(targetOrientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        DiagnosticsLogger.shared.playback("PlayerUI", "rotation requested reason=\(reason) target=\(targetOrientation.rawValue)")
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            setPlaybackIdleTimerDisabled(false, reason: "scene-background")
            resetTransientInteractions(reason: "background")
            playbackSettingsPresented = false
            restoreOriginalBrightnessIfNeeded()
            guard pauseWhenBackgrounded, !audioInterruptionActive, controller.playbackControlIsPlaying, !pictureInPictureController.isActive, !isExternalPlaybackActive else {
                wasAutoPausedForBackground = false
                DiagnosticsLogger.shared.playback("Lifecycle", "background preserve playback pip=\(pictureInPictureController.isActive) external=\(isExternalPlaybackActive) wantsPlayback=\(controller.playbackControlIsPlaying)")
                return
            }
            wasAutoPausedForBackground = controller.pausePlayback()
            DiagnosticsLogger.shared.playback("Lifecycle", "background autoPause=\(wasAutoPausedForBackground)")
        case .active:
            setPlaybackIdleTimerDisabled(true, reason: "scene-active")
            updateIndependentBrightnessForPlaybackContext()
            if pipCloseDismissPending { finalizePiPClosedPlaybackDismissal(); return }
            let shouldResume = wasAutoPausedForBackground && resumeWhenForegrounded && !audioInterruptionActive
            wasAutoPausedForBackground = false
            if shouldResume, controller.resumePlayback() {
                applyPresentationPreferences()
                DiagnosticsLogger.shared.playback("Lifecycle", "foreground resumed app-auto-paused playback")
            } else {
                DiagnosticsLogger.shared.playback("Lifecycle", "foreground no-auto-resume enabled=\(resumeWhenForegrounded) interruption=\(audioInterruptionActive)")
            }
        case .inactive:
            resetTransientInteractions(reason: "inactive")
        @unknown default:
            break
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let rawValue = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue,
              let type = AVAudioSession.InterruptionType(rawValue: rawValue) else { return }
        switch type {
        case .began:
            audioInterruptionActive = true
            wasAutoPausedForBackground = false
            resetTransientInteractions(reason: "audio-interruption")
            let paused = controller.pausePlayback()
            DiagnosticsLogger.shared.playback("AudioInterruption", "began pauseIssued=\(paused)")
        case .ended:
            audioInterruptionActive = false
            DiagnosticsLogger.shared.playback("AudioInterruption", "ended autoResume=false")
        @unknown default:
            break
        }
    }

    private func resetTransientInteractions(reason: String) {
        if sessionOverrides.temporaryPlaybackRate != nil { endTemporaryRate() }
        gestureResetGeneration &+= 1
        centerFeedbackVisible = false
        centerFeedbackScale = 1
        DiagnosticsLogger.shared.playback("PlayerGesture", "reset reason=\(reason) generation=\(gestureResetGeneration)")
    }

    private func updateIndependentBrightnessForPlaybackContext() {
        guard independentBrightnessEnabled else { return }
        if scenePhase == .active, !pictureInPictureController.isActive, !isExternalPlaybackActive { applyIndependentBrightnessIfNeeded() }
        else { restoreOriginalBrightnessIfNeeded() }
    }

    private func applyIndependentBrightnessIfNeeded() {
        guard independentBrightnessEnabled else { return }
        UIScreen.main.brightness = CGFloat(min(1, max(0, independentBrightnessValue)))
    }

    private func restoreOriginalBrightnessIfNeeded() {
        guard independentBrightnessEnabled, let originalScreenBrightness else { return }
        UIScreen.main.brightness = originalScreenBrightness
    }

    private func toggleControls() {
        if controlsVisible {
            controlsHideWorkItem?.cancel()
            playbackSettingsPresented = false
            controlsVisible = false
        } else { showControls() }
    }

    private func showControls(autoHide: Bool = true) {
        controlsVisible = true
        controlsHideWorkItem?.cancel()
        controlsHideWorkItem = nil
        if autoHide && !playbackSettingsPresented { scheduleControlsHide() }
    }

    private func scheduleControlsHide() {
        controlsHideWorkItem?.cancel()
        controlsHideWorkItem = nil
        guard controlsAutoHideSeconds > 0, controller.playbackControlIsPlaying, !playbackSettingsPresented else { return }
        let workItem = DispatchWorkItem {
            playbackSettingsPresented = false
            centerFeedbackVisible = false
            controlsVisible = false
        }
        controlsHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + controlsAutoHideSeconds, execute: workItem)
    }

    private func togglePlayPauseFromControl() {
        let willPause = controller.playbackControlIsPlaying
        controller.togglePlayPause()
        if !willPause { applyPresentationPreferences() }
        if willPause { showControls(autoHide: false) }
        else { showControls(autoHide: true) }
    }

    private func togglePlayPauseFromGesture() {
        let willPause = controller.playbackControlIsPlaying
        controller.togglePlayPause()
        if !willPause { applyPresentationPreferences() }
        showCenterPlaybackFeedback()
        if willPause {
            if controlsVisible { showControls(autoHide: false) }
        } else if controlsVisible { scheduleControlsHide() }
    }

    private func showCenterPlaybackFeedback() {
        feedbackHideWorkItem?.cancel()
        centerFeedbackVisible = true
        centerFeedbackScale = 1.14
        withAnimation(.easeOut(duration: 0.16)) { centerFeedbackScale = 1 }
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.14)) { centerFeedbackVisible = false }
        }
        feedbackHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50, execute: workItem)
    }

    private func beginTemporaryRate() {
        guard controller.playbackControlIsPlaying, sessionOverrides.temporaryPlaybackRate == nil else { return }
        let rate = min(4, max(0.25, temporaryPlaybackRate))
        sessionOverrides.temporaryPlaybackRate = rate
        temporaryRateHUD = rate
        controlsHideWorkItem?.cancel()
        applyPresentationPreferences(rate: rate)
    }

    private func endTemporaryRate() {
        guard sessionOverrides.temporaryPlaybackRate != nil else { return }
        sessionOverrides.temporaryPlaybackRate = nil
        temporaryRateHUD = nil
        applyPresentationPreferences(rate: sessionOverrides.basePlaybackRate)
        if scenePhase == .active { scheduleControlsHide() }
    }

    private func beginScreenScrub() {
        controlsHideWorkItem?.cancel()
        controller.beginScreenScrubbing()
    }

    private func endScreenScrub() {
        controller.endScreenScrubbing()
        if controlsVisible { scheduleControlsHide() }
    }

    private func cancelScreenScrub() {
        controller.cancelScreenScrubbing()
        if controlsVisible { scheduleControlsHide() }
    }

    private func applyBasePlaybackRate(_ rate: Double) {
        let clamped = min(8, max(0.15, rate))
        sessionOverrides.basePlaybackRate = clamped
        if sessionOverrides.temporaryPlaybackRate == nil, controller.playbackControlIsPlaying { applyPresentationPreferences(rate: clamped) }
        DiagnosticsLogger.shared.playback("PlayerUI", "base playback rate=\(String(format: "%.2f", clamped))")
    }

    private func applyPresentationPreferences() {
        applyPresentationPreferences(rate: sessionOverrides.effectivePlaybackRate)
    }

    private func applyPresentationPreferences(rate: Double) {
        guard playbackStarted else { return }
        let plan = presentationCoordinator.makePlan(
            rate: rate,
            motionSmoothingMode: currentMotionSmoothingMode,
            videoEnhancementEnabled: videoEnhancementEnabled,
            displayFPS: displayRefreshMonitor.framesPerSecond
        )
        presentationCoordinator.apply(plan, using: controller.engine)
    }

    private func openControlPanel(_ panel: PlayerControlPanel) {
        playbackSettingsPresented = false
        controlsHideWorkItem?.cancel()
        activePanel = panel
    }

    private func togglePlaybackSettings() {
        activePanel = nil
        controlsHideWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.18)) { playbackSettingsPresented.toggle() }
        if !playbackSettingsPresented { scheduleControlsHide() }
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

    private func handlePiPPlaybackClosureRequest() {
        pipCloseDismissPending = true
        controlsHideWorkItem?.cancel()
        feedbackHideWorkItem?.cancel()
        adjustmentHideWorkItem?.cancel()
        controlsVisible = false
        playbackSettingsPresented = false
        centerFeedbackVisible = false
        temporaryRateHUD = nil
        adjustmentHUD = nil
        DiagnosticsLogger.shared.app("PlayerLifecycle", "pip close requested playback already stopped scene=\(String(describing: scenePhase))")
        if scenePhase == .active { finalizePiPClosedPlaybackDismissal() }
    }

    private func finalizePiPClosedPlaybackDismissal() {
        guard pipCloseDismissPending, !isClosing else { return }
        pipCloseDismissPending = false
        isClosing = true
        orientationReady = false
        pictureInPictureController.stopAndDetach()
        AppOrientationCoordinator.shared.restoreMainInterfaceOrientation()
        DiagnosticsLogger.shared.app("PlayerLifecycle", "pip close foreground dismissal begin playbackStopped=true")
        waitForPortraitBeforeDismiss(attempt: 0)
    }

    private func closePlayer() {
        guard !isClosing else { return }
        DiagnosticsLogger.shared.app("PlayerLifecycle", "close tap received before engine stop engine=\(controller.engineKind.title)")
        isClosing = true
        orientationReady = false
        controlsHideWorkItem?.cancel()
        feedbackHideWorkItem?.cancel()
        adjustmentHideWorkItem?.cancel()
        initialOrientationWorkItem?.cancel()
        closeDismissWorkItem?.cancel()
        controlsVisible = false
        playbackSettingsPresented = false
        centerFeedbackVisible = false
        centerFeedbackScale = 1
        temporaryRateHUD = nil
        adjustmentHUD = nil
        controller.stop()
        pictureInPictureController.stopAndDetach()
        DiagnosticsLogger.shared.app("PlayerLifecycle", "close stop issued before orientation restore")
        DiagnosticsLogger.shared.playback("Lifecycle", "close button tapped; playback/transport stopped before portrait wait")
        AppOrientationCoordinator.shared.restoreMainInterfaceOrientation()
        waitForPortraitBeforeDismiss(attempt: 0)
    }

    private func waitForPortraitBeforeDismiss(attempt: Int) {
        guard isClosing else { return }
        let actual = activeWindowScene()?.interfaceOrientation
        if actual?.isPortrait == true || attempt >= 20 {
            closeDismissWorkItem = nil
            DiagnosticsLogger.shared.playback("Lifecycle", "player dismiss after portrait wait actual=\(actual?.rawValue ?? 0) timeout=\(attempt >= 20) surfaceLifecycle=persistent")
            presentationMode.wrappedValue.dismiss()
            return
        }
        if attempt == 6 || attempt == 12 { requestInterfaceOrientation(.portrait, reason: "close-retry\(attempt)") }
        let workItem = DispatchWorkItem { waitForPortraitBeforeDismiss(attempt: attempt + 1) }
        closeDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func rotatePlayer() {
        guard let scene = activeWindowScene() else { return }
        let targetOrientation: UIInterfaceOrientation = scene.interfaceOrientation.isLandscape ? .portrait : .landscapeRight
        sessionOverrides.manualOrientation = targetOrientation
        beginOrientationTransition(to: targetOrientation, reason: "manual", shouldStartPlayback: false)
    }

    private struct AdjustmentHUDState {
        let adjustment: PlaybackVerticalAdjustment
        let value: Double
    }
}

private struct PlayerPresentationDidAppearProbe: UIViewControllerRepresentable {
    let onDidAppear: () -> Void

    func makeUIViewController(context: Context) -> ProbeViewController { ProbeViewController(onDidAppear: onDidAppear) }

    func updateUIViewController(_ uiViewController: ProbeViewController, context: Context) { uiViewController.onDidAppear = onDidAppear }

    final class ProbeViewController: UIViewController {
        var onDidAppear: () -> Void

        init(onDidAppear: @escaping () -> Void) {
            self.onDidAppear = onDidAppear
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func loadView() {
            let view = UIView(frame: .zero)
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            DispatchQueue.main.async { [weak self] in self?.onDidAppear() }
        }
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