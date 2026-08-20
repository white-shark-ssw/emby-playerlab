import AVFoundation
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers
import UIKit

#if MDK_LAB && canImport(swift_mdk)

enum LocalPlaybackEngineChoice: String, CaseIterable, Identifiable {
    case mdk
    case mpv

    var id: String { rawValue }
    var title: String {
        switch self {
        case .mdk: return "MDK"
        case .mpv: return "MPV"
        }
    }

    static var availableCases: [LocalPlaybackEngineChoice] {
        var result: [LocalPlaybackEngineChoice] = [.mdk]
        #if canImport(Libmpv)
        result.append(.mpv)
        #endif
        return result
    }
}

@MainActor
final class LocalPlaybackModel: ObservableObject {
    @Published var selectedName = "尚未选择文件"
    @Published var snapshot = PlayerSnapshot()
    @Published var seekTarget: Double = 0
    @Published var isPresentingPicker = false
    @Published var engineChoice: LocalPlaybackEngineChoice = .mdk
    @Published private(set) var mdkView: UIView?
    @Published private(set) var mpvLayer: CAMetalLayer?

    private var engine: PlayerEngine?
    private var selectedURL: URL?
    private var securityScopedURL: URL?

    var isPlaying: Bool { snapshot.isPlaying }

    func select(_ url: URL) {
        stop(resetSelection: false)
        let granted = url.startAccessingSecurityScopedResource()
        selectedURL = url
        securityScopedURL = granted ? url : nil
        selectedName = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        DiagnosticsLogger.shared.playback("LocalPlayback", "event=file-selected name=\(url.lastPathComponent) ext=\(url.pathExtension.lowercased()) size=\(values?.fileSize ?? 0) securityScoped=\(granted) source=file emby=false unifiedTransport=false")
        start(at: 0)
    }

    func switchEngine(to choice: LocalPlaybackEngineChoice) {
        guard engineChoice != choice else { return }
        let resumePosition = snapshot.position
        engineChoice = choice
        guard selectedURL != nil else { return }
        stopEngineOnly()
        start(at: resumePosition)
    }

    func togglePlayback() {
        guard let engine else { return }
        snapshot.isPlaying ? engine.pause() : engine.play()
    }

    func seek(to value: Double) {
        guard let engine else { return }
        let target = max(0, snapshot.duration > 0 ? min(value, snapshot.duration) : value)
        DiagnosticsLogger.shared.playback("LocalPlayback", "event=seek-request engine=\(engine.kind.title) from=\(String(format: "%.3f", snapshot.position)) target=\(String(format: "%.3f", target))")
        engine.seek(to: target, direction: .absolute)
    }

    func stop(resetSelection: Bool = true) {
        stopEngineOnly()
        if let securityScopedURL { securityScopedURL.stopAccessingSecurityScopedResource() }
        securityScopedURL = nil
        if resetSelection {
            selectedURL = nil
            selectedName = "尚未选择文件"
        }
    }

    private func start(at position: Double) {
        guard let url = selectedURL else { return }
        configureAudioSession()
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(values?.fileSize ?? 0)
        let ext = url.pathExtension.lowercased()
        let mediaSource = MediaSource(id: "local-file", name: url.lastPathComponent, path: url.path, container: ext, directStreamURL: nil, supportsDirectPlay: true, supportsDirectStream: true, runTimeTicks: nil, size: size, requiredHTTPHeaders: nil, mediaStreams: nil)
        let source = ResolvedPlaybackSource(itemId: "local-file", itemName: url.lastPathComponent, mediaSource: mediaSource, playSessionId: nil, url: url, headers: [:])

        let newEngine: PlayerEngine
        switch engineChoice {
        case .mdk:
            let client = EmbyAPIClient(baseURL: URL(string: "http://127.0.0.1")!)
            let mdk = KSAVIOPlayerEngine(source: source, client: client, configuration: MediaTransportConfiguration.current(), sharedTransportSession: nil)
            mdkView = mdk.playerView
            mpvLayer = nil
            newEngine = mdk
            DiagnosticsLogger.shared.playback("LocalPlayback", "event=surface-ready engine=mdk mount=KSAVIOPlayerSurface view=\(mdk.playerView.map { String(describing: ObjectIdentifier($0)) } ?? "nil")")
        case .mpv:
            #if canImport(Libmpv)
            let mpv = MPVPlayerEngine(sharedTransportSession: nil)
            mdkView = nil
            mpvLayer = mpv.displayLayer
            newEngine = mpv
            #else
            return
            #endif
        }

        newEngine.onSnapshot = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                self.snapshot = value
                self.seekTarget = value.position
            }
        }
        newEngine.onSeekCompleted = { result in
            DiagnosticsLogger.shared.playback("LocalPlayback", "event=seek-complete target=\(String(format: "%.3f", result.target)) actual=\(result.actualPosition.map { String(format: "%.3f", $0) } ?? "nil") latencyMs=\(String(format: "%.1f", result.completionLatencyMs))")
        }
        engine = newEngine
        snapshot = PlayerSnapshot(position: position)
        seekTarget = position
        DiagnosticsLogger.shared.playback("LocalPlayback", "event=prepare engine=\(newEngine.kind.title) scheme=file start=\(String(format: "%.3f", position)) emby=false unifiedTransport=false automaticFallback=false")
        newEngine.prepare(url: url, headers: [:], preferredForwardBuffer: 0, startPosition: position)
        newEngine.play()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
            let outputs = session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
            DiagnosticsLogger.shared.playback("LocalPlaybackAudio", "active=true category=playback mode=moviePlayback output=\(outputs) volume=\(String(format: "%.2f", session.outputVolume))")
        } catch {
            DiagnosticsLogger.shared.playback("LocalPlaybackAudio", "active=false error=\(error.localizedDescription)")
        }
    }

    private func stopEngineOnly() {
        if let engine { DiagnosticsLogger.shared.playback("LocalPlayback", "event=stop engine=\(engine.kind.title) position=\(String(format: "%.3f", snapshot.position)) duration=\(String(format: "%.3f", snapshot.duration)) error=\(snapshot.errorMessage ?? "none")") }
        engine?.stop()
        engine = nil
        mdkView = nil
        mpvLayer = nil
        snapshot = PlayerSnapshot()
        seekTarget = 0
    }
}

