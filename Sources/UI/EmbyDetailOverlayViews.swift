import SwiftUI
import UIKit

struct EmbyOverviewOverlayView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let backdropURL: URL?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ImmersiveBackdrop(url: backdropURL, overlayOpacity: colorScheme == .dark ? 0.44 : 0.56, blurRadius: 60)
                Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { presentationMode.wrappedValue.dismiss() }

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button { presentationMode.wrappedValue.dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 34, height: 34)
                                .background(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(DetailPressButtonStyle())
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    ScrollView(.vertical, showsIndicators: false) {
                        Text(text)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 22)
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                    }
                }
                .frame(width: max(280, geometry.size.width - 62), height: min(620, geometry.size.height * 0.62))
                .background(Color(uiColor: .secondarySystemBackground).opacity(colorScheme == .dark ? 0.98 : 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 26, x: 0, y: 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}

struct EmbyStillViewerPresenter: UIViewControllerRepresentable {
    @Binding var selectedIndex: Int?
    let images: [EmbyImageInfo]
    let itemId: String
    let client: EmbyAPIClient

    final class Coordinator {
        weak var host: UIViewController?

        func dismiss() {
            guard let host else { return }
            host.dismiss(animated: false)
            self.host = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard let index = selectedIndex, !images.isEmpty else {
            context.coordinator.dismiss()
            return
        }
        guard context.coordinator.host == nil else { return }

        let binding = $selectedIndex
        let coordinator = context.coordinator
        let viewer = EmbyStillViewer(images: images, initialIndex: index, itemId: itemId, client: client) {
            binding.wrappedValue = nil
            coordinator.dismiss()
        }
        let host = UIHostingController(rootView: viewer)
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        coordinator.host = host
        DispatchQueue.main.async {
            guard viewController.presentedViewController == nil else { return }
            viewController.present(host, animated: false)
        }
    }
}

private struct EmbyStillViewer: View {
    let images: [EmbyImageInfo]
    let initialIndex: Int
    let itemId: String
    let client: EmbyAPIClient
    let onDismiss: () -> Void
    @State private var currentIndex: Int
    @State private var verticalOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var isDismissing = false

    init(images: [EmbyImageInfo], initialIndex: Int, itemId: String, client: EmbyAPIClient, onDismiss: @escaping () -> Void) {
        self.images = images
        self.initialIndex = min(max(0, initialIndex), max(0, images.count - 1))
        self.itemId = itemId
        self.client = client
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: min(max(0, initialIndex), max(0, images.count - 1)))
    }

    var body: some View {
        GeometryReader { geometry in
            let progress = min(1, max(0, verticalOffset / max(1, geometry.size.height * 0.72)))
            ZStack(alignment: .topLeading) {
                Color.black.opacity((1 - progress) * 0.96).ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, info in
                        AsyncImage(url: client.imageURL(itemId: itemId, imageType: info.imageType, maxWidth: 2400, index: info.imageIndex)) { phase in
                            switch phase {
                            case .success(let image): image.resizable().aspectRatio(contentMode: .fit)
                            case .failure: Color.clear.overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.white.opacity(0.55)))
                            case .empty: ZStack { Color.clear; ProgressView().tint(.white) }
                            @unknown default: Color.clear
                            }
                        }
                        .frame(width: max(0, geometry.size.width - 24), height: geometry.size.height)
                        .padding(.horizontal, 12)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .offset(y: verticalOffset)
                .opacity(1 - progress * 0.72)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard !isDismissing, value.translation.height > 0, abs(value.translation.height) > abs(value.translation.width) else { return }
                            verticalOffset = value.translation.height
                        }
                        .onEnded { value in
                            guard !isDismissing else { return }
                            if verticalOffset > 105 || value.predictedEndTranslation.height > 220 {
                                animateDismiss(height: geometry.size.height)
                            } else {
                                withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) { verticalOffset = 0 }
                            }
                        }
                )

                Button { animateDismiss(height: geometry.size.height) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: ImmersiveUIMetrics.topControlVisualSize, height: ImmersiveUIMetrics.topControlVisualSize)
                        .background(Color.black.opacity(0.52))
                        .clipShape(Circle())
                        .frame(width: ImmersiveUIMetrics.topControlHitSize, height: ImmersiveUIMetrics.topControlHitSize)
                }
                .buttonStyle(DetailPressButtonStyle())
                .padding(.leading, 14)
                .padding(.top, currentWindowTopInset + ImmersiveUIMetrics.topControlPadding)
                .opacity(1 - progress)
                .zIndex(10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.11)) { isVisible = true }
            }
        }
        .ignoresSafeArea()
    }

    private var currentWindowTopInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })
        return window?.safeAreaInsets.top ?? 0
    }

    private func animateDismiss(height: CGFloat) {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(.easeIn(duration: 0.17)) {
            verticalOffset = max(height, 1)
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onDismiss() }
    }
}
