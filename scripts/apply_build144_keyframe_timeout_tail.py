from pathlib import Path

mpv_path = Path("Sources/Player/MPVPlayerEngine.swift")
transport_path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")

mpv = mpv_path.read_text()
transport = transport_path.read_text()

old_hit_log = '        DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) available=\\(available) returned=\\(data.count) result=hit mode=cache-only-no-network")\n'
if old_hit_log not in transport:
    raise SystemExit("Build144 missing expected KeyframeCacheRead hit log")
transport = transport.replace(old_hit_log, "", 1)

old_dispatch = '''                pending.dispatchTarget = dispatchTarget
                pending.keyframeLookupMs = keyframeLookupMs
                pending.keyframeAction = keyframeAction
                pending.previousKeyframe = previousKeyframe
                pending.nextKeyframe = nextKeyframe
                pending.nearestKeyframe = nearestKeyframe
                self.pendingSeek = pending
                let dispatchAt = CACurrentMediaTime()
                self.latestNativeSeekDispatchID = seekID
                self.activeSeekEventOwnerID = nil
                let previousText = previousKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nextText = nextKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nearestText = nearestKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                DiagnosticsLogger.shared.log("MPVFastSeek", "id=\\(seekID) phase=preflight requestedTarget=\\(String(format: "%.3f", target)) dispatchTarget=\\(String(format: "%.6f", dispatchTarget)) previous=\\(previousText) next=\\(nextText) nearest=\\(nearestText) keyframeLookupMs=\\(String(format: "%.1f", keyframeLookupMs)) budgetMs=\\(String(format: "%.0f", Self.keyframeLookupBudgetMs)) action=\\(keyframeAction)")
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(seekID) phase=native-dispatch owner=awaiting-mpv-event-seek")
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: "%.3f", target)) dispatchTarget=\\(String(format: "%.6f", dispatchTarget)) phase=native-dispatch prioritizeMs=\\(String(format: "%.1f", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: "%.1f", (dispatchAt - requestedAt) * 1000)) keyframeLookupMs=\\(String(format: "%.1f", keyframeLookupMs)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: "%.3f", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.6f", dispatchTarget), mode])
'''

new_dispatch = '''                var finalDispatchTarget = dispatchTarget
                var finalKeyframeAction = keyframeAction
                var finalPreviousKeyframe = previousKeyframe
                var finalNextKeyframe = nextKeyframe
                var finalNearestKeyframe = nearestKeyframe
                if finalKeyframeAction.hasPrefix("fallback-"), let cached = self.sessionKeyframeMap.neighbors(around: target) {
                    let neighbors = cached.neighbors
                    finalPreviousKeyframe = neighbors.previous
                    finalNextKeyframe = neighbors.next
                    finalNearestKeyframe = neighbors.nearest
                    if let previous = neighbors.previous, let next = neighbors.next, let nearest = neighbors.nearest, abs(nearest - next) < 0.0005, abs(next - target) < abs(target - previous) {
                        finalDispatchTarget = next
                        finalKeyframeAction = "dispatch-recheck-nearest-next"
                    } else {
                        finalKeyframeAction = "dispatch-recheck-nearest-previous-no-change"
                    }
                }
                pending.dispatchTarget = finalDispatchTarget
                pending.keyframeLookupMs = keyframeLookupMs
                pending.keyframeAction = finalKeyframeAction
                pending.previousKeyframe = finalPreviousKeyframe
                pending.nextKeyframe = finalNextKeyframe
                pending.nearestKeyframe = finalNearestKeyframe
                self.pendingSeek = pending
                let dispatchAt = CACurrentMediaTime()
                self.latestNativeSeekDispatchID = seekID
                self.activeSeekEventOwnerID = nil
                let previousText = finalPreviousKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nextText = finalNextKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nearestText = finalNearestKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                DiagnosticsLogger.shared.log("MPVFastSeek", "id=\\(seekID) phase=preflight requestedTarget=\\(String(format: "%.3f", target)) dispatchTarget=\\(String(format: "%.6f", finalDispatchTarget)) previous=\\(previousText) next=\\(nextText) nearest=\\(nearestText) keyframeLookupMs=\\(String(format: "%.1f", keyframeLookupMs)) budgetMs=\\(String(format: "%.0f", Self.keyframeLookupBudgetMs)) action=\\(finalKeyframeAction)")
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(seekID) phase=native-dispatch owner=awaiting-mpv-event-seek")
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: "%.3f", target)) dispatchTarget=\\(String(format: "%.6f", finalDispatchTarget)) phase=native-dispatch prioritizeMs=\\(String(format: "%.1f", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: "%.1f", (dispatchAt - requestedAt) * 1000)) keyframeLookupMs=\\(String(format: "%.1f", keyframeLookupMs)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: "%.3f", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.6f", finalDispatchTarget), mode])
'''

if old_dispatch not in mpv:
    raise SystemExit("Build144 missing expected MPV dispatch block")
mpv = mpv.replace(old_dispatch, new_dispatch, 1)

mpv_path.write_text(mpv)
transport_path.write_text(transport)
print("Build144 timeout-tail patch applied")
