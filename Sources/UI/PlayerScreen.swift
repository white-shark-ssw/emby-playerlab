import SwiftUI

struct PlayerScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var controller: PlayerController
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("buffer.preset") private var bufferPresetRaw = BufferPreset.balanced.rawValue
    @State private var showSettings = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient) {
        _controller = StateObject(wrappedValue: PlayerController(source: source, client: client))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AVPlayerSurface(player: controller.engine.player)
                .ignoresSafeArea()

            DoubleTapGestureOverlay(
                onLeftDoubleTap: { controller.seek(by: -Double(backwardSeconds)) },
                onRightDoubleTap: { controller.seek(by: Double(forwardSeconds)) }
            )
            .ignoresSafeArea()

            if let feedback = controller.seekFeedback {
                Text(feedback)
                    .font(.system(size: 34, weight: .bold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.65))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
            }

            controls

            if let message = controller.prematureEOFMessage {
                VStack {
                    Text("疑似提前结束")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.red.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding()
                .frame(maxHeight: .infinity, alignment: .top)
            }
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

    private var controls: some View {
        VStack {
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding()
                }

                Spacer()

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
                        Image(systemName: controller.snapshot.isPlaying ? "pause.fill" : "play.fill")
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
                    Slider(
                        value: Binding(
                            get: { controller.displayedPosition },
                            set: { controller.updateScrubbing(to: $0) }
                        ),
                        in: 0...max(controller.effectiveDuration, 1),
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
                    colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .foregroundColor(.white)
    }

    private var diagnosticsRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(controller.lastSeekSummary)
            Text("缓冲到 \(formatTime(controller.bufferedEnd)) · \(controller.snapshot.isBuffering ? "等待数据" : "可播放")")
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
