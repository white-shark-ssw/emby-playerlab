import Foundation
import SwiftUI
import UIKit

struct PlayerFloatingPanelOverlay: View {
    let panel: PlayerControlPanel
    let source: ResolvedPlaybackSource
    let currentRate: Double
    let onRateSelected: (Double) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            Group {
                switch panel {
                case .info:
                    PlayerPlaybackInfoFloatingPanel(source: source)
                case .speed:
                    PlayerSpeedFloatingPanel(currentRate: currentRate, onSelect: { rate in
                        onRateSelected(rate)
                        onDismiss()
                    })
                case .tracks, .episodes:
                    EmptyView()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { }
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }
}

extension View {
    @ViewBuilder
    func playerFloatingPanelPresentation() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.clear)
        } else {
            self.background(PlayerClearPresentationBackground())
        }
    }
}

private struct PlayerClearPresentationBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async { clearPresentationBackground(from: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { clearPresentationBackground(from: uiView) }
    }

    private func clearPresentationBackground(from view: UIView) {
        var current = view.superview
        var remaining = 4
        while let container = current, remaining > 0 {
            container.backgroundColor = .clear
            current = container.superview
            remaining -= 1
        }
    }
}

private struct PlayerFloatingPanelChrome<Content: View>: View {
    let title: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat?
    let content: Content

    init(title: String, maxWidth: CGFloat, maxHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.52))
                .padding(.horizontal, 20)
                .frame(height: 42)

            Divider().background(Color.white.opacity(0.09))
            content
        }
        .frame(maxWidth: maxWidth)
        .frame(maxHeight: maxHeight)
        .background(Color(red: 0.16, green: 0.16, blue: 0.17).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 24)
    }
}

private struct PlayerSpeedFloatingPanel: View {
    let currentRate: Double
    let onSelect: (Double) -> Void
    private let rates = [3.0, 2.5, 2.0, 1.75, 1.5, 1.25, 1.0, 0.75, 0.5]

    var body: some View {
        PlayerFloatingPanelChrome(title: "倍速", maxWidth: 330, maxHeight: 400) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(rates.enumerated()), id: \.element) { index, rate in
                        Button { onSelect(rate) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .opacity(abs(currentRate - rate) < 0.001 ? 1 : 0)
                                    .frame(width: 18)

                                Text(rateTitle(rate))
                                    .font(.system(size: 20, weight: .regular))
                                    .monospacedDigit()

                                Spacer(minLength: 0)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 39)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index != rates.count - 1 { Divider().background(Color.white.opacity(0.08)).padding(.leading, 20) }
                    }
                }
            }
        }
    }

    private func rateTitle(_ rate: Double) -> String {
        if abs(rate.rounded() - rate) < 0.001 { return String(format: "%.0fX", rate) }
        if abs(rate * 10 - (rate * 10).rounded()) < 0.001 { return String(format: "%.1fX", rate) }
        return String(format: "%.2fX", rate)
    }
}

private struct PlayerPlaybackInfoFloatingPanel: View {
    let source: ResolvedPlaybackSource

    var body: some View {
        PlayerFloatingPanelChrome(title: "播放信息", maxWidth: 620, maxHeight: 340) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    infoSection(title: "媒体", fields: mediaFields)
                    if !videoFields.isEmpty { infoSection(title: "视频", fields: videoFields) }
                    if !audioFields.isEmpty { infoSection(title: "音频", fields: audioFields) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    private var videoStream: MediaStream? { source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame }) }
    private var audioStream: MediaStream? { source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Audio") == .orderedSame }) }

    private var mediaFields: [PlayerInfoField] {
        var fields: [PlayerInfoField] = []
        appendField("容器", source.mediaSource.container?.uppercased(), to: &fields)
        appendField("时长", source.mediaSource.durationSeconds.map(formatTime), to: &fields)
        if let size = source.mediaSource.size { appendField("文件大小", ByteCountFormatter.string(fromByteCount: size, countStyle: .file), to: &fields) }
        return fields
    }

    private var videoFields: [PlayerInfoField] {
        guard let video = videoStream else { return [] }
        var fields: [PlayerInfoField] = []
        appendField("编码", video.codec?.uppercased(), to: &fields)
        if let width = video.width, let height = video.height { appendField("分辨率", "\(width) × \(height)", to: &fields) }
        appendField("显示比例", video.displayAspectRatio.map { String(format: "%.3f:1", $0) }, to: &fields)
        if let rotation = video.rotation, rotation % 360 != 0 { appendField("旋转", "\(rotation)°", to: &fields) }
        if let frameRate = video.averageFrameRate ?? video.realFrameRate { appendField("帧率", String(format: "%.3g fps", frameRate), to: &fields) }
        if let bitRate = video.bitRate { appendField("码率", bitrateTitle(bitRate), to: &fields) }
        appendField("动态范围", video.videoRangeType ?? video.videoRange, to: &fields)
        if let bitDepth = video.bitDepth { appendField("位深", "\(bitDepth) bit", to: &fields) }
        appendField("像素格式", video.pixelFormat, to: &fields)
        return fields
    }

    private var audioFields: [PlayerInfoField] {
        guard let audio = audioStream else { return [] }
        var fields: [PlayerInfoField] = []
        appendField("编码", audio.codec?.uppercased(), to: &fields)
        appendField("声道", audio.channelLayout ?? audio.channels.map(String.init), to: &fields)
        if let sampleRate = audio.sampleRate { appendField("采样率", "\(sampleRate) Hz", to: &fields) }
        if let bitRate = audio.bitRate { appendField("码率", bitrateTitle(bitRate), to: &fields) }
        appendField("语言", audio.language, to: &fields)
        return fields
    }

    private func infoSection(title: String, fields: [PlayerInfoField]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.55))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], alignment: .leading, spacing: 9) {
                ForEach(fields) { field in
                    HStack(spacing: 8) {
                        Text(field.title).foregroundColor(.white.opacity(0.58))
                        Spacer(minLength: 6)
                        Text(field.value).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .font(.system(size: 13, weight: .regular))
                }
            }
        }
    }

    private func appendField(_ title: String, _ value: String?, to fields: inout [PlayerInfoField]) {
        guard let value, !value.isEmpty else { return }
        fields.append(PlayerInfoField(title: title, value: value))
    }

    private func bitrateTitle(_ value: Int) -> String {
        value >= 1_000_000 ? String(format: "%.2f Mbps", Double(value) / 1_000_000) : String(format: "%.0f Kbps", Double(value) / 1_000)
    }
}

private struct PlayerInfoField: Identifiable {
    let title: String
    let value: String
    var id: String { title + "=" + value }
}
