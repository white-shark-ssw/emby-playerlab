import SwiftUI
import UniformTypeIdentifiers
import UIKit

#if MDK_LAB && canImport(swift_mdk)

@MainActor
final class LocalMDKFileLabModel: ObservableObject {
    @Published var snapshot = PlayerSnapshot()
    @Published var selectedName = "未选择文件"
    @Published var statusText = "请选择已经完整下载到本机的异常视频。"
    @Published var isPlaying = false

    private var engine: KSAVIOPlayerEngine?
    private var scopedURL: URL?

    func open(_ url: URL) {
        stop()
        let access = url.startAccessingSecurityScopedResource()
        scopedURL = access ? url : nil
        selectedName = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let bytes = values?.fileSize ?? 0
        DiagnosticsLogger.shared.playback("LocalMDKLab", "open source=local-file name=\(url.lastPathComponent) ext=\(url.pathExtension.lowercased()) bytes=\(bytes) unifiedTransport=false embyReporting=false resume=false fallback=false")
        statusText = "MDK 正在直接读取本地文件…"

        let newEngine = KSAVIOPlayerEngine(sharedTransportSession: nil)
        newEngine.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.snapshot = snapshot
                self.isPlaying = snapshot.state == .playing
                self.statusText = snapshot.errorMessage ?? self.status(for: snapshot.state)
            }
        }
        engine = newEngine
        newEngine.prepare(url: url, headers: [:], resumePosition: 0)
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
            DiagnosticsLogger.shared.playback("LocalMDKLab", "stop source=local-file position=\(String(format: "%.3f", snapshot.position)) duration=\(String(format: "%.3f", snapshot.duration)) state=\(snapshot.state.rawValue)")
            engine.stop()
        }
        engine = nil
        if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
        scopedURL = nil
        isPlaying = false
    }

    private func status(for state: PlayerState) -> String {
        switch state {
        case .idle: return "空闲"
        case .preparing: return "MDK prepare 中…"
        case .playing: return "MDK 本地文件播放中"
        case .paused: return "已暂停"
        case .buffering: return "MDK buffering"
        case .ended: return "MDK 报告播放结束"
        case .failed: return "MDK 播放失败，请导出日志"
        }
    }
}

struct LocalMDKFileLabView: View {
    @StateObject private var model = LocalMDKFileLabModel()
    @State private var pickerPresented = false
    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false

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

private extension LocalMDKFileLabModel {
    var engineRenderView: UIView? { engine?.renderView }
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
