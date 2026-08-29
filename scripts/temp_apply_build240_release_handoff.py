from pathlib import Path

# Build identity only; packaging still overrides MARKETING_VERSION/CURRENT_PROJECT_VERSION explicitly.
p = Path('Sources/Core/AppIdentity.swift')
t = p.read_text()
if t.count('0.14.72') != 2:
    raise SystemExit('unexpected AppIdentity 0.14.72 count')
t = t.replace('0.14.72', '0.14.73')
p.write_text(t)

# Reuse the existing carousel cadence owner and existing CADisplayLink. The only new state is diagnostic sampling.
p = Path('Sources/UI/EmbyHomeCarouselCadenceDiagnosticsV3.swift')
t = p.read_text()
old = '''    private struct DisplayGapEvent {
        let gapMS: Double
        let imageRole: String
        let imageItemID: String
        let imageAgeMS: Double
    }
'''
new = old + '''
    private struct ReleaseProgressSample {
        let elapsedMS: Double
        let progress: CGFloat
    }

    private struct ReleaseDisplaySample {
        let elapsedMS: Double
        let gapMS: Double
        let progress: CGFloat
    }
'''
if old not in t: raise SystemExit('DisplayGapEvent anchor missing')
t = t.replace(old, new, 1)

old = '''    private var imageEventsDuringDrag = 0
    private var imageRoleCounts: [String: Int] = [:]
'''
new = old + '''    private var releaseHandoffAt: CFTimeInterval?
    private var releaseHandoffVelocityPtS: CGFloat = 0
    private var releaseHandoffActualProgress: CGFloat = 0
    private var releaseHandoffVisualProgress: CGFloat = 0
    private var releaseHandoffWidth: CGFloat = 1
    private var releaseHandoffLatestProgress: CGFloat = 0
    private var releaseHandoffProgressSamples: [ReleaseProgressSample] = []
    private var releaseHandoffDisplaySamples: [ReleaseDisplaySample] = []
'''
if old not in t: raise SystemExit('diagnostic state anchor missing')
t = t.replace(old, new, 1)

old = '''        imageEventsDuringDrag = 0
        imageRoleCounts.removeAll(keepingCapacity: true)
        deliveredTouchStats.record(touch.timestamp)
'''
new = '''        imageEventsDuringDrag = 0
        imageRoleCounts.removeAll(keepingCapacity: true)
        releaseHandoffAt = nil
        releaseHandoffVelocityPtS = 0
        releaseHandoffActualProgress = 0
        releaseHandoffVisualProgress = 0
        releaseHandoffWidth = 1
        releaseHandoffLatestProgress = 0
        releaseHandoffProgressSamples.removeAll(keepingCapacity: true)
        releaseHandoffDisplaySamples.removeAll(keepingCapacity: true)
        deliveredTouchStats.record(touch.timestamp)
'''
if old not in t: raise SystemExit('begin reset anchor missing')
t = t.replace(old, new, 1)

anchor = '''    func recordTouch(_ touch: UITouch, event: UIEvent) {
'''
insert = '''    func beginReleaseHandoff(directionalVelocityPtS: CGFloat, actualProgress: CGFloat, visualProgress: CGFloat, width: CGFloat) {
        precondition(Thread.isMainThread)
        guard active else { return }
        releaseHandoffAt = CACurrentMediaTime()
        releaseHandoffVelocityPtS = directionalVelocityPtS
        releaseHandoffActualProgress = actualProgress
        releaseHandoffVisualProgress = visualProgress
        releaseHandoffWidth = max(1, width)
        releaseHandoffLatestProgress = visualProgress
        releaseHandoffProgressSamples.removeAll(keepingCapacity: true)
        releaseHandoffDisplaySamples.removeAll(keepingCapacity: true)
    }

'''
if anchor not in t: raise SystemExit('recordTouch anchor missing')
t = t.replace(anchor, insert + anchor, 1)

