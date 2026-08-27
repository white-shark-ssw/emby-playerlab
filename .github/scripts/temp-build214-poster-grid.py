from pathlib import Path


def replace_exact(path: str, old: str, new: str, expected: int = 1) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} occurrence(s), found {count}: {old[:120]}")
    file.write_text(text.replace(old, new), encoding="utf-8")


identity = Path("Sources/Core/AppIdentity.swift")
text = identity.read_text(encoding="utf-8")
old_identity = '    static let sourceVersion = "0.14.46"\n    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.14.46"'
new_identity = '    static let sourceVersion = "0.14.49"\n    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.14.49"'
if text.count(old_identity) != 1:
    raise SystemExit("Build213 AppIdentity anchor mismatch")
identity.write_text(text.replace(old_identity, new_identity), encoding="utf-8")

source = Path("Sources/UI/EmbySharedImageAndNavigation.swift")
text = source.read_text(encoding="utf-8")
anchor = "struct EmbyCachedRemoteImage: View {\n"
insertion = r'''private final class EmbyCachedDisplayImageSurfaceView: UIView {
    let imageView = UIImageView(frame: .zero)
    let placeholderView = UIImageView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        isUserInteractionEnabled = false
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        placeholderView.contentMode = .center
        placeholderView.frame = bounds
        placeholderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(placeholderView)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { nil }

    func configure(contentMode: ContentMode, placeholderSystemImage: String) {
        imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        placeholderView.image = UIImage(systemName: placeholderSystemImage, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium))
        placeholderView.tintColor = UIColor.secondaryLabel.withAlphaComponent(0.62)
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
        placeholderView.isHidden = image != nil
    }
}

private struct EmbyCachedDisplayImageSurface: UIViewRepresentable {
    let loader: EmbyCachedImageLoader
    let contentMode: ContentMode
    let placeholderSystemImage: String

    func makeCoordinator() -> Coordinator { Coordinator(loader: loader) }

    func makeUIView(context: Context) -> EmbyCachedDisplayImageSurfaceView {
        let view = EmbyCachedDisplayImageSurfaceView(frame: .zero)
        view.configure(contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ uiView: EmbyCachedDisplayImageSurfaceView, context: Context) {
        uiView.configure(contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
    }

    static func dismantleUIView(_ uiView: EmbyCachedDisplayImageSurfaceView, coordinator: Coordinator) { coordinator.detach() }

    final class Coordinator {
        private let loader: EmbyCachedImageLoader
        private weak var surface: EmbyCachedDisplayImageSurfaceView?
        private var imageCancellable: AnyCancellable?

        init(loader: EmbyCachedImageLoader) {
            self.loader = loader
            imageCancellable = loader.$image.sink { [weak self] image in self?.surface?.setImage(image) }
        }

        func attach(_ surface: EmbyCachedDisplayImageSurfaceView) {
            self.surface = surface
            surface.setImage(loader.image)
        }

        func detach() {
            surface = nil
            imageCancellable?.cancel()
            imageCancellable = nil
        }
    }
}

private struct EmbyCachedDisplayRemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholderSystemImage: String
    @State private var loader: EmbyCachedImageLoader

    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String) {
        self.url = url
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
        _loader = State(initialValue: EmbyCachedImageLoader(initialURL: url))
    }

    var body: some View {
        EmbyCachedDisplayImageSurface(loader: loader, contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
            .onAppear { loader.load(url, reportsLoadingState: false, diagnosticRole: "display") }
            .onDisappear { loader.cancel(reportsLoadingState: false) }
            .onChange(of: url) { loader.load($0, reportsLoadingState: false, diagnosticRole: "display") }
    }
}

struct EmbyCachedRemoteImage: View {
'''
if text.count(anchor) != 1:
    raise SystemExit("EmbyCachedRemoteImage anchor mismatch")
text = text.replace(anchor, insertion)

old_init = '        _loader = StateObject(wrappedValue: EmbyCachedImageLoader(initialURL: onImageLoaded == nil ? url : nil))\n'
new_init = '        _loader = StateObject(wrappedValue: EmbyCachedImageLoader(initialURL: onImageLoaded == nil && showsLoadingIndicator ? url : nil))\n'
if text.count(old_init) != 1:
    raise SystemExit("loader init anchor mismatch")
text = text.replace(old_init, new_init)

old_body = r'''    var body: some View {
        if let onImageLoaded {
            imageBody.onReceive(loader.$image.compactMap { $0 }) { image in
                let identifier = ObjectIdentifier(image)
                guard reportedImageIdentifier != identifier else { return }
                reportedImageIdentifier = identifier
                let startedAt = CACurrentMediaTime()
                onImageLoaded(image)
                let durationMS = (CACurrentMediaTime() - startedAt) * 1000
                let publishContext = loader.lastPublishContext
                EmbyPosterScrollHitchDiagnostics.shared.imageCallbackDidComplete(url: publishContext?.url ?? url, source: publishContext?.source ?? "unknown", durationMS: durationMS)
            }
        } else {
            imageBody
        }
    }
'''
new_body = r'''    var body: some View {
        if onImageLoaded == nil && !showsLoadingIndicator {
            EmbyCachedDisplayRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
        } else if let onImageLoaded {
            imageBody.onReceive(loader.$image.compactMap { $0 }) { image in
                let identifier = ObjectIdentifier(image)
                guard reportedImageIdentifier != identifier else { return }
                reportedImageIdentifier = identifier
                let startedAt = CACurrentMediaTime()
                onImageLoaded(image)
                let durationMS = (CACurrentMediaTime() - startedAt) * 1000
                let publishContext = loader.lastPublishContext
                EmbyPosterScrollHitchDiagnostics.shared.imageCallbackDidComplete(url: publishContext?.url ?? url, source: publishContext?.source ?? "unknown", durationMS: durationMS)
            }
        } else {
            imageBody
        }
    }
'''
if text.count(old_body) != 1:
    raise SystemExit("EmbyCachedRemoteImage body anchor mismatch")
