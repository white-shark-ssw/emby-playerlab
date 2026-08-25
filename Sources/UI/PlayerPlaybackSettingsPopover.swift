import SwiftUI
import UIKit

struct PlayerPlaybackSettingsPopover: View {
    @Binding var isPresented: Bool
    @Binding var motionSmoothingRaw: String
    @Binding var videoEnhancementEnabled: Bool
    let onPreferencesChanged: () -> Void

    @State private var page: Page = .root
    @State private var appeared = false

    private enum Page: Equatable { case root, motionSmoothing }
    private let rootHeight: CGFloat = 139
    private let motionHeight: CGFloat = 224
    private let forwardPageAnimation = Animation.timingCurve(0.20, 0.82, 0.24, 1, duration: 0.20)
    private let backwardPageAnimation = Animation.easeOut(duration: 0.17)

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
                    .scaleEffect(appeared ? 1 : 0.98, anchor: .bottomTrailing)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 3, y: appeared ? 0 : 3)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            page = .root
            withAnimation(.easeOut(duration: 0.18)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    private var popover: some View {
        ZStack(alignment: .bottomTrailing) {
            panel(rootPage, height: rootHeight)
                .scaleEffect(page == .root ? 1 : 0.985, anchor: .bottomTrailing)
                .opacity(page == .root ? 1 : 0.30)
                .offset(x: page == .root ? 0 : -4)
                .allowsHitTesting(page == .root)

            if page == .motionSmoothing {
                panel(motionPage, height: motionHeight)
                    .transition(submenuTransition)
                    .zIndex(2)
            }
        }
        .frame(width: 258, height: motionHeight, alignment: .bottomTrailing)
    }

    private var submenuTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 10, y: 2)).combined(with: .scale(scale: 0.985, anchor: .bottomTrailing)),
            removal: .opacity.combined(with: .offset(x: 6, y: 2)).combined(with: .scale(scale: 0.99, anchor: .bottomTrailing))
        )
    }

    private func panel<Content: View>(_ content: Content, height: CGFloat) -> some View {
        content
            .frame(width: 258, height: height, alignment: .bottom)
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
            }
            separator
            actionRow(title: "运动平滑", systemImage: "waveform.path", trailingChevron: true, action: showMotionSmoothing)
        }
    }

    private var motionPage: some View {
        VStack(spacing: 0) {
            Button(action: showRoot) {
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
    private var currentMotionMode: MotionSmoothingMode { MotionSmoothingMode(rawValue: motionSmoothingRaw) ?? .off }

    private func showMotionSmoothing() { withAnimation(forwardPageAnimation) { page = .motionSmoothing } }
    private func showRoot() { withAnimation(backwardPageAnimation) { page = .root } }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isPresented = false }
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
