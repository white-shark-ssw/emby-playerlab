import SwiftUI
import UniformTypeIdentifiers
import UIKit

#if MDK_LAB && canImport(swift_mdk)
import QuartzCore
import swift_mdk

private final class LocalMDKRenderView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isUserInteractionEnabled = false
        metalLayer.contentsScale = UIScreen.main.scale
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.scale ?? UIScreen.main.scale
        metalLayer.drawableSize = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
    }

    var currentPixelSize: CGSize {
        let size = metalLayer.drawableSize
        if size.width > 0, size.height > 0 { return size }
        let scale = window?.screen.scale ?? UIScreen.main.scale
        return CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
    }
}

@MainActor
private final class LocalMDKDirectFilePlayer {
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    let renderView = LocalMDKRenderView(frame: .zero)

    private var renderer: PlayerMetalLayerRenderer?
    private var player: swift_mdk.Player?
    private var timer: Timer?
    private var shouldPlay = false
    private var generation = 0

    func prepare(url: URL) {
        stopPlayerOnly()
        generation &+= 1
        let currentGeneration = generation
        guard let renderer = PlayerMetalLayerRenderer(layer: renderView.metalLayer) else {
            onSnapshot?(PlayerSnapshot(errorMessage: "Metal renderer unavailable"))
            return
        }
        self.renderer = renderer
        let player = swift_mdk.Player()
        self.player = player
        player.videoDecoders = ["VT", "FFmpeg"]
        player.setBufferRange(msMin: 1_000, msMax: 30_000, drop: false)
        player.setProperty(name: "keep_open", value: "1")
        player.setProperty(name: "avio.multiple_requests", value: "1")
        player.setProperty(name: "avio.short_seek_size", value: String(2 * 1_048_576))
        player.media = url.absoluteString
        DiagnosticsLogger.shared.playback("LocalMDKLab", "prepare-dispatch source=local-file generation=\(currentGeneration) decoder=VT,FFmpeg unifiedTransport=false fallback=false")
        player.prepare(from: 0, complete: { [weak self, weak player, weak renderer] preparedAtMs, boost in
            boost = true
            guard let self, let player, let renderer else { return false }
            DispatchQueue.main.async {
                guard currentGeneration == self.generation, self.player === player else { return }
                renderer.prepareSurfaceSize(self.renderView.currentPixelSize)
                renderer.bind(player)
                renderer.setSurfaceSize(self.renderView.currentPixelSize, player: player)
                if self.shouldPlay { player.state = .Playing }
                self.startTimer(player: player, generation: currentGeneration)
                DiagnosticsLogger.shared.playback("LocalMDKLab", "prepared source=local-file generation=\(currentGeneration) preparedAtMs=\(preparedAtMs) rendererBound=true")
            }
            return true
        })
    }

    func play() {
        shouldPlay = true
        player?.state = .Playing
    }

    func pause() {
        shouldPlay = false
        player?.state = .Paused
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let target = max(0, seconds)
        let requestedAt = Date().timeIntervalSince1970
        player.seek(Int64((target * 1_000).rounded()), flags: .Default) { [weak self, weak player] actualMs in
            DispatchQueue.main.async {
                guard let self, let player, self.player === player else { return }
                let latency = (Date().timeIntervalSince1970 - requestedAt) * 1_000
                DiagnosticsLogger.shared.playback("LocalMDKLab", "seek-callback source=local-file target=\(String(format: "%.3f", target)) actualMs=\(actualMs) latencyMs=\(String(format: "%.1f", latency))")
                if self.shouldPlay { player.state = .Playing }
            }
        }
    }

    func stop() {
        shouldPlay = false
        generation &+= 1
        stopPlayerOnly()
        onSnapshot = nil
    }

    private func startTimer(player: swift_mdk.Player, generation: Int) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self, weak player] _ in
            guard let self, let player, generation == self.generation, self.player === player else { return }
            let position = max(0, Double(player.position) / 1_000)
            let duration = max(0, Double(player.mediaInfo.duration) / 1_000)
            let status = player.mediaStatus.rawValue
            let buffering = self.hasStatus(status, bit: 3) || self.hasStatus(status, bit: 4)
            let ended = self.hasStatus(status, bit: 6)
            let playing = player.state == .Playing && !ended
            let forward = max(0, Double(player.buffered()) / 1_000)
            let bufferedEnd = duration > 0 ? min(duration, position + forward) : position + forward
            self.onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: playing, isBuffering: buffering, waitingReason: buffering ? "MDK 等待本地媒体数据" : nil, errorMessage: self.hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: ended))
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func stopPlayerOnly() {
        timer?.invalidate()
        timer = nil
        renderer?.detach()
        renderer = nil
        guard let player else { return }
        self.player = nil
        DispatchQueue.global(qos: .utility).async { player.state = .Stopped }
    }

    private func hasStatus(_ raw: Int32, bit: Int32) -> Bool { UInt32(bitPattern: raw) & (UInt32(1) << UInt32(bit)) != 0 }
}

