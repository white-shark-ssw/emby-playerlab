from pathlib import Path

p = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = p.read_text()

raw_record = '        if concretePlaybackDemand, !resumeHistoricalDependency { recordPlaybackDemand(offset: range.lowerBound) }\n'
text = text.replace(raw_record, '', 1)

raw_promotion = r'''        if concretePlaybackDemand, !reanchored, !awaitingInitialResumeDemand, Date() > pendingUserSeekUntil {
            switch demandCoordinator.observe(offset: range.lowerBound, activeCenter: cacheWindowCenter, nearDistance: blockBytes * 4, starving: playbackStarving) {
            case .nearHead:
                advanceCacheWindowCenterFromRecentDemand(resource: resource)
            case .holdCandidate(let samples):
                if samples == 1 {
                    DiagnosticsLogger.shared.playback("PlaybackDemand", "candidate center=\(cacheWindowCenter) offset=\(range.lowerBound) starving=\(playbackStarving) reason=\(reason)")
                }
            case .promote(let offset, let promotionReason):
                let previous = cacheWindowCenter
                playbackAnchor = offset
                playbackDemandSamples.removeAll()
                recordPlaybackDemand(offset: offset)
                resetCacheWindowCenter(to: offset, resource: resource, reason: promotionReason)
                reanchored = true
                DiagnosticsLogger.shared.playback("PlaybackDemand", "promoted previous=\(previous) new=\(offset) reason=\(promotionReason) request=\(range.lowerBound)-\(range.upperBound)")
                for slot in [0, 1] {
                    guard let active = slotClaims[slot], !active.range.contains(offset) else { continue }
                    if active.role == .sequential || active.role == .urgentPlayback { cancelSlot(slot, reason: "active-head-promoted") }
                }
            }
        }

'''
text = text.replace(raw_promotion, '', 1)

raw_advance = r'''    private func advanceCacheWindowCenterFromRecentDemand(resource: TransportResolvedResource) {
        guard playbackAdvancing, !awaitingInitialResumeDemand, Date() > pendingUserSeekUntil else { return }
        prunePlaybackDemandSamples()
        guard let recentFloor = playbackDemandSamples.map(\.offset).min() else { return }
        let candidate = min(max(0, recentFloor), max(0, resource.contentLength - 1))
        guard candidate > cacheWindowCenter else { return }
        let distance = candidate - cacheWindowCenter
        guard distance <= blockBytes * 4 else { return }
        let previous = cacheWindowCenter
        cacheWindowCenter = candidate
        playbackAnchor = candidate
        DiagnosticsLogger.shared.playback("RollingCache", "center advanced previous=\(previous) new=\(cacheWindowCenter) delta=\(distance)")
        scheduleSlots(reason: "window-center-advanced")
    }

'''
text = text.replace(raw_advance, '', 1)

if 'demandCoordinator.observe(offset:' in text:
    raise SystemExit('raw-read authority path still exists')
if raw_record in text:
    raise SystemExit('raw concrete read still pollutes playback authority samples')

p.write_text(text)
print('Build83 old raw-read authority paths removed')
