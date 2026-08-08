import SwiftUI

struct PlayerScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var controller: PlayerController
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("seek.screenPanEnabled") private var screenPanEnabled = true
    @AppStorage("buffer.preset") private var bufferPresetRaw = BufferPreset.balanced.rawValue
    @State private var showSettings = false
    @State private var isClosing = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, preference: PlayerEnginePreference) {
        _controller = StateObject(wrappedValue: PlayerController(source: source, client: client, preference: preference))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !isClosing {
                playerSurface
                    .ignoresSafeArea()
            }

            PlaybackGestureOverlay(
                onLeftDoubleTap: { controller.seek(by: -Double(backwardSeconds)) },
                onRightDoubleTap: { controller.seek(by: Double(forwardSeconds)) },
                onHorizontalPanBegan: {
                    if screenPanEnabled { controller.beginScreenScrubbing() }
                },
                onHorizontalPanChanged: { translation, width in
                    if screenPanEnabled {
                        controller.updateScreenScrubbing(translationX: translation, viewWidth: width)
                    }
                },
                onHorizontalPanEnded: {
                    if screenPanEnabled { controller.endScreenScrubbing() }
                },
                onHorizontalPanCancelled: {
                    if screenPanEnabled { controller.cancelScreenScrubbing() }
                }
            )
            .ignoresSafeArea()

            if let feedback = controller.seekFeedback {
                feedbackView(feedback)
            }

            if let feedback = controller.scrubFeedback {
                feedbackView(feedback)
            }

            controls

            statusMessages
        }
        .statusBar(hidden: true)
        .onAppear {
            let preset = BufferPreset(rawValue: bufferPresetRaw) ?? .balanced
            controller.start(preferredForwardBuffer: preset.seconds)
        }
        .onDisappear {
            controller.stop()
        }
        .sheet(isPresented: $showSettings) {
            PlayerSettingsView()
        }
    }

    @ViewBuilder
    private var playerSurface: some View {
        if controller.engineKind == .mpv, let layer = controller.mpvDisplayLayer {
            GeometryReader { geometry in
                MPVPlayerSurface(displayLayer: layer)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id("\(ObjectIdentifier(layer))-\(Int(geometry.size.width.rounded()))x\(Int(geometry.size.height.rounded()))")
            }
        } else if controller.engineKind == .ksAVIO, let view = controller.ksAVIOView {
            KSAVIOPlayerSurface(playerView: view)
                .id(ObjectIdentifier(view))
        } else if let player = controller.avPlayer {
            AVPlayerSurface(player: player)
                .id("avplayer")
        } else {
            Color.black
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 8) {
                Button {
                    guard !isClosing else { return }
                    isClosing = true
                    DiagnosticsLogger.shared.log("Lifecycle", "close button tapped")

                    // Give SwiftUI one frame to dismantle the MPV surface/KVO before libmpv teardown.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        controller.stop()
                        presentationMode.wrappedValue.dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding()
                }

                Text(controller.source.itemName)
                    .lineLimit(1)
                    .font(.headline)

                Spacer()

                Text(engineBadge)
                    .font(.headline.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                    .accessibilityLabel("当前自动播放引擎：\(controller.engineKind.title)")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .padding()
                }
            }

            Spacer()

            VStack(spacing: 10) {
                diagnosticsRow

                HStack(spacing: 28) {
                    Button {
                        controller.seek(by: -Double(backwardSeconds))
                    } label: {
                        Image(systemName: "gobackward.\(supportedSymbolSeconds(backwardSeconds))")
                            .font(.system(size: 30))
                    }

                    Button {
                        controller.togglePlayPause()
                    } label: {
                        Image(systemName: controller.playbackControlIsPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 38))
                    }

                    Button {
                        controller.seek(by: Double(forwardSeconds))
                    } label: {
                        Image(systemName: "goforward.\(supportedSymbolSeconds(forwardSeconds))")
                            .font(.system(size: 30))
                    }
                }

                HStack {
                    Text(formatTime(controller.displayedPosition))
                        .monospacedDigit()
                    BufferedTimelineSlider(
                        value: Binding(
                            get: { controller.displayedPosition },
                            set: { controller.updateScrubbing(to: $0) }
                        ),
                        range: 0...max(controller.effectiveDuration, 1),
                        downloadCacheRanges: controller.transportCacheRanges,
                        onEditingChanged: { editing in
                            editing ? controller.beginScrubbing() : controller.endScrubbing()
                        }
                    )
                    Text(formatTime(controller.effectiveDuration))
                        .monospacedDigit()
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .foregroundColor(.white)
    }

    private var diagnosticsRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("引擎：\(controller.engineKind.title) · \(controller.lastSeekSummary)")
            Text("下载缓存 \(Int((controller.transportCacheFraction * 100).rounded()))% · 前向可播 \(formatTime(controller.forwardBufferedDuration)) · \(controller.snapshot.isBuffering ? "等待数据" : "可播放")")
            if controller.snapshot.accessLogStalls > 0 || controller.snapshot.droppedVideoFrames > 0 {
                Text("AV 统计：停滞 \(controller.snapshot.accessLogStalls) · 丢帧 \(controller.snapshot.droppedVideoFrames)")
            }
            if let transportSummary = controller.transportSummary {
                Text("传输：\(transportSummary)")
            }
            if let reason = controller.snapshot.waitingReason {
                Text("等待原因：\(reason)")
            }
            if let error = controller.snapshot.errorMessage {
                Text("错误：\(error)").foregroundColor(.red)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusMessages: some View {
        VStack(spacing: 8) {
            if let message = controller.prematureEOFMessage {
                statusBanner(title: "疑似提前结束", message: message, color: .red)
            }
            if let message = controller.stallMessage {
                statusBanner(title: "播放停滞恢复", message: message, color: .orange)
            }
            Spacer()
        }
        .padding()
        .allowsHitTesting(false)
    }

    private func feedbackView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .bold))
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(Color.black.opacity(0.68))
            .foregroundColor(.white)
            .clipShape(Capsule())
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

    private var engineBadge: String {
        switch controller.engineKind {
        case .ktvAVPlayer: return "AUTO·KTV"
        case .resourceLoaderAVPlayer: return "AUTO·AV"
        case .transportAVPlayer: return "LEGACY"
        case .ksAVIO: return "AUTO·FF"
        case .avPlayer: return "DIRECT"
        case .mpv: return "AUTO·MPV"
        }
    }

    private func supportedSymbolSeconds(_ value: Int) -> Int {
        [10, 15, 30, 45, 60, 75, 90].contains(value) ? value : 10
    }
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "00:00" }
    let total = Int(seconds.rounded(.down))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    return hours > 0
        ? String(format: "%02d:%02d:%02d", hours, minutes, secs)
        : String(format: "%02d:%02d", minutes, secs)
}
