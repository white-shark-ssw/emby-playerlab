import SwiftUI
import UIKit

struct PlayerPlaybackSettingsPopover: View {
    @Binding var isPresented: Bool
    @Binding var motionSmoothingRaw: String
    @Binding var videoEnhancementEnabled: Bool
    let onPreferencesChanged: () -> Void

    @State private var page: Page = .root
    @State private var appeared = false

    private enum Page { case root, motionSmoothing }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismiss)

                popover
                    .padding(.trailing, 18)
                    .padding(.bottom, 58)
                    .scaleEffect(appeared ? 1 : 0.96, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 5, y: appeared ? 0 : 5)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            page = .root
            withAnimation(.easeOut(duration: 0.20)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    private var popover: some View {
        ZStack {
            rootPage
                .opacity(page == .root ? 1 : 0)
                .offset(x: page == .root ? 0 : -18)
                .allowsHitTesting(page == .root)

            motionPage
                .opacity(page == .motionSmoothing ? 1 : 0)
                .offset(x: page == .motionSmoothing ? 0 : 18)
                .allowsHitTesting(page == .motionSmoothing)
        }
        .animation(.easeInOut(duration: 0.20), value: page)
        .frame(width: 258)
        .background(PlayerPlaybackSettingsGlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.13), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { }
    }

    private var rootPage: some View {
        VStack(spacing: 0) {
            header("播放设置")
            separator
            actionRow(title: "超画", systemImage: "sparkles", leadingCheck: videoEnhancementEnabled) {
                videoEnhancementEnabled.toggle()
                onPreferencesChanged()
            }
            separator
            actionRow(title: "运动平滑", systemImage: "waveform.path", trailingChevron: true) {
                page = .motionSmoothing
            }
        }
    }

    private var motionPage: some View {
        VStack(spacing: 0) {
            Button { page = .root } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("运动平滑").font(.system(size: 16, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(MotionSmoothingMode.allCases) { mode in
                separator
                Button {
                    motionSmoothingRaw = mode.rawValue
                    onPreferencesChanged()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .opacity(currentMotionMode == mode ? 1 : 0)
                            .frame(width: 18)
                        Text(mode.title).font(.system(size: 17, weight: .regular))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func header(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(.white.opacity(0.62))
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
    }

    private func actionRow(title: String, systemImage: String, leadingCheck: Bool = false, trailingChevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if leadingCheck { Image(systemName: "checkmark") }
                    else { Color.clear.frame(width: 1, height: 1) }
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 18)
                Text(title).font(.system(size: 17, weight: .regular))
                Spacer()
                if trailingChevron { Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.72)) }
                Image(systemName: systemImage).font(.system(size: 17, weight: .medium)).frame(width: 22)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var separator: some View { Rectangle().fill(Color.white.opacity(0.13)).frame(height: 0.5) }
    private var currentMotionMode: MotionSmoothingMode { MotionSmoothingMode(rawValue: motionSmoothingRaw) ?? .automatic }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.16)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { isPresented = false }
    }
}

private struct PlayerPlaybackSettingsGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        view.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
