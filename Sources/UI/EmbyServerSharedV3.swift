import SwiftUI
import Combine
import UIKit

final class V3HomeNativeScrollProbeView: UIView {
    var hierarchyDidChange: ((UIView) -> Void)?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        hierarchyDidChange?(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        hierarchyDidChange?(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hierarchyDidChange?(self)
    }
}

struct V3HomeNativeScrollObserver: UIViewRepresentable {
    let isRefreshing: Bool
    let onOffsetChanged: (CGFloat) -> Void
    let onRefresh: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(isRefreshing: isRefreshing, onOffsetChanged: onOffsetChanged, onRefresh: onRefresh) }

    func makeUIView(context: Context) -> V3HomeNativeScrollProbeView {
        let view = V3HomeNativeScrollProbeView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: V3HomeNativeScrollProbeView, context: Context) {
        context.coordinator.update(isRefreshing: isRefreshing, onOffsetChanged: onOffsetChanged, onRefresh: onRefresh)
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: V3HomeNativeScrollProbeView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach()
    }

    final class Coordinator: NSObject {
        private var isRefreshing: Bool
        private var onOffsetChanged: (CGFloat) -> Void
        private var onRefresh: () -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private let refreshControl = UIRefreshControl()

        init(isRefreshing: Bool, onOffsetChanged: @escaping (CGFloat) -> Void, onRefresh: @escaping () -> Void) {
            self.isRefreshing = isRefreshing
            self.onOffsetChanged = onOffsetChanged
            self.onRefresh = onRefresh
            super.init()
            refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        }

        func update(isRefreshing: Bool, onOffsetChanged: @escaping (CGFloat) -> Void, onRefresh: @escaping () -> Void) {
            self.isRefreshing = isRefreshing
            self.onOffsetChanged = onOffsetChanged
            self.onRefresh = onRefresh
            synchronizeRefreshControl()
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            if self.scrollView !== scrollView {
                contentOffsetObservation?.invalidate()
                self.scrollView = scrollView
                scrollView.alwaysBounceVertical = true
                if scrollView.refreshControl == nil || scrollView.refreshControl === refreshControl { scrollView.refreshControl = refreshControl }
                contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
            } else {
                emit(scrollView)
            }
            synchronizeRefreshControl()
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            if scrollView?.refreshControl === refreshControl { scrollView?.refreshControl = nil }
            scrollView = nil
        }

        @objc private func refreshTriggered() { onRefresh() }

        private func ancestorVerticalScrollView(from probe: UIView) -> UIScrollView? {
            var current: UIView? = probe
            while let view = current {
                if let scrollView = view as? UIScrollView, !scrollView.isPagingEnabled { return scrollView }
                current = view.superview
            }
            return nil
        }

        private func emit(_ scrollView: UIScrollView) {
            let rawDisplacement = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            if Thread.isMainThread { onOffsetChanged(rawDisplacement) }
            else { DispatchQueue.main.async { [weak self] in self?.onOffsetChanged(rawDisplacement) } }
        }

        private func synchronizeRefreshControl() {
            guard !isRefreshing else { return }
            if refreshControl.isRefreshing { refreshControl.endRefreshing() }
        }
    }
}

struct V3PageHeader: View {
    let title: String
    let onClose: () -> Void
    var body: some View {
        HStack {
            Spacer().frame(width: 36)
            Spacer()
            Text(title).font(.title2.weight(.bold))
            Spacer()
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary).frame(width: 36, height: 36).background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle()) }
        }
        .padding(.horizontal, 16)
        .padding(.top, 5)
    }
}

struct V3LibraryTile: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    var body: some View {
        VStack(spacing: 6) {
            V3RemoteImage(url: client.imageURL(itemId: item.id, maxWidth: 480, tag: item.primaryImageTag), contentMode: .fill).frame(width: 164, height: 92).clipped().clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name).font(.subheadline.weight(.medium)).foregroundColor(.primary).lineLimit(1).frame(width: 164)
        }
    }
}

struct V3LandscapeCard: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomLeading) {
                V3RemoteImage(url: client.imageURL(itemId: item.id, imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop", maxWidth: 650, tag: item.backdropImageTags.first ?? item.primaryImageTag), contentMode: .fill).frame(width: 212, height: 120).clipped()
                if item.playbackProgress > 0 { GeometryReader { proxy in VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) } } }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(1).frame(width: 212, alignment: .leading)
            Text(v3MediaSubtitle(item)).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
    }
}

struct V3PosterCard: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient
    let width: CGFloat?

    private var resolvedWidth: CGFloat { width ?? gridCellWidth ?? 118 }
    private var posterHeight: CGFloat { floor(resolvedWidth / EmbyPosterGridMetrics.posterAspectRatio) }
    private var posterImageMaxWidth: Int {
        guard width == nil else { return 440 }
        let available = UIScreen.main.bounds.width - EmbyPosterGridMetrics.horizontalPadding * 2 - EmbyPosterGridMetrics.columnSpacing * CGFloat(EmbyPosterGridMetrics.columnCount - 1)
        let gridWidth = floor(max(1, available) / CGFloat(EmbyPosterGridMetrics.columnCount))
        return min(440, max(1, Int(ceil(gridWidth * UIScreen.main.scale))))
    }
    private var yearText: String { item.productionYear.map(String.init) ?? " " }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                V3RemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: posterImageMaxWidth, tag: item.preferredPrimaryImageTag), contentMode: .fill)
                    .frame(width: resolvedWidth, height: posterHeight)
                    .clipped()
                if item.playbackProgress > 0 { GeometryReader { proxy in VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) } } }
                if let count = item.userData?.unplayedItemCount, count > 0 {
                    VStack { HStack { Spacer(); Text("\(count)").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.blue).clipShape(Circle()) }; Spacer() }.padding(5)
                } else if item.isPlayed {
                    VStack { HStack { Spacer(); Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.green).clipShape(Circle()) }; Spacer() }.padding(5)
                }
            }
            .frame(width: resolvedWidth, height: posterHeight)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).lineLimit(1).frame(width: resolvedWidth, height: 20, alignment: .leading)
                Text(yearText).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: resolvedWidth, height: 16, alignment: .leading).opacity(item.productionYear == nil ? 0 : 1)
            }
            .frame(width: resolvedWidth, height: 38, alignment: .topLeading)
        }
        .frame(width: resolvedWidth, alignment: .leading)
    }
}

struct V3RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: "play.rectangle", showsLoadingIndicator: false) }
}

func v3MediaSubtitle(_ item: LibraryItem) -> String {
    if let seriesName = item.seriesName, let season = item.parentIndexNumber, let episode = item.indexNumber { return "\(seriesName) · S\(season):E\(episode)" }
    if let year = item.productionYear { return String(year) }
    return item.type ?? ""
}

func v3MediaTypeTitle(_ item: LibraryItem) -> String {
    switch item.type?.lowercased() {
    case "movie": return "电影"
    case "series": return "剧集"
    case "episode": return "剧集"
    case "video": return "视频"
    default: return item.type ?? ""
    }
}

func v3CollectionTypeTitle(_ value: String) -> String {
    switch value.lowercased() {
    case "movies": return "电影"
    case "tvshows": return "电视剧"
    case "music": return "音乐"
    case "homevideos": return "家庭视频"
    case "mixed": return "混合内容"
    default: return value
    }
}
