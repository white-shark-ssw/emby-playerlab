import SwiftUI
import UniformTypeIdentifiers
import UIKit

#if MDK_LAB && canImport(swift_mdk)

@MainActor
final class LocalMDKFileLabModel: ObservableObject {
    @Published var selectedName = "尚未选择文件"
    @Published var snapshot = PlayerSnapshot()
    @Published var seekTarget: Double = 0
    @Published var isPresentingPicker = false
    @Published var isPlaying = false

    private var engine: KSAVIOPlayerEngine?
    private var securityScopedURL: URL?

    var playerView: UIView? { engine?.playerView }

    func select(_ url: URL) {
        stop()
        let granted = url.startAccessingSecurityScopedResource()
        securityScopedURL = granted ? url : nil
        selectedName = url.lastPathComponent

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let size = values?.fileSize ?? 0
        let ext = url.pathExtension.lowercased()
        DiagnosticsLogger.shared.playback("LocalMDKLab", "event=file-selected source=local-file name=\(url.lastPathComponent) ext=\(ext) size=\(size) securityScoped=\(granted) emby=false unifiedTransport=false fallback=false")

        let mediaSource = MediaSource(id: "local-mdk-lab", name: url.lastPathComponent, path: url.path, container: ext, directStreamURL: nil, supportsDirectPlay: true, supportsDirectStream: true, runTimeTicks: nil, size: Int64(size), requiredHTTPHeaders: nil, mediaStreams: nil)
        let source = ResolvedPlaybackSource(itemId: "local-mdk-lab", itemName: url.lastPathComponent, mediaSource: mediaSource, playSessionId: nil, url: url, headers: [:])
        let client = EmbyAPIClient(baseURL: URL(string: "http://127.0.0.1")!)
        let newEngine = KSAVIOPlayerEngine(source: source, client: client, configuration: MediaTransportConfiguration.current(), sharedTransportSession: nil)
        newEngine.onSnapshot = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                let previous = self.snapshot
                self.snapshot = value
                self.seekTarget = value.position
                self.isPlaying = value.isPlaying
                if previous.didReachEnd != value.didReachEnd || previous.errorMessage != value.errorMessage {
                    DiagnosticsLogger.shared.playback("LocalMDKLab", "event=snapshot source=local-file position=\(String(format: "%.3f", value.position)) duration=\(String(format: "%.3f", value.duration)) playing=\(value.isPlaying) buffering=\(value.isBuffering) ended=\(value.didReachEnd) error=\(value.errorMessage ?? "none")")
                }
            }
        }
        newEngine.onSeekCompleted = { result in
            DiagnosticsLogger.shared.playback("LocalMDKLab", "event=seek-complete source=local-file target=\(String(format: "%.3f", result.target)) actual=\(result.actualPosition.map { String(format: "%.3f", $0) } ?? "nil") latencyMs=\(String(format: "%.1f", result.completionLatencyMs))")
        }
        engine = newEngine
        snapshot = PlayerSnapshot()
        seekTarget = 0
        DiagnosticsLogger.shared.playback("LocalMDKLab", "event=prepare source=local-file urlScheme=file start=0 emby=false resume=false unifiedTransport=false fallback=false")
        newEngine.prepare(url: url, headers: [:], preferredForwardBuffer: 0, startPosition: 0)
        newEngine.play()
    }

    func togglePlayback() {
        guard let engine else { return }
        if isPlaying { engine.pause() } else { engine.play() }
    }

    func seek(to value: Double) {
        guard let engine else { return }
        DiagnosticsLogger.shared.playback("LocalMDKLab", "event=seek-request source=local-file from=\(String(format: "%.3f", snapshot.position)) target=\(String(format: "%.3f", value))")
        engine.seek(to: value, direction: .absolute)
    }

    func stop() {
        if let engine {
            DiagnosticsLogger.shared.playback("LocalMDKLab", "event=stop source=local-file position=\(String(format: "%.3f", snapshot.position)) duration=\(String(format: "%.3f", snapshot.duration)) ended=\(snapshot.didReachEnd) error=\(snapshot.errorMessage ?? "none")")
            engine.stop()
        }
        engine = nil
        if let securityScopedURL { securityScopedURL.stopAccessingSecurityScopedResource() }
        securityScopedURL = nil
        isPlaying = false
    }
}

struct LocalMDKFileLabView: View {
    @StateObject private var model = LocalMDKFileLabModel()

    var body: some View {
        VStack(spacing: 14) {
            Text("MDK 本地文件实验")
                .font(.headline)
            Text("直接将系统文件交给 MDK；不经过 Emby、UnifiedTransport、网络缓存、Resume 或 MPV 自动接管。日志仍写入 OnePlayer 播放日志。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("选择本机视频") { model.isPresentingPicker = true }
                .buttonStyle(.borderedProminent)
            Text(model.selectedName)
                .font(.footnote)
                .lineLimit(2)

            if let view = model.playerView {
                LocalMDKSurface(view: view)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .background(Color.black)
            } else {
                Rectangle().fill(Color.black).aspectRatio(16.0 / 9.0, contentMode: .fit)
            }

            if model.snapshot.duration > 0 {
                Slider(value: Binding(get: { min(model.seekTarget, model.snapshot.duration) }, set: { model.seekTarget = $0 }), in: 0...model.snapshot.duration, onEditingChanged: { editing in if !editing { model.seek(to: model.seekTarget) } })
                Text("\(format(model.snapshot.position)) / \(format(model.snapshot.duration))")
                    .font(.caption.monospacedDigit())
            }

            HStack(spacing: 24) {
                Button { model.seek(to: max(0, model.snapshot.position - 10)) } label: { Image(systemName: "gobackward.10").font(.title2) }
                Button { model.togglePlayback() } label: { Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").font(.title2) }
                Button { model.seek(to: min(model.snapshot.duration > 0 ? model.snapshot.duration : .greatestFiniteMagnitude, model.snapshot.position + 10)) } label: { Image(systemName: "goforward.10").font(.title2) }
            }

            if model.snapshot.isBuffering { Text("MDK buffering").font(.caption).foregroundColor(.secondary) }
            if let error = model.snapshot.errorMessage { Text(error).font(.caption).foregroundColor(.red) }
            Spacer()
        }
        .padding()
        .navigationTitle("MDK 本地实验")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $model.isPresentingPicker) { LocalVideoDocumentPicker { url in model.select(url) } }
        .onDisappear { model.stop() }
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let value = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

private struct LocalMDKSurface: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct LocalVideoDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .video, .audiovisualContent], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { if let url = urls.first { onPick(url) } }
    }
}

#else

struct LocalMDKFileLabView: View {
    var body: some View { Text("当前构建未包含 MDK 实验引擎。") .navigationTitle("MDK 本地实验") }
}

#endif
