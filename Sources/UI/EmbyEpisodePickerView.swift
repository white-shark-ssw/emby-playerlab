import SwiftUI

private struct EmbyEpisodeJump: Identifiable {
    let label: Int
    let episode: LibraryItem
    var id: String { episode.id }
}

struct EmbyEpisodePickerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: EmbyMediaDetailViewModel
    let client: EmbyAPIClient
    @State private var sortAscending = true
    @State private var lastHapticIndex: Int?
    @State private var lastHapticTime: TimeInterval = 0
    @State private var pickerHeroSourceSize: CGSize?
    @State private var pickerHeroRawScrollMinY: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top
            ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    ImmersiveBackdrop(url: pickerHeroURL, overlayOpacity: colorScheme == .dark ? 0.50 : 0.64)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                                pickerHero(width: geometry.size.width)
                                LazyVStack(spacing: 16) {
                                    ForEach(displayedEpisodes) { episode in episodeRow(episode).id(episode.id) }
                                }
                                .padding(.leading, 18)
                                .padding(.trailing, 48)
                                .padding(.top, 12)
                                .padding(.bottom, 92)
                        }
                        .frame(width: geometry.size.width)
                        .background(
                            AdaptiveHeroNativeScrollObserver { value in
                                if abs(pickerHeroRawScrollMinY - value) > 0.10 { pickerHeroRawScrollMinY = value }
                            }
                        )
                    }
                    .frame(width: geometry.size.width, height: viewportHeight)
                    .background(Color.clear)
                    .ignoresSafeArea(edges: [.top, .bottom])


                    let railHeight = min(590, viewportHeight * 0.72)
                    let railTop = max(126, viewportHeight * 0.13)
                    quickJumpRail(proxy: proxy)
                        .frame(width: ImmersiveUIMetrics.quickJumpHitWidth, height: railHeight)
                        .position(x: geometry.size.width - ImmersiveUIMetrics.quickJumpHitWidth / 2 - 4, y: railTop + railHeight / 2)
                        .zIndex(30)
                }
                .frame(width: geometry.size.width, height: viewportHeight, alignment: .top)
                .ignoresSafeArea(edges: [.top, .bottom])
                .onAppear { DiagnosticsLogger.shared.log("ImmersiveViewport", "page=episode-picker geometry=\(geometry.size) safe=\(geometry.safeAreaInsets) viewportHeight=\(viewportHeight)") }
            }
        }
        .navigationBarHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { sortAscending.toggle(); DetailHaptics.selection() } label: {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.50))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sortAscending ? "改为倒序" : "改为正序")
            }
        }
        .immersiveSystemNavigationAppearance()
        .nativeInteractivePop()
        .detailPagePresentation()
    }

    private var displayedEpisodes: [LibraryItem] {
        sortAscending ? model.selectedSeasonEpisodes : Array(model.selectedSeasonEpisodes.reversed())
    }

    private var quickJumps: [EmbyEpisodeJump] {
        let items = displayedEpisodes
        guard !items.isEmpty else { return [] }
        let step = max(1, Int(ceil(Double(max(0, items.count - 1)) / 29.0)))
        var offsets = Array(stride(from: 0, to: items.count, by: step))
        if offsets.last != items.count - 1 { offsets.append(items.count - 1) }
        return offsets.map { offset in EmbyEpisodeJump(label: items[offset].indexNumber ?? offset + 1, episode: items[offset]) }
    }

    private func pickerHero(width: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.compactBaseHeight(width: width)
        let heroViewport = CGSize(width: width, height: baseHeight)
        let cropTravel = AdaptiveHeroRevealMetrics.cropTravel(imageSize: pickerHeroSourceSize, viewportSize: heroViewport)
        let stretch = max(0, pickerHeroRawScrollMinY)
        let upwardScroll = max(0, -pickerHeroRawScrollMinY)
        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel)
        let visualHeight = baseHeight + stretch
        let renderedImageSize = stretch > 0 ? AdaptiveHeroRevealMetrics.stretchedImageSize(imageSize: pickerHeroSourceSize, viewportSize: CGSize(width: width, height: visualHeight)) : AdaptiveHeroRevealMetrics.renderedImageSize(imageSize: pickerHeroSourceSize, viewportSize: heroViewport, consumedCropScroll: consumedCropScroll)
        let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedImageSize, viewportHeight: visualHeight)
        let maskFadeSpan = min(0.67, clearImageBottom * 0.67)
        let maskStart = max(0.08, clearImageBottom - maskFadeSpan)
        let maskMid = maskStart + (clearImageBottom - maskStart) * 0.50

        return ZStack(alignment: .bottomLeading) {
            ZStack(alignment: .top) {
                EmbyCachedRemoteImage(url: pickerHeroURL, contentMode: .fill, onImageLoaded: { image in
                    if pickerHeroSourceSize != image.size { pickerHeroSourceSize = image.size }
                })
                .frame(width: renderedImageSize.width, height: renderedImageSize.height)
            }
            .frame(width: width, height: visualHeight, alignment: .top)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.00),
                        .init(color: .black, location: maskStart),
                        .init(color: .black.opacity(0.80), location: maskMid),
                        .init(color: .clear, location: clearImageBottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(model.item.name).font(.headline).lineLimit(1)
                Text(model.selectedSeasonTitle).font(.title2.weight(.bold))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: visualHeight)
        .offset(y: stretch > 0 ? -stretch : consumedCropScroll)
        .frame(width: width, height: baseHeight + consumedCropScroll, alignment: .top)
    }

    private var pickerHeroURL: URL? {
        if !model.item.backdropImageTags.isEmpty { return client.imageURL(itemId: model.item.id, imageType: "Backdrop", maxWidth: 1600, tag: model.item.backdropImageTags.first, index: 0) }
        if let season = model.selectedSeason, let seasonItem = model.seasonItem(number: season) { return client.imageURL(itemId: seasonItem.preferredPrimaryImageItemId, maxWidth: 1000, tag: seasonItem.preferredPrimaryImageTag) }
        return client.imageURL(itemId: model.item.preferredPrimaryImageItemId, maxWidth: 1200, tag: model.item.preferredPrimaryImageTag)
    }

    private func quickJumpRail(proxy: ScrollViewProxy) -> some View {
        GeometryReader { geometry in
            let jumps = quickJumps
            ZStack(alignment: .trailing) {
                Color.clear.contentShape(Rectangle())
                if !jumps.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(jumps.enumerated()), id: \.element.id) { _, jump in
                            Text(String(jump.label))
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .frame(width: geometry.size.width, height: geometry.size.height / CGFloat(jumps.count), alignment: .trailing)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !jumps.isEmpty, geometry.size.height > 0 else { return }
                        let fraction = min(0.999, max(0, value.location.y / geometry.size.height))
                        let index = min(jumps.count - 1, max(0, Int(fraction * CGFloat(jumps.count))))
                        proxy.scrollTo(jumps[index].episode.id, anchor: .top)
                        emitRailHaptic(index: index)
                    }
            )
        }
    }

    private func emitRailHaptic(index: Int) {
        guard index != lastHapticIndex else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastHapticTime >= 0.010 else { return }
        lastHapticIndex = index
        lastHapticTime = now
        DetailHaptics.selection()
    }

    private func episodeRow(_ episode: LibraryItem) -> some View {
        let overview = model.normalizedOverview(for: episode) ?? ""
        return Button {
            presentationMode.wrappedValue.dismiss()
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await model.play(episode)
            }
        } label: {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    AsyncImage(url: client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 620, tag: episode.preferredPrimaryImageTag)) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        default: Color(uiColor: .secondarySystemBackground)
                        }
                    }
                    .frame(width: 132, height: 76)
                    .clipped()
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .bold)).foregroundColor(.white).frame(width: 32, height: 32).background(Color.black.opacity(0.48)).clipShape(Circle())
                }
                .frame(width: 132, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.displayEpisodeTitle(episode))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(overview.isEmpty ? " " : overview)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary.opacity(0.72))
                        .lineLimit(3)
                        .lineSpacing(1.5)
                        .frame(maxWidth: .infinity, minHeight: 43, alignment: .topLeading)
                        .opacity(overview.isEmpty ? 0 : 1)
                    if overview.isEmpty {
                        HStack(spacing: 6) {
                            if let date = episode.premiereDate, date.count >= 10 { Text(String(date.prefix(10))) }
                            else if let year = episode.productionYear { Text(String(year)) }
                            if let duration = episode.durationSeconds { Text("·"); Text(formatDuration(duration)) }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours)小时\(minutes)分钟" : "\(hours)小时" }
        return "\(minutes)分钟"
    }
}
