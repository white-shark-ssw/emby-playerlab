from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"::error::{label} not found")
    return text.replace(old, new, 1)


info = Path("Config/Info.plist")
text = info.read_text()
needle = "\t<key>UIApplicationSupportsIndirectInputEvents</key>\n\t<true/>\n"
if "CADisableMinimumFrameDurationOnPhone" not in text:
    text = replace_once(text, needle, needle + "\t<key>CADisableMinimumFrameDurationOnPhone</key>\n\t<true/>\n", "Info.plist ProMotion anchor")
info.write_text(text)

shared = Path("Sources/UI/EmbySharedImageAndNavigation.swift")
text = shared.read_text()
if "import ImageIO" not in text:
    text = replace_once(text, "import CoreImage\n", "import CoreImage\nimport ImageIO\n", "ImageIO import")

old = '''        task = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let loaded = UIImage(data: data) else { return }
                EmbyImageMemoryCache.shared.setObject(loaded, forKey: url as NSURL)
                await MainActor.run {
                    guard self?.currentURL == url else { return }
                    self?.image = loaded
                    self?.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.currentURL == url else { return }
                    self?.isLoading = false
                }
            }
        }
    }
}
'''
new = '''        task = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                let loaded = await Task.detached(priority: .utility) { EmbyImageDecoder.decode(data: data, url: url) }.value
                guard !Task.isCancelled, let loaded else { return }
                EmbyImageMemoryCache.shared.setObject(loaded, forKey: url as NSURL)
                await MainActor.run {
                    guard self?.currentURL == url else { return }
                    self?.image = loaded
                    self?.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.currentURL == url else { return }
                    self?.isLoading = false
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if image == nil { isLoading = false }
    }
}

private enum EmbyImageDecoder {
    static func decode(data: Data, url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return UIImage(data: data) }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let pixelHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        let requestedWidth = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name.caseInsensitiveCompare("MaxWidth") == .orderedSame }).flatMap { Double($0.value ?? "") }
        let sourceMax = max(pixelWidth, pixelHeight)
        let targetMax: Double
        if let requestedWidth, requestedWidth > 0, pixelWidth > 0, pixelHeight > 0 {
            let scale = min(1, requestedWidth / pixelWidth)
            targetMax = max(1, ceil(sourceMax * scale))
        } else {
            targetMax = max(1, sourceMax)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(targetMax),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return UIImage(data: data) }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
'''
if "private enum EmbyImageDecoder" not in text:
    text = replace_once(text, old, new, "image loader block")

old = '''    let placeholderSystemImage: String
    let onImageLoaded: ((UIImage) -> Void)?
    @StateObject private var loader = EmbyCachedImageLoader()
    @State private var reportedImageIdentifier: ObjectIdentifier?

    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String = "photo", onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.url = url
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
        self.onImageLoaded = onImageLoaded
    }
'''
new = '''    let placeholderSystemImage: String
    let showsLoadingIndicator: Bool
    let onImageLoaded: ((UIImage) -> Void)?
    @StateObject private var loader = EmbyCachedImageLoader()
    @State private var reportedImageIdentifier: ObjectIdentifier?

    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String = "photo", showsLoadingIndicator: Bool = true, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.url = url
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
        self.showsLoadingIndicator = showsLoadingIndicator
        self.onImageLoaded = onImageLoaded
    }
'''
if "let showsLoadingIndicator: Bool" not in text:
    text = replace_once(text, old, new, "remote image initializer")
text = text.replace("                if loader.isLoading { ProgressView() }", "                if showsLoadingIndicator && loader.isLoading { ProgressView() }", 1)
if ".onDisappear { loader.cancel() }" not in text:
    text = replace_once(text, "        .onAppear { loader.load(url) }\n        .onChange(of: url) {", "        .onAppear { loader.load(url) }\n        .onDisappear { loader.cancel() }\n        .onChange(of: url) {", "remote image disappear cancellation")
