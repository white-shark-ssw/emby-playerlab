from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


# Detail page: NavigationView already gives us a viewport whose bottom safe area is
# expanded by the server root. Ignoring the top safe area shifts that fixed-height
# viewport upward, so add the top inset back to the real page height.
path = Path("Sources/UI/EmbyMediaDetailView.swift")
text = path.read_text()
text = replace_once(
    text,
    "        GeometryReader { geometry in\n            ZStack(alignment: .top) {\n",
    "        GeometryReader { geometry in\n            let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top\n            ZStack(alignment: .top) {\n",
    "detail viewport declaration",
)
text = replace_once(
    text,
    "                .frame(width: geometry.size.width, height: geometry.size.height)\n                .background(Color.clear)\n                .ignoresSafeArea(edges: [.top, .bottom])\n",
    "                .frame(width: geometry.size.width, height: viewportHeight)\n                .background(Color.clear)\n                .ignoresSafeArea(edges: [.top, .bottom])\n",
    "detail scroll viewport",
)
text = replace_once(
    text,
    "            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)\n            .ignoresSafeArea(edges: [.top, .bottom])\n",
    "            .frame(width: geometry.size.width, height: viewportHeight, alignment: .top)\n            .ignoresSafeArea(edges: [.top, .bottom])\n            .onAppear { DiagnosticsLogger.shared.log(\"ImmersiveViewport\", \"page=detail geometry=\\(geometry.size) safe=\\(geometry.safeAreaInsets) viewportHeight=\\(viewportHeight)\") }\n",
    "detail outer viewport",
)
path.write_text(text)


# Full episode picker follows the same viewport ownership rule.
path = Path("Sources/UI/EmbyEpisodePickerView.swift")
text = path.read_text()
text = replace_once(
    text,
    "        GeometryReader { geometry in\n            ScrollViewReader { proxy in\n",
    "        GeometryReader { geometry in\n            let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top\n            ScrollViewReader { proxy in\n",
    "picker viewport declaration",
)
text = replace_once(
    text,
    "                    .frame(width: geometry.size.width, height: geometry.size.height)\n                    .background(Color.clear)\n                    .ignoresSafeArea(edges: [.top, .bottom])\n",
    "                    .frame(width: geometry.size.width, height: viewportHeight)\n                    .background(Color.clear)\n                    .ignoresSafeArea(edges: [.top, .bottom])\n",
    "picker scroll viewport",
)
text = replace_once(text, "                    let railHeight = min(590, geometry.size.height * 0.72)\n                    let railTop = max(126, geometry.size.height * 0.13)\n", "                    let railHeight = min(590, viewportHeight * 0.72)\n                    let railTop = max(126, viewportHeight * 0.13)\n", "picker rail viewport")
text = replace_once(
    text,
    "                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)\n                .ignoresSafeArea(edges: [.top, .bottom])\n",
    "                .frame(width: geometry.size.width, height: viewportHeight, alignment: .top)\n                .ignoresSafeArea(edges: [.top, .bottom])\n                .onAppear { DiagnosticsLogger.shared.log(\"ImmersiveViewport\", \"page=episode-picker geometry=\\(geometry.size) safe=\\(geometry.safeAreaInsets) viewportHeight=\\(viewportHeight)\") }\n",
    "picker outer viewport",
)
path.write_text(text)


# Shared presentation: remove the ineffective negative additionalSafeAreaInsets bridge.
# The runtime log proved the hosting controller stayed at bottom safe=34 even after
# additional.bottom=-34. Dock is now a pure overlay and never changes page sizing.
path = Path("Sources/UI/ImmersiveUIComponents.swift")
text = path.read_text()
bridge_start = text.index("private final class ImmersiveBottomSafeAreaViewController")
modifier_start = text.index("private struct DetailPagePresentationModifier")
text = text[:bridge_start] + text[modifier_start:]
old_modifier = '''private struct DetailPagePresentationModifier: ViewModifier {
    @AppStorage(DetailPresentationSettingsKey.fullyImmersive) private var fullyImmersive = true
    @Environment(\\.serverDockContent) private var serverDockContent

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if !fullyImmersive, let serverDockContent {
                serverDockContent
                    .frame(height: ImmersiveUIMetrics.serverDockHeight)
                    .zIndex(100)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Group {
            if fullyImmersive { ImmersiveBottomSafeAreaBridge().frame(width: 0, height: 0) }
        })
    }
}
'''
new_modifier = '''private struct DetailPagePresentationModifier: ViewModifier {
    @AppStorage(DetailPresentationSettingsKey.fullyImmersive) private var fullyImmersive = true
    @Environment(\\.serverDockContent) private var serverDockContent

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if !fullyImmersive, let serverDockContent {
                    serverDockContent
                        .frame(height: ImmersiveUIMetrics.serverDockHeight)
                        .zIndex(100)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
    }
}
'''
text = replace_once(text, old_modifier, new_modifier, "detail presentation modifier")

coordinator_start = text.index("    final class Coordinator: NSObject, UIGestureRecognizerDelegate {")
make_coordinator = text.index("    func makeCoordinator() -> Coordinator { Coordinator() }", coordinator_start)
new_coordinator = '''    final class Coordinator: NSObject {
        private let navigationControllers = NSHashTable<UINavigationController>.weakObjects()
        private let observedGestures = NSHashTable<UIGestureRecognizer>.weakObjects()

        func install(from viewController: UIViewController) {
            if let navigationController = viewController.navigationController { install(navigationController) }
            if let root = viewController.viewIfLoaded?.window?.rootViewController { installTree(from: root) }
        }

        private func installTree(from root: UIViewController) {
            var stack: [UIViewController] = [root]
            while let current = stack.popLast() {
                if let navigationController = current as? UINavigationController { install(navigationController) }
                if let presented = current.presentedViewController { stack.append(presented) }
                stack.append(contentsOf: current.children)
            }
        }

        private func install(_ navigationController: UINavigationController) {
            navigationControllers.add(navigationController)
            guard let gesture = navigationController.interactivePopGestureRecognizer else { return }
            if !observedGestures.contains(gesture) {
                observedGestures.add(gesture)
                gesture.addTarget(self, action: #selector(popGestureChanged(_:)))
            }
            gesture.delegate = nil
            gesture.isEnabled = navigationController.viewControllers.count > 1
            gesture.cancelsTouchesInView = true
        }

        private func navigationController(for gestureRecognizer: UIGestureRecognizer) -> UINavigationController? {
            navigationControllers.allObjects.first { $0.interactivePopGestureRecognizer === gestureRecognizer }
        }

        @objc private func popGestureChanged(_ gestureRecognizer: UIGestureRecognizer) {
            guard gestureRecognizer.state == .began || gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled || gestureRecognizer.state == .failed else { return }
            let navigationController = navigationController(for: gestureRecognizer)
            DiagnosticsLogger.shared.log("NavigationRace", "event=interactive-pop-state state=\\(gestureRecognizer.state.rawValue) stack=\\(navigationController?.viewControllers.count ?? 0) coordinatorPresent=\\(navigationController?.transitionCoordinator != nil)")
        }
    }

'''
text = text[:coordinator_start] + new_coordinator + text[make_coordinator:]
path.write_text(text)


for staged_path in [Path(".github/workflows/one-shot-viewport-pop-fix.yml"), Path("scripts/apply_viewport_pop_fix.py")]:
    if staged_path.exists(): staged_path.unlink()

print("Applied viewport and interactive-pop fix.")
