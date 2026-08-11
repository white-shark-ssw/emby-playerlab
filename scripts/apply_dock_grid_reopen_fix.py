from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, got {count}")
    return text.replace(old, new, 1)


# 1) Pass the real root bottom safe-area inset down to pushed detail pages.
# The root Dock itself remains 40pt; descendants only need the inset to place
# that same 40pt bar at the same vertical position as the root pages.
path = Path("Sources/UI/EmbyServerRootViewV3.swift")
text = path.read_text()
text = replace_once(
    text,
    '                    .environment(\\.serverDockContent, AnyView(serverTabBar))\n',
    '                    .environment(\\.serverDockContent, AnyView(serverTabBar))\n                    .environment(\\.serverDockBottomInset, geometry.safeAreaInsets.bottom)\n',
    "root dock bottom inset environment",
)
path.write_text(text)


# 2) Non-immersive detail Dock: keep its visual height exactly 40pt, but move the
# bar above the Home Indicator safe area just like the root/home Dock. The Dock's
# own background still ignores the bottom safe area, so the background continues
# through the Home Indicator region without moving the buttons down.
path = Path("Sources/UI/ImmersiveUIComponents.swift")
text = path.read_text()
text = replace_once(
    text,
    '''private struct ServerDockContentKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}

extension EnvironmentValues {
    var serverDockContent: AnyView? {
        get { self[ServerDockContentKey.self] }
        set { self[ServerDockContentKey.self] = newValue }
    }
}
''',
    '''private struct ServerDockContentKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}

private struct ServerDockBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var serverDockContent: AnyView? {
        get { self[ServerDockContentKey.self] }
        set { self[ServerDockContentKey.self] = newValue }
    }

    var serverDockBottomInset: CGFloat {
        get { self[ServerDockBottomInsetKey.self] }
        set { self[ServerDockBottomInsetKey.self] = newValue }
    }
}
''',
    "dock bottom inset environment key",
)
text = replace_once(
    text,
    '''private struct DetailPagePresentationModifier: ViewModifier {
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
''',
    '''private struct DetailPagePresentationModifier: ViewModifier {
    @AppStorage(DetailPresentationSettingsKey.fullyImmersive) private var fullyImmersive = true
    @Environment(\\.serverDockContent) private var serverDockContent
    @Environment(\\.serverDockBottomInset) private var serverDockBottomInset

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if !fullyImmersive, let serverDockContent {
                    serverDockContent
                        .frame(height: ImmersiveUIMetrics.serverDockHeight)
                        .padding(.bottom, serverDockBottomInset)
                        .zIndex(100)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
    }
}
''',
    "detail dock placement",
)
path.write_text(text)


