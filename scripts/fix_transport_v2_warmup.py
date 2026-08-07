from pathlib import Path

p = Path("Sources/Cache/KTVCachePlaybackSession.swift")
text = p.read_text()
old = '''    private func enableSecondaryAfterWarmup() {
        let now = Date()
        let cacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        lock.lock()
        guard !stopped, dualPhase == .singleBaseline, now >= playbackPriorityUntil else { lock.unlock(); return }
        let elapsed = max(now.timeIntervalSince(dualWindowStartedAt), 0.001)
        singleLaneBaselineSpeed = Double(max(0, cacheBytes - dualWindowStartBytes)) / elapsed
        dualPhase = .dualKept
        let baseline = singleLaneBaselineSpeed
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "adjacent dual enabled baseline=\\(Int(baseline))B/s trigger=session-warmup policy=persistent-until-error pipelineDepth=\\(pipelineLookaheadSegments)")
        scheduleAvailableWorkers(reason: "session-warmup-dual")
    }
'''
new = '''    private func enableSecondaryAfterWarmup() {
        let now = Date()
        let cacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        lock.lock()
        guard !stopped, dualPhase == .singleBaseline else { lock.unlock(); return }
        if now < playbackPriorityUntil {
            let retryDelay = max(0.05, playbackPriorityUntil.timeIntervalSince(now) + 0.05)
            lock.unlock()
            DiagnosticsLogger.shared.log("KTVAdaptive", "dual warmup deferred by playback priority retryMs=\\(Int(retryDelay * 1000))")
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryDelay) { [weak self] in self?.enableSecondaryAfterWarmup() }
            return
        }
        let elapsed = max(now.timeIntervalSince(dualWindowStartedAt), 0.001)
        singleLaneBaselineSpeed = Double(max(0, cacheBytes - dualWindowStartBytes)) / elapsed
        dualPhase = .dualKept
        let baseline = singleLaneBaselineSpeed
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "adjacent dual enabled baseline=\\(Int(baseline))B/s trigger=session-warmup policy=persistent-until-error pipelineDepth=\\(pipelineLookaheadSegments)")
        scheduleAvailableWorkers(reason: "session-warmup-dual")
    }
'''
if old in text:
    p.write_text(text.replace(old, new, 1))
elif new not in text:
    raise SystemExit("Transport v2 warmup function not found")
