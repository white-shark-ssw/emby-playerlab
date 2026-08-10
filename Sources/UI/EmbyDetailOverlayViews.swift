import SwiftUI

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

                    ScrollView(.vertical, showsIndicators: true) {
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
                .background(Color(uiColor: .secondarySystemBackground).opacity(colorScheme == .dark ? 0.97 : 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 26, x: 0, y: 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}

struct EmbyStillViewer: View {
    @Environment(\.presentationMode) private var presentationMode
    let images: [EmbyImageInfo]
    let initialIndex: Int
    let itemId: String
    let client: EmbyAPIClient
    @State private var currentIndex: Int
    @State private var verticalOffset: CGFloat = 0

    init(images: [EmbyImageInfo], initialIndex: Int, itemId: String, client: EmbyAPIClient) {
        self.images = images
        self.initialIndex = min(max(0, initialIndex), max(0, images.count - 1))
        self.itemId = itemId
        self.client = client
        _currentIndex = State(initialValue: min(max(0, initialIndex), max(0, images.count - 1)))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(max(0.34, 1 - Double(abs(verticalOffset) / max(1, geometry.size.height)))).ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, info in
                        AsyncImage(url: client.imageURL(itemId: itemId, imageType: info.imageType, maxWidth: 2400, index: info.imageIndex)) { phase in
                            switch phase {
                            case .success(let image): image.resizable().aspectRatio(contentMode: .fit)
                            case .failure: Color.black.overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.white.opacity(0.55)))
                            case .empty: ZStack { Color.black; ProgressView().tint(.white) }
                            @unknown default: Color.black
                            }
                        }
                        .frame(width: geometry.size.width - 18, height: geometry.size.height)
                        .padding(.horizontal, 9)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .offset(y: verticalOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard value.translation.height > 0, abs(value.translation.height) > abs(value.translation.width) else { return }
                            verticalOffset = value.translation.height
                        }
                        .onEnded { value in
                            if verticalOffset > 105 || value.predictedEndTranslation.height > 220 {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) { verticalOffset = 0 }
                            }
                        }
                )

                Button { presentationMode.wrappedValue.dismiss() } label: {
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
                .padding(.top, geometry.safeAreaInsets.top + ImmersiveUIMetrics.topControlPadding)
                .zIndex(10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