old = '''    func recordSwiftUIUpdate(progress: CGFloat) {
        precondition(Thread.isMainThread)
        guard active else { return }
        if let lastRenderProgress, abs(progress - lastRenderProgress) <= 0.000001 { return }
        lastRenderProgress = progress
        let now = CACurrentMediaTime()
        renderUpdateStats.record(now)
        if let lastProgressPublishAt { maxPublishToRenderLagMS = max(maxPublishToRenderLagMS, max(0, (now - lastProgressPublishAt) * 1000)) }
    }
'''
new = '''    func recordSwiftUIUpdate(progress: CGFloat) {
        precondition(Thread.isMainThread)
        guard active else { return }
        let now = CACurrentMediaTime()
        recordReleaseAnimatedProgress(progress, at: now)
        if let lastRenderProgress, abs(progress - lastRenderProgress) <= 0.000001 { return }
        lastRenderProgress = progress
        renderUpdateStats.record(now)
        if let lastProgressPublishAt { maxPublishToRenderLagMS = max(maxPublishToRenderLagMS, max(0, (now - lastProgressPublishAt) * 1000)) }
    }
'''
if old not in t: raise SystemExit('recordSwiftUIUpdate block missing')
t = t.replace(old, new, 1)

old = '''        let now = CACurrentMediaTime()
        let durationMS = max(0, (now - dragStartedAt) * 1000)
        let p95DisplayGap = percentile95(displayGapSamples)
'''
new = '''        let now = CACurrentMediaTime()
        let durationMS = max(0, (now - dragStartedAt) * 1000)
        logReleaseHandoff(reason: reason)
        let p95DisplayGap = percentile95(displayGapSamples)
'''
if old not in t: raise SystemExit('end timing anchor missing')
t = t.replace(old, new, 1)

old = '''        let gapMS = max(0, (link.timestamp - previousTimestamp) * 1000)
        displayGapSamples.append(gapMS)
        let imageAgeMS: Double
'''
new = '''        let gapMS = max(0, (link.timestamp - previousTimestamp) * 1000)
        displayGapSamples.append(gapMS)
        recordReleaseDisplaySample(timestamp: link.timestamp, gapMS: gapMS)
        let imageAgeMS: Double
'''
if old not in t: raise SystemExit('display link anchor missing')
t = t.replace(old, new, 1)

anchor = '''    private func percentile95(_ values: [Double]) -> Double {
'''
insert = '''    private func recordReleaseAnimatedProgress(_ progress: CGFloat, at timestamp: CFTimeInterval) {
        guard let releaseHandoffAt else { return }
        releaseHandoffLatestProgress = progress
        guard releaseHandoffProgressSamples.count < 6 else { return }
        let previousProgress = releaseHandoffProgressSamples.last?.progress ?? releaseHandoffVisualProgress
        guard abs(progress - previousProgress) > 0.000001 else { return }
        releaseHandoffProgressSamples.append(ReleaseProgressSample(elapsedMS: max(0, (timestamp - releaseHandoffAt) * 1000), progress: progress))
    }

    private func recordReleaseDisplaySample(timestamp: CFTimeInterval, gapMS: Double) {
        guard let releaseHandoffAt, timestamp >= releaseHandoffAt, releaseHandoffDisplaySamples.count < 6 else { return }
        releaseHandoffDisplaySamples.append(ReleaseDisplaySample(elapsedMS: max(0, (timestamp - releaseHandoffAt) * 1000), gapMS: gapMS, progress: releaseHandoffLatestProgress))
    }

    private func formatReleaseProgressSamples(_ samples: [ReleaseProgressSample]) -> String {
        guard !samples.isEmpty else { return "none" }
        var previousMS = 0.0
        var previousProgress = releaseHandoffVisualProgress
        return samples.map { sample in
            let deltaSeconds = max(0, sample.elapsedMS - previousMS) / 1000
            let velocity = deltaSeconds > 0.000001 ? (sample.progress - previousProgress) * releaseHandoffWidth / deltaSeconds : 0
            previousMS = sample.elapsedMS
            previousProgress = sample.progress
            return "\\(String(format: "%.2f", sample.elapsedMS)):p\\(String(format: "%.4f", sample.progress)):v\\(String(format: "%.1f", velocity))"
        }.joined(separator: ",")
    }

    private func formatReleaseDisplaySamples(_ samples: [ReleaseDisplaySample]) -> String {
        guard !samples.isEmpty else { return "none" }
        var previousMS = 0.0
        var previousProgress = releaseHandoffVisualProgress
        return samples.map { sample in
            let deltaSeconds = max(0, sample.elapsedMS - previousMS) / 1000
            let velocity = deltaSeconds > 0.000001 ? (sample.progress - previousProgress) * releaseHandoffWidth / deltaSeconds : 0
            previousMS = sample.elapsedMS
            previousProgress = sample.progress
            return "\\(String(format: "%.2f", sample.elapsedMS)):g\\(String(format: "%.2f", sample.gapMS)):p\\(String(format: "%.4f", sample.progress)):v\\(String(format: "%.1f", velocity))"
        }.joined(separator: ",")
    }

    private func logReleaseHandoff(reason: String) {
        guard releaseHandoffAt != nil else { return }
        let remainingPt = max(0, (1 - releaseHandoffVisualProgress) * releaseHandoffWidth)
        DiagnosticsLogger.shared.app(
            "HomeCarouselReleaseHandoff",
            "reason=\\(reason) release_velocity_pt_s=\\(String(format: "%.1f", releaseHandoffVelocityPtS)) actual_progress=\\(String(format: "%.4f", releaseHandoffActualProgress)) visual_progress=\\(String(format: "%.4f", releaseHandoffVisualProgress)) remaining_pt=\\(String(format: "%.1f", remainingPt)) width_pt=\\(String(format: "%.1f", releaseHandoffWidth)) animation_samples=\\(formatReleaseProgressSamples(releaseHandoffProgressSamples)) display_samples=\\(formatReleaseDisplaySamples(releaseHandoffDisplaySamples))"
        )
    }

'''
if anchor not in t: raise SystemExit('percentile anchor missing')
t = t.replace(anchor, insert + anchor, 1)