struct LocalPlaybackView: View {
    @StateObject private var model = LocalPlaybackModel()

    var body: some View {
        VStack(spacing: 14) {
            Text("本地播放")
                .font(.headline)
            Text("直接播放“文件”App中的本机视频。来自其他 App 文件提供器的视频会先由系统导入 OnePlayer，避免提供器不支持原地打开时点击文件无响应。该入口与 Emby、STRM、UnifiedTransport 和 Resume 完全隔离。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Picker("播放引擎", selection: Binding(get: { model.engineChoice }, set: { model.switchEngine(to: $0) })) {
                ForEach(LocalPlaybackEngineChoice.availableCases) { choice in Text(choice.title).tag(choice) }
            }
            .pickerStyle(.segmented)

            Button("选择本机视频") { model.isPresentingPicker = true }
                .buttonStyle(.borderedProminent)
            Text(model.selectedName)
                .font(.footnote)
                .lineLimit(2)

            localSurface
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .background(Color.black)

            if model.snapshot.duration > 0 {
                Slider(value: Binding(get: { min(model.seekTarget, model.snapshot.duration) }, set: { model.seekTarget = $0 }), in: 0...model.snapshot.duration, onEditingChanged: { editing in if !editing { model.seek(to: model.seekTarget) } })
                Text("\(format(model.snapshot.position)) / \(format(model.snapshot.duration))")
                    .font(.caption.monospacedDigit())
            }

            HStack(spacing: 28) {
                Button { model.seek(to: max(0, model.snapshot.position - 10)) } label: { Image(systemName: "gobackward.10").font(.title2) }
                Button { model.togglePlayback() } label: { Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").font(.title2) }
                Button { model.seek(to: model.snapshot.position + 10) } label: { Image(systemName: "goforward.10").font(.title2) }
            }

            if model.snapshot.isBuffering { Text("正在缓冲").font(.caption).foregroundColor(.secondary) }
            if let error = model.snapshot.errorMessage { Text(error).font(.caption).foregroundColor(.red) }
            Spacer()
        }
        .padding()
        .navigationTitle("本地播放")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $model.isPresentingPicker) {
            LocalVideoDocumentPicker { url in
                model.isPresentingPicker = false
                model.select(url)
            }
        }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var localSurface: some View {
        if model.engineChoice == .mdk, let view = model.mdkView {
            KSAVIOPlayerSurface(playerView: view).id(ObjectIdentifier(view))
        } else if model.engineChoice == .mpv, let layer = model.mpvLayer {
            MPVPlayerSurface(displayLayer: layer)
        } else {
            Rectangle().fill(Color.black)
        }
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let value = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

private struct LocalVideoDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .video, .audiovisualContent], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            DispatchQueue.main.async { [onPick] in onPick(url) }
        }
    }
}

#else

struct LocalPlaybackView: View {
    var body: some View {
        List { Text("当前构建未包含 MDK 本地播放能力。") }
            .navigationTitle("本地播放")
    }
}

#endif