@MainActor
final class LocalMDKFileLabModel: ObservableObject {
    @Published var snapshot = PlayerSnapshot()
    @Published var selectedName = "未选择文件"
    @Published var statusText = "请选择已经完整下载到本机的异常视频。"
    @Published var isPlaying = false

    private var engine: LocalMDKDirectFilePlayer?
    private var scopedURL: URL?
    var engineRenderView: UIView? { engine?.renderView }

    func open(_ url: URL) {
        stop()
        let access = url.startAccessingSecurityScopedResource()
        scopedURL = access ? url : nil
        selectedName = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let bytes = values?.fileSize ?? 0
        DiagnosticsLogger.shared.playback("LocalMDKLab", "open source=local-file name=\(url.lastPathComponent) ext=\(url.pathExtension.lowercased()) bytes=\(bytes) unifiedTransport=false embyReporting=false resume=false fallback=false")
        statusText = "MDK 正在直接读取本地文件…"

        let newEngine = LocalMDKDirectFilePlayer()
        newEngine.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.snapshot = snapshot
            self.isPlaying = snapshot.isPlaying
            if let error = snapshot.errorMessage { self.statusText = error }
            else if snapshot.didReachEnd { self.statusText = "MDK 报告播放结束" }
            else if snapshot.isBuffering { self.statusText = "MDK buffering" }
            else if snapshot.isPlaying { self.statusText = "MDK 本地文件播放中" }
            else { self.statusText = "已暂停" }
        }
        engine = newEngine
        newEngine.prepare(url: url)
        newEngine.play()
    }

    func togglePlayback() {
        guard let engine else { return }
        if isPlaying { engine.pause() } else { engine.play() }
    }

    func seek(by delta: TimeInterval) { seek(to: snapshot.position + delta) }

    func seek(to target: TimeInterval) {
        guard let engine else { return }
        let bounded = max(0, snapshot.duration > 0 ? min(target, snapshot.duration) : target)
        DiagnosticsLogger.shared.playback("LocalMDKLab", "seek source=local-file requested=\(String(format: "%.3f", bounded)) from=\(String(format: "%.3f", snapshot.position))")
        engine.seek(to: bounded)
    }

    func stop() {
        if let engine {
            DiagnosticsLogger.shared.playback("LocalMDKLab", "stop source=local-file position=\(String(format: "%.3f", snapshot.position)) duration=\(String(format: "%.3f", snapshot.duration))")
            engine.stop()
        }
        engine = nil
        if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
        scopedURL = nil
        isPlaying = false
    }
}

struct LocalMDKFileLabView: View {
    @StateObject private var model = LocalMDKFileLabModel()
    @SwiftUI.State private var pickerPresented = false
    @SwiftUI.State private var scrubPosition: Double = 0
    @SwiftUI.State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 16) {
            Text("MDK 本地文件实验").font(.title2.bold())
            Text("本入口只用于 A/B 诊断：本地 file URL → MDK。不会经过 Emby、STRM、302、115、UnifiedTransport，也不会自动切换 MPV。日志仍写入 OnePlayer 播放诊断。")
                .font(.footnote).foregroundStyle(.secondary)
            Button("选择本地视频") { pickerPresented = true }.buttonStyle(.borderedProminent)
            Text(model.selectedName).font(.caption).lineLimit(2)

            if let renderView = model.engineRenderView {
                LocalMDKRenderContainer(renderView: renderView).aspectRatio(16 / 9, contentMode: .fit).background(Color.black)
            } else {
                Rectangle().fill(Color.black).aspectRatio(16 / 9, contentMode: .fit).overlay(Text("选择文件后由 MDK 直接渲染").foregroundStyle(.secondary))
            }

            Text(model.statusText).font(.callout)
            HStack {
                Button("-10 秒") { model.seek(by: -10) }
                Button(model.isPlaying ? "暂停" : "播放") { model.togglePlayback() }
                Button("+10 秒") { model.seek(by: 10) }
            }.buttonStyle(.bordered)

            Slider(value: Binding(get: { isScrubbing ? scrubPosition : model.snapshot.position }, set: { scrubPosition = $0 }), in: 0...max(model.snapshot.duration, 1), onEditingChanged: { editing in
                isScrubbing = editing
                if !editing { model.seek(to: scrubPosition) }
            })
            Text("\(formatTime(isScrubbing ? scrubPosition : model.snapshot.position)) / \(formatTime(model.snapshot.duration))").font(.caption.monospacedDigit())
            Spacer()
        }
        .padding()
        .navigationTitle("MDK 本地实验")
        .fileImporter(isPresented: $pickerPresented, allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { model.open(url) }
            case .failure(let error): DiagnosticsLogger.shared.playback("LocalMDKLab", "picker-failed error=\(error.localizedDescription)")
            }
        }
        .onDisappear { model.stop() }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded(.down)); return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct LocalMDKRenderContainer: UIViewRepresentable {
    let renderView: UIView
    func makeUIView(context: Context) -> UIView { renderView }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#else

struct LocalMDKFileLabView: View {
    var body: some View { Text("当前构建未包含 MDK 实验引擎。").navigationTitle("MDK 本地实验") }
}

#endif