old = '''struct V3HomeCarouselCadenceRenderProbe: UIViewRepresentable {
    let progress: CGFloat

    func makeUIView(context: Context) -> UIView {
'''
new = '''struct V3HomeCarouselCadenceRenderProbe: UIViewRepresentable, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func makeUIView(context: Context) -> UIView {
'''
if old not in t: raise SystemExit('render probe anchor missing')
t = t.replace(old, new, 1)
p.write_text(t)

# Arm the diagnostic only for commit paths. Commit/cancel behavior, thresholds and release velocity source stay unchanged.
p = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift')
t = p.read_text()
old = '''            transitionProgress = 0
            transitionDirection = releaseDirection
            completeInteractiveTransition(to: targetID)
            return
'''
new = '''            transitionProgress = 0
            transitionDirection = releaseDirection
            V3HomeCarouselCadenceDiagnostics.shared.beginReleaseHandoff(directionalVelocityPtS: directionalVelocity, actualProgress: actualProgress, visualProgress: transitionProgress, width: width)
            completeInteractiveTransition(to: targetID)
            return
'''
if old not in t: raise SystemExit('non-drag commit anchor missing')
t = t.replace(old, new, 1)
old = '''        guard let targetID = transitionToID else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended-no-target"); return }
        isCarouselDragging = false
        if shouldCommit { completeInteractiveTransition(to: targetID) }
        else { cancelInteractiveTransition() }
'''
new = '''        guard let targetID = transitionToID else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended-no-target"); return }
        isCarouselDragging = false
        if shouldCommit {
            V3HomeCarouselCadenceDiagnostics.shared.beginReleaseHandoff(directionalVelocityPtS: directionalVelocity, actualProgress: actualProgress, visualProgress: transitionProgress, width: width)
            completeInteractiveTransition(to: targetID)
        } else {
            cancelInteractiveTransition()
        }
'''
if old not in t: raise SystemExit('interactive commit anchor missing')
t = t.replace(old, new, 1)
p.write_text(t)

Path('docs/changelog/CHANGELOG_v0_14_73_build240.md').write_text('''# OnePlayer 0.14.73 / Build240\n\n- Diagnostic-only Home-carousel release-handoff measurement based exactly on the accepted Build239 product behavior.\n- Keeps the 0.28 slow-drag commit threshold, direction-aware latest-delivered velocity >=600 pt/s fling gate, Build237 white-flash correction, Build236 real-sample start handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle / 0.22s commit + 0.18s cancel tail unchanged.\n- Reuses the existing carousel cadence CADisplayLink through settle; adds no timer, interpolator, spring, retry, watchdog or second visual/gesture owner.\n- Makes the existing zero-size cadence render probe Animatable so it can report the release animation interpolation, then logs the first six animated-progress and display-link samples after a commit release for comparison with measured directional release velocity.\n- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range changes.\n''')