shared.write_text(text)

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift")
text = v3.read_text()
old = '''                        V3EmbyFavoritesView(client: client, onClose: close, dock: AnyView(serverTabBar))
                            .opacity(selectedTab == .favorites ? 1 : 0)
                            .allowsHitTesting(selectedTab == .favorites)
                            .accessibilityHidden(selectedTab != .favorites)

                        V3EmbySearchView(client: client, onClose: close, dock: AnyView(serverTabBar))
                            .opacity(selectedTab == .search ? 1 : 0)
                            .allowsHitTesting(selectedTab == .search)
                            .accessibilityHidden(selectedTab != .search)

                        V3EmbyServerSettingsView(session: session, onClose: close, dock: AnyView(serverTabBar))
                            .opacity(selectedTab == .settings ? 1 : 0)
                            .allowsHitTesting(selectedTab == .settings)
                            .accessibilityHidden(selectedTab != .settings)
'''
new = '''                        if selectedTab == .favorites { V3EmbyFavoritesView(client: client, onClose: close, dock: AnyView(serverTabBar)) }
                        if selectedTab == .search { V3EmbySearchView(client: client, onClose: close, dock: AnyView(serverTabBar)) }
                        if selectedTab == .settings { V3EmbyServerSettingsView(session: session, onClose: close, dock: AnyView(serverTabBar)) }
'''
if "if selectedTab == .favorites { V3EmbyFavoritesView" not in text:
    text = replace_once(text, old, new, "inactive tab pruning")
text = text.replace("            HStack(spacing: 12) {\n                ForEach(model.visibleLibraries)", "            LazyHStack(spacing: 12) {\n                ForEach(model.visibleLibraries)", 1)
text = text.replace("            HStack(spacing: 12) {\n                ForEach(items) { item in\n                    NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3LandscapeCard", "            LazyHStack(spacing: 12) {\n                ForEach(items) { item in\n                    NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3LandscapeCard", 1)
text = text.replace("            HStack(alignment: .top, spacing: 12) {\n                ForEach(items) { item in\n                    NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3PosterCard", "            LazyHStack(alignment: .top, spacing: 12) {\n                ForEach(items) { item in\n                    NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3PosterCard", 1)
old = '''private struct V3RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: "play.rectangle") }
}
'''
new = '''private struct V3RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: "play.rectangle", showsLoadingIndicator: false) }
}
'''
if "showsLoadingIndicator: false" not in text:
    text = replace_once(text, old, new, "V3 image loading indicator")
v3.write_text(text)

grid = Path("Sources/UI/EmbyPosterGrid.swift")
text = grid.read_text()
old = '''    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing) {
            ForEach(Array(items.enumerated()), id: \\.element.id) { index, item in
                content(item)
                    .environment(\\.embyPosterGridNavigationState, navigationState)
                    .environment(\\.embyPosterGridCellWidth, cellWidth)
                    .frame(width: cellWidth, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onAppear {
                        guard let handler = onApproachingEnd else { return }
                        let threshold = max(0, items.count - EmbyPosterGridMetrics.loadAheadItemCount)
                        if index >= threshold { handler() }
                    }
            }
        }
'''
new = '''    var body: some View {
        let loadAheadIDs = Set(items.suffix(EmbyPosterGridMetrics.loadAheadItemCount).map(\\.id))
        return LazyVGrid(columns: columns, alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing) {
            ForEach(items) { item in
                content(item)
                    .environment(\\.embyPosterGridNavigationState, navigationState)
                    .environment(\\.embyPosterGridCellWidth, cellWidth)
                    .frame(width: cellWidth, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onAppear {
                        guard let handler = onApproachingEnd, loadAheadIDs.contains(item.id) else { return }
                        handler()
                    }
            }
        }
'''
if "ForEach(Array(items.enumerated())" in text:
    text = replace_once(text, old, new, "poster grid enumeration")
grid.write_text(text)

checker = Path("scripts/check_scroll_performance.py")
checker.write_text('''from pathlib import Path\n\ninfo = Path("Config/Info.plist").read_text()\nshared = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text()\nv3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()\ngrid = Path("Sources/UI/EmbyPosterGrid.swift").read_text()\nproject = Path("project.yml").read_text()\n\nassert "<key>CADisableMinimumFrameDurationOnPhone</key>" in info\nassert "<true/>" in info.split("<key>CADisableMinimumFrameDurationOnPhone</key>", 1)[1][:80]\nassert "import ImageIO" in shared\nassert "CGImageSourceCreateThumbnailAtIndex" in shared\nassert "kCGImageSourceShouldCacheImmediately" in shared\nassert "Task.detached(priority: .utility)" in shared\nassert ".onDisappear { loader.cancel() }" in shared\nassert "showsLoadingIndicator" in shared\nassert v3.count("LazyHStack") >= 3\nassert "showsLoadingIndicator: false" in v3\nassert "if selectedTab == .favorites" in v3\nassert "if selectedTab == .search" in v3\nassert "if selectedTab == .settings" in v3\nassert "ForEach(Array(items.enumerated())" not in grid\nassert "let loadAheadIDs = Set(items.suffix" in grid\nassert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project\nprint("Scroll performance checks passed")\n''')
