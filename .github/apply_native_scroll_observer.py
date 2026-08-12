from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
detail = detail_path.read_text()
detail = replace_once(
    detail,
    '''                ScrollView(.vertical, showsIndicators: false) {\n                    VStack(alignment: .leading, spacing: 0) {\n                        AdaptiveHeroRawScrollSentinel(coordinateSpaceName: "emby-detail-scroll")\n                        LazyVStack(alignment: .leading, spacing: 0) {\n''',
    '''                ScrollView(.vertical, showsIndicators: false) {\n                    LazyVStack(alignment: .leading, spacing: 0) {\n''',
    "detail scroll wrapper",
)
detail = replace_once(
    detail,
    '''                            .padding(.top, 2)\n                            .padding(.bottom, max(88, geometry.safeAreaInsets.bottom + 70))\n                        }\n                    }\n                    .frame(width: geometry.size.width)\n                }\n                .coordinateSpace(name: "emby-detail-scroll")\n                .onPreferenceChange(AdaptiveHeroRawScrollPreferenceKey.self) { value in\n                    if abs(heroRawScrollMinY - value) > 0.10 { heroRawScrollMinY = value }\n                }\n''',
    '''                            .padding(.top, 2)\n                            .padding(.bottom, max(88, geometry.safeAreaInsets.bottom + 70))\n                    }\n                    .frame(width: geometry.size.width)\n                    .background(\n                        AdaptiveHeroNativeScrollObserver { value in\n                            if abs(heroRawScrollMinY - value) > 0.10 { heroRawScrollMinY = value }\n                        }\n                    )\n                }\n''',
    "detail scroll observer",
)
detail_path.write_text(detail)

picker_path = Path("Sources/UI/EmbyEpisodePickerView.swift")
picker = picker_path.read_text()
picker = replace_once(
    picker,
    '''                    ScrollView(.vertical, showsIndicators: false) {\n                        VStack(spacing: 0) {\n                            AdaptiveHeroRawScrollSentinel(coordinateSpaceName: "emby-episode-picker-scroll")\n                            LazyVStack(spacing: 0) {\n''',
    '''                    ScrollView(.vertical, showsIndicators: false) {\n                        LazyVStack(spacing: 0) {\n''',
    "picker scroll wrapper",
)
picker = replace_once(
    picker,
    '''                                .padding(.top, 12)\n                                .padding(.bottom, 92)\n                            }\n                        }\n                        .frame(width: geometry.size.width)\n                    }\n                    .frame(width: geometry.size.width, height: viewportHeight)\n                    .background(Color.clear)\n                    .coordinateSpace(name: "emby-episode-picker-scroll")\n                    .onPreferenceChange(AdaptiveHeroRawScrollPreferenceKey.self) { value in\n                        if abs(pickerHeroRawScrollMinY - value) > 0.10 { pickerHeroRawScrollMinY = value }\n                    }\n''',
    '''                                .padding(.top, 12)\n                                .padding(.bottom, 92)\n                        }\n                        .frame(width: geometry.size.width)\n                        .background(\n                            AdaptiveHeroNativeScrollObserver { value in\n                                if abs(pickerHeroRawScrollMinY - value) > 0.10 { pickerHeroRawScrollMinY = value }\n                            }\n                        )\n                    }\n                    .frame(width: geometry.size.width, height: viewportHeight)\n                    .background(Color.clear)\n''',
    "picker scroll observer",
)
picker_path.write_text(picker)

metrics_path = Path("Sources/UI/ImmersiveUIComponents.swift")
metrics = metrics_path.read_text()
pattern = re.compile(
    r'''struct AdaptiveHeroRawScrollPreferenceKey: PreferenceKey \{.*?\n\}\n\nstruct AdaptiveHeroRawScrollSentinel: View \{.*?\n\}\n\n(?=struct DetailPressButtonStyle)''',
    re.S,
)
observer = r'''private final class AdaptiveHeroScrollProbeUIView: UIView {
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

struct AdaptiveHeroNativeScrollObserver: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> AdaptiveHeroScrollProbeUIView {
        let view = AdaptiveHeroScrollProbeUIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: AdaptiveHeroScrollProbeUIView, context: Context) {
        context.coordinator.onChange = onChange
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: AdaptiveHeroScrollProbeUIView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach()
    }

    final class Coordinator {
        var onChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?

        init(onChange: @escaping (CGFloat) -> Void) { self.onChange = onChange }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorScrollView(from: probe) else { return }
            guard self.scrollView !== scrollView else {
                emit(scrollView)
                return
            }
            contentOffsetObservation?.invalidate()
            self.scrollView = scrollView
            contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            scrollView = nil
        }

        private func ancestorScrollView(from probe: UIView) -> UIScrollView? {
            var current: UIView? = probe
            while let view = current {
                if let scrollView = view as? UIScrollView { return scrollView }
                current = view.superview
            }
            return nil
        }

        private func emit(_ scrollView: UIScrollView) {
            let rawDisplacement = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            if Thread.isMainThread { onChange(rawDisplacement) }
            else { DispatchQueue.main.async { [weak self] in self?.onChange(rawDisplacement) } }
        }
    }
}

'''
metrics, count = pattern.subn(observer, metrics, count=1)
if count != 1:
    raise SystemExit(f"native observer replacement: expected one match, found {count}")
metrics_path.write_text(metrics)

check_path = Path("scripts/check_adaptive_hero_reveal.py")
check = check_path.read_text()
old_metrics_checks = '''require("struct AdaptiveHeroRawScrollPreferenceKey" in metrics, "raw ScrollView displacement preference key is missing")\nrequire("struct AdaptiveHeroRawScrollSentinel" in metrics and ".frame(height: 0)" in metrics, "independent zero-height raw scroll sentinel is missing")\nrequire("proxy.frame(in: .named(coordinateSpaceName)).minY" in metrics, "sentinel must read its own uncompensated position in the named ScrollView coordinate space")'''
new_metrics_checks = '''require("struct AdaptiveHeroNativeScrollObserver: UIViewRepresentable" in metrics, "native ScrollView observer is missing")\nrequire("contentOffset.y + scrollView.adjustedContentInset.top" in metrics, "native raw ScrollView displacement formula is missing")\nrequire("AdaptiveHeroRawScrollPreferenceKey" not in metrics and "AdaptiveHeroRawScrollSentinel" not in metrics, "GeometryReader/PreferenceKey raw scroll path must stay removed")'''
check = replace_once(check, old_metrics_checks, new_metrics_checks, "metrics checks")
check = replace_once(
    check,
    'require(\'AdaptiveHeroRawScrollSentinel(coordinateSpaceName: "emby-detail-scroll")\' in detail, "detail must use the independent top sentinel")',
    'require("AdaptiveHeroNativeScrollObserver" in detail, "detail must observe native ScrollView content offset")',
    "detail check",
)
check = replace_once(
    check,
    'require(\'AdaptiveHeroRawScrollSentinel(coordinateSpaceName: "emby-episode-picker-scroll")\' in picker, "episode picker must use the independent top sentinel")',
    'require("AdaptiveHeroNativeScrollObserver" in picker, "episode picker must observe native ScrollView content offset")',
    "picker check",
)
check_path.write_text(check)

print("native Hero ScrollView observer patch applied")