# 3) Poster-grid navigation: do not destroy/replace the NavigationLink destination
# while UIKit is still finishing an interactive pop. The prior code cleared
# selectedItem/client as soon as isActive became false, which turns the live
# destination into EmptyView during the pop. The device log then shows a later
# push with UINavigationController stack=3. Keep destination data stable, hold a
# short return-settle gate, and queue one tap made during that gate.
path = Path("Sources/UI/EmbyPosterGrid.swift")
text = path.read_text()
start = text.index("final class EmbyPosterGridNavigationState: ObservableObject {")
end = text.index("\nprivate struct EmbyPosterGridNavigationStateKey", start)
replacement = r'''final class EmbyPosterGridNavigationState: ObservableObject {
    @Published fileprivate var selectedItem: LibraryItem?
    @Published fileprivate var client: EmbyAPIClient?
    @Published fileprivate var isActive = false
    @Published fileprivate var sourceInteractionLocked = false
    private var transitionLocked = false
    private var destinationPresented = false
    private var transitionGeneration = 0
    private var queuedItem: LibraryItem?
    private var queuedClient: EmbyAPIClient?
    private let pushConfirmationTimeout: TimeInterval = 1.25
    private let returnSettleInterval: TimeInterval = 0.36

    func open(item: LibraryItem, client: EmbyAPIClient) {
        if !isActive, transitionLocked, !destinationPresented {
            if queuedItem == nil {
                queuedItem = item
                queuedClient = client
                DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-queued item=\(item.id) generation=\(transitionGeneration) reason=return-settling")
            } else {
                DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-rejected item=\(item.id) active=\(isActive) transitionLocked=\(transitionLocked) sourceLocked=\(sourceInteractionLocked) destinationPresented=\(destinationPresented) reason=queue-occupied")
            }
            return
        }
        guard !isActive, !transitionLocked, !sourceInteractionLocked else {
            DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-rejected item=\(item.id) active=\(isActive) transitionLocked=\(transitionLocked) sourceLocked=\(sourceInteractionLocked) destinationPresented=\(destinationPresented) reason=transition-active")
            return
        }
        transitionGeneration += 1
        let generation = transitionGeneration
        sourceInteractionLocked = true
        transitionLocked = true
        destinationPresented = false
        queuedItem = nil
        queuedClient = nil
        selectedItem = item
        self.client = client
        isActive = true
        DiagnosticsLogger.shared.log("NavigationRace", "event=poster-open-accepted item=\(item.id) generation=\(generation)")
        DispatchQueue.main.asyncAfter(deadline: .now() + pushConfirmationTimeout) { [weak self] in
            self?.expirePendingPush(generation: generation)
        }
    }

    fileprivate func destinationDidAppear() {
        destinationPresented = true
        DiagnosticsLogger.shared.log("NavigationRace", "event=destination-did-appear item=\(selectedItem?.id ?? "none") generation=\(transitionGeneration)")
    }

    fileprivate func destinationDidDisappear() {
        DiagnosticsLogger.shared.log("NavigationRace", "event=destination-did-disappear item=\(selectedItem?.id ?? "none") active=\(isActive) transitionLocked=\(transitionLocked) generation=\(transitionGeneration)")
    }

    fileprivate func updateActive(_ active: Bool) {
        DiagnosticsLogger.shared.log("NavigationRace", "event=binding-update active=\(active) currentActive=\(isActive) transitionLocked=\(transitionLocked) destinationPresented=\(destinationPresented) sourceLocked=\(sourceInteractionLocked) generation=\(transitionGeneration)")
        if active {
            isActive = true
            return
        }
        if !isActive, transitionLocked, !destinationPresented {
            DiagnosticsLogger.shared.log("NavigationRace", "event=binding-update-duplicate-false generation=\(transitionGeneration)")
            return
        }
        if transitionLocked && !destinationPresented {
            cancelPendingPush(reason: "binding-deactivated-before-appearance")
            return
        }
        if destinationPresented {
            beginReturnSettlement()
            return
        }
        isActive = false
        transitionLocked = false
        sourceInteractionLocked = false
    }

    fileprivate func prepareForGridAppearance() {
        DiagnosticsLogger.shared.log("NavigationRace", "event=grid-appear active=\(isActive) transitionLocked=\(transitionLocked) destinationPresented=\(destinationPresented) sourceLocked=\(sourceInteractionLocked) generation=\(transitionGeneration)")
        if !isActive && !transitionLocked {
            destinationPresented = false
            sourceInteractionLocked = false
        }
    }

    private func beginReturnSettlement() {
        let generation = transitionGeneration
        isActive = false
        destinationPresented = false
        transitionLocked = true
        sourceInteractionLocked = false
        DiagnosticsLogger.shared.log("NavigationRace", "event=return-settle-begin item=\(selectedItem?.id ?? "none") generation=\(generation) delayMs=\(Int(returnSettleInterval * 1000))")
        DispatchQueue.main.asyncAfter(deadline: .now() + returnSettleInterval) { [weak self] in
            self?.finishReturnSettlement(generation: generation)
        }
    }

    private func finishReturnSettlement(generation: Int) {
        guard generation == transitionGeneration, !isActive, transitionLocked, !destinationPresented else { return }
        transitionLocked = false
        sourceInteractionLocked = false
        let queued = queuedItem
        let queuedClient = self.queuedClient
        queuedItem = nil
        self.queuedClient = nil
        DiagnosticsLogger.shared.log("NavigationRace", "event=return-settle-end item=\(selectedItem?.id ?? "none") generation=\(generation) queued=\(queued?.id ?? "none")")
        if let queued, let queuedClient { open(item: queued, client: queuedClient) }
    }

    private func expirePendingPush(generation: Int) {
        guard generation == transitionGeneration, transitionLocked, isActive, !destinationPresented else { return }
        DiagnosticsLogger.shared.log("NavigationRace", "event=push-confirmation-timeout item=\(selectedItem?.id ?? "none") generation=\(generation) active=\(isActive) sourceLocked=\(sourceInteractionLocked)")
        cancelPendingPush(reason: "destination-did-not-appear")
    }

    private func cancelPendingPush(reason: String) {
        DiagnosticsLogger.shared.log("NavigationRace", "event=cancel-pending-push reason=\(reason) item=\(selectedItem?.id ?? "none") generation=\(transitionGeneration)")
        transitionGeneration += 1
        isActive = false
        transitionLocked = false
        destinationPresented = false
        sourceInteractionLocked = false
        queuedItem = nil
        queuedClient = nil
        selectedItem = nil
        client = nil
    }
}
'''
text = text[:start] + replacement + text[end:]
text = replace_once(
    text,
    '''                    EmbyMediaDetailView(item: item, client: client)
                        .onAppear { state.destinationDidAppear() }
                        .onDisappear { state.destinationDidDisappear() }
''',
    '''                    EmbyMediaDetailView(item: item, client: client)
                        .id(state.transitionIdentity)
                        .onAppear { state.destinationDidAppear() }
                        .onDisappear { state.destinationDidDisappear() }
''',
    "destination identity",
)
# transitionIdentity is read-only and intentionally internal to the file so each
# accepted push gets a fresh detail view identity without exposing state fields.
text = replace_once(
    text,
    "    private let returnSettleInterval: TimeInterval = 0.36\n\n    func open(item: LibraryItem, client: EmbyAPIClient) {\n",
    "    private let returnSettleInterval: TimeInterval = 0.36\n    fileprivate var transitionIdentity: Int { transitionGeneration }\n\n    func open(item: LibraryItem, client: EmbyAPIClient) {\n",
    "transition identity property",
)
path.write_text(text)


for staged_path in [Path(".github/workflows/one-shot-dock-grid-reopen-fix.yml"), Path("scripts/apply_dock_grid_reopen_fix.py")]:
    if staged_path.exists(): staged_path.unlink()

print("Applied Dock placement and poster-grid reopen fixes.")