text = text.replace(old_body, new_body)
source.write_text(text, encoding="utf-8")

checker = Path("scripts/check_poster_grid_smoothness.py")
text = checker.read_text(encoding="utf-8")
home_read = 'home_source = Path("Sources/UI/EmbyHomeCoreV3.swift").read_text(encoding="utf-8")\n'
if text.count(home_read) != 1:
    raise SystemExit("checker Home-source anchor mismatch")
text = text.replace(home_read, "")

old_req = r'''    "_loader = StateObject(wrappedValue: EmbyCachedImageLoader(initialURL: onImageLoaded == nil ? url : nil))",
    "if let onImageLoaded {\n            imageBody.onReceive(loader.$image.compactMap { $0 })",
    "} else {\n            imageBody\n        }",
'''
new_req = r'''    "_loader = StateObject(wrappedValue: EmbyCachedImageLoader(initialURL: onImageLoaded == nil && showsLoadingIndicator ? url : nil))",
    "private final class EmbyCachedDisplayImageSurfaceView: UIView",
    "private struct EmbyCachedDisplayRemoteImage: View",
    "@State private var loader: EmbyCachedImageLoader",
    "_loader = State(initialValue: EmbyCachedImageLoader(initialURL: url))",
    "EmbyCachedDisplayImageSurface(loader: loader, contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)",
    "imageCancellable = loader.$image.sink",
    "if onImageLoaded == nil && !showsLoadingIndicator {",
    "if let onImageLoaded {\n            imageBody.onReceive(loader.$image.compactMap { $0 })",
'''
if text.count(old_req) != 1:
    raise SystemExit("checker required-image anchor mismatch")
text = text.replace(old_req, new_req)

callback_anchor = r'''if image_source.count("imageBody.onReceive(loader.$image.compactMap { $0 })") != 1:
    raise SystemExit("image-loaded publisher must exist only on the real callback path")
'''
callback_addition = r'''if image_source.count("imageBody.onReceive(loader.$image.compactMap { $0 })") != 1:
    raise SystemExit("image-loaded publisher must exist only on the real callback path")
display_fast_path = image_source[image_source.index("private final class EmbyCachedDisplayImageSurfaceView"):image_source.index("struct EmbyCachedRemoteImage")]
if "@StateObject" in display_fast_path or ".onReceive(" in display_fast_path:
    raise SystemExit("display-only poster fast path must not observe loader.objectWillChange through SwiftUI")
if display_fast_path.count("loader.$image.sink") != 1:
    raise SystemExit("display-only poster fast path must have exactly one UIKit image publisher sink")
for needle in [
    'loader.load(url, reportsLoadingState: false, diagnosticRole: "display")',
    'loader.cancel(reportsLoadingState: false)',
    'surface.setImage(loader.image)',
    'imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit',
]:
    if needle not in display_fast_path:
        raise SystemExit(f"missing UIKit display-image fast-path contract: {needle}")
'''
if text.count(callback_anchor) != 1:
    raise SystemExit("checker callback-count anchor mismatch")
text = text.replace(callback_anchor, callback_addition)

home_guard = '''if 'EmbyPosterScrollMotionProbe(route: "home")' not in home_source:\n    raise SystemExit("Home poster-heavy scroll must register its vertical scroll owner for motion-gated hitch diagnostics")\n'''
if text.count(home_guard) != 1:
    raise SystemExit("checker Home-probe guard anchor mismatch")
text = text.replace(home_guard, "")
checker.write_text(text, encoding="utf-8")

changelog = Path("docs/changelog/CHANGELOG_v0_14_49_build216.md")
if changelog.exists():
    raise SystemExit("Build216 changelog already exists")
changelog.write_text(
    '# OnePlayer 0.14.49 / Build216\n\n'
    '## Grid display presentation A/B candidate\n\n'
    '- Based directly on Build212 target-device grid evidence: 11 real dragging hitches landed 0.0–20.1 ms after newly visible 378px network/display poster publication.\n'
    '- Build216 is based on the accepted Build213 page-cache main baseline; Favorites/Library page persistence remains included and unchanged. Build214/215 are independently owned by the Home-carousel task and are not included.\n'
    '- The candidate is grid/display-only. It does not carry the old poster Home motion-probe file and does not modify Home carousel owner files.\n'
    '- Pure display images with no loading indicator and no `onImageLoaded` callback keep the existing loader, disk cache, decoded-image pool, request size, diagnostic source tags and immediate delivery, but stop observing loader `objectWillChange` through the surrounding SwiftUI poster cell.\n'
    '- The existing loader publisher feeds a UIKit `UIImageView` surface directly for that display-only path. Callback/loading-indicator paths remain on the existing SwiftUI implementation.\n'
    '- Existing 3-column layout, rendered-device poster pixel width, person-result poster policy, native navigation and grid hitch diagnostics are preserved.\n'
    '- No image-quality reduction, timer, debounce, throttle, retry, fallback, page-data ownership change, scroll-physics change or carousel interaction change.\n'
    '- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN client-direct paths are untouched. Deployment Target remains iOS 15.0.\n',
    encoding="utf-8",
)
