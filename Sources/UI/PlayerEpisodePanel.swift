import SwiftUI

struct PlayerEpisodePanel: View {
    let seriesName: String?
    let episodes: [LibraryItem]
    let currentItemID: String
    let switchingItemID: String?
    let imageURL: (LibraryItem) -> URL?
    let onSelect: (LibraryItem) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.48).ignoresSafeArea().contentShape(Rectangle()).onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("选集").font(.system(size: 18, weight: .bold))
                        if let seriesName, !seriesName.isEmpty { Text(seriesName).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.58)).lineLimit(1) }
                    }
                    Spacer()
                    Button(action: onDismiss) { Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).frame(width: 34, height: 34).background(Color.white.opacity(0.10)).clipShape(Circle()) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭选集")
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(episodes) { episode in episodeCard(episode).id(episode.id) }
                        }
                        .padding(.horizontal, 1)
                    }
                    .onAppear { DispatchQueue.main.async { proxy.scrollTo(currentItemID, anchor: .center) } }
                    .onChange(of: currentItemID) { itemID in withAnimation(.easeOut(duration: 0.20)) { proxy.scrollTo(itemID, anchor: .center) } }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, height: 220, alignment: .top)
            .background(Color.black.opacity(0.94))
            .overlay(Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5), alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func episodeCard(_ episode: LibraryItem) -> some View {
        let current = episode.id == currentItemID
        let switching = episode.id == switchingItemID
        return Button {
            if !current && switchingItemID == nil { onSelect(episode) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let url = imageURL(episode) {
                            EmbyCachedRemoteImage(url: url, contentMode: .fill)
                        } else {
                            Rectangle().fill(Color.white.opacity(0.08)).overlay(Image(systemName: "film").font(.system(size: 25)).foregroundColor(.white.opacity(0.42)))
                        }
                    }
                    .frame(width: 178, height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if current {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.right.2").font(.system(size: 13, weight: .bold))
                            Text("正在播放").font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.58))
                        .clipShape(Capsule())
                        .padding(8)
                    } else if switching {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).padding(10).background(Color.black.opacity(0.58)).clipShape(Circle()).padding(8)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(current ? Color.white : Color.white.opacity(0.10), lineWidth: current ? 2 : 0.5))

                Text(episodeIndexTitle(episode)).font(.system(size: 14, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text(episode.name).font(.system(size: 12.5, weight: .regular)).foregroundColor(.white.opacity(0.58)).lineLimit(1).frame(width: 178, alignment: .leading)
            }
            .frame(width: 178, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(current || (switchingItemID != nil && !switching))
        .opacity(switchingItemID != nil && !current && !switching ? 0.55 : 1)
        .accessibilityLabel(episodeAccessibilityTitle(episode, current: current))
    }

    private func episodeIndexTitle(_ episode: LibraryItem) -> String {
        if let season = episode.parentIndexNumber, let number = episode.indexNumber { return "S\(season) E\(number)" }
        if let number = episode.indexNumber { return "E\(number)" }
        return "剧集"
    }

    private func episodeAccessibilityTitle(_ episode: LibraryItem, current: Bool) -> String {
        let prefix = episodeIndexTitle(episode)
        return current ? "\(prefix) \(episode.name)，正在播放" : "\(prefix) \(episode.name)"
    }
}
