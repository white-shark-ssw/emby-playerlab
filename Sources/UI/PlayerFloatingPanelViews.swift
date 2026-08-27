import Foundation
import SwiftUI
import UIKit

struct PlayerFloatingPanelOverlay: View {
    let panel: PlayerControlPanel
    let source: ResolvedPlaybackSource
    let currentRate: Double
    let maxRate: Double
    let onRateSelected: (Double) -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                switch panel {
                case .info:
                    PlayerPlaybackInfoFloatingPanel(source: source)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, floatingHorizontalInset(width: geometry.size.width))
                        .padding(.bottom, 40)
                case .speed:
                    PlayerSpeedFloatingPanel(currentRate: currentRate, maxRate: maxRate, onSelect: { rate in
                        onRateSelected(rate)
                        onDismiss()
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, floatingHorizontalInset(width: geometry.size.width))
                    .padding(.bottom, 40)
                case .tracks, .episodes:
                    EmptyView()
                }
            }
        }
    }

    private func floatingHorizontalInset(width: CGFloat) -> CGFloat {
        min(116, max(72, width * 0.10))
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

private struct PlayerFrostedGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        view.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

private struct PlayerFloatingPanelChrome<Content: View>: View {
    let width: CGFloat
    let height: CGFloat?
    let content: Content

    init(width: CGFloat, height: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.width = width
        self.height = height
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: width)
            .frame(height: height)
            .background(
                ZStack {
                    PlayerFrostedGlassBackground()
                    Color.black.opacity(0.12)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.34), radius: 18, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .onTapGesture { }
    }
}

private struct PlayerSpeedFloatingPanel: View {
    let currentRate: Double
    let maxRate: Double
    let onSelect: (Double) -> Void
    private static let allRates = [8.0, 6.0, 5.0, 4.0, 3.0, 2.5, 2.0, 1.5, 1.25, 1.0, 0.75, 0.5, 0.15]
    private var rates: [Double] { Self.allRates.filter { $0 <= maxRate + 0.001 } }

    var body: some View {
        PlayerFloatingPanelChrome(width: 250, height: 380) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(rates.enumerated()), id: \.element) { index, rate in
                            Button { onSelect(rate) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .opacity(abs(currentRate - rate) < 0.001 ? 1 : 0)
                                        .frame(width: 18)

                                    Text(rateTitle(rate))
                                        .font(.system(size: 20, weight: .regular))
                                        .monospacedDigit()

                                    Spacer(minLength: 0)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(rate)

                            if index != rates.count - 1 { Divider().background(Color.white.opacity(0.13)) }
                        }
                    }
                }
                .onAppear {
                    let nearest = rates.min(by: { abs($0 - currentRate) < abs($1 - currentRate) }) ?? 1
                    DispatchQueue.main.async { proxy.scrollTo(nearest, anchor: UnitPoint(x: 0.5, y: 0.62)) }
                }
            }
        }
    }

    private func rateTitle(_ rate: Double) -> String {
        if abs(rate * 100 - (rate * 100).rounded()) < 0.001, abs(rate * 10 - (rate * 10).rounded()) >= 0.001 { return String(format: "%.2fx", rate) }
        return String(format: "%.1fx", rate)
    }
}

private struct PlayerPlaybackInfoFloatingPanel: View {
    let source: ResolvedPlaybackSource

    var body: some View {
        PlayerFloatingPanelChrome(width: 470, height: 318) {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 15) {
                    infoSection(title: "媒体", fields: mediaFields)
                    if !videoFields.isEmpty { Divider().background(Color.white.opacity(0.12)); infoSection(title: "视频", fields: videoFields) }
                    if !audioFields.isEmpty { Divider().background(Color.white.opacity(0.12)); infoSection(title: "音频", fields: audioFields) }
                }
                .padding(.horizontal, 18)
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
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.58))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 9) {
                ForEach(fields) { field in
                    HStack(spacing: 8) {
                        Text(field.title).foregroundColor(.white.opacity(0.58))
                        Spacer(minLength: 6)
                        Text(field.value).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.78)
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
