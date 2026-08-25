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

mdk = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
mdk_text = mdk.read_text()
old_recovery = r'''    func recoverStall(position: Double, duration: Double) {
        guard let player else { return }
        if let sharedTransportSession { Task { await sharedTransportSession.recoverStall(position: position, duration: duration) } }
        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) state=\(String(describing: player.state)) status=0x\(String(player.mediaStatus.rawValue, radix: 16)) unifiedTransport=\(sharedTransportSession != nil) action=prioritize-and-play")
        if shouldPlay { player.state = .Playing }
    }
'''
new_recovery = r'''    func recoverStall(position: Double, duration: Double) {
        guard let player else { return }
        if let sharedTransportSession { Task { await sharedTransportSession.recoverStall(position: position, duration: duration) } }
        let status = player.mediaStatus.rawValue
        let prematureEnd = hasStatus(status, bit: 6) && duration > 0 && position + max(3, duration * 0.005) < duration
        if prematureEnd, shouldPlay {
            DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) state=\(String(describing: player.state)) status=0x\(String(status, radix: 16)) unifiedTransport=\(sharedTransportSession != nil) action=native-seek-current-after-network-eof")
            seek(to: position, direction: .absolute)
            return
        }
        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) state=\(String(describing: player.state)) status=0x\(String(status, radix: 16)) unifiedTransport=\(sharedTransportSession != nil) action=prioritize-and-play")
        if shouldPlay { player.state = .Playing }
    }
'''
if new_recovery not in mdk_text:
    if old_recovery not in mdk_text:
        raise SystemExit('MDK recoverStall anchor missing')
    mdk_text = mdk_text.replace(old_recovery, new_recovery, 1)
mdk.write_text(mdk_text)

print('Build83 authority separation and MDK EOF recovery finalized')
