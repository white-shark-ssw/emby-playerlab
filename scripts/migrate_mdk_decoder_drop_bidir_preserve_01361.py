from pathlib import Path

path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
text = path.read_text()

old_policy = '''            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart
            let decoderProperty = player.property(name: "video.decoder") ?? "nil"
            DiagnosticsLogger.shared.playback("MDKDecoderTrace", "id=\\(dispatchedIntent.id) phase=pre-seek property=\\(decoderProperty) requestedPolicy=unchanged-default-auto")
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"accurate-incache\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")
'''
new_policy = '''            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart
            let decoderPropertyBefore = player.property(name: "video.decoder")
            var decoderPropertyParts = decoderPropertyBefore?.split(separator: ":").map(String.init).filter { !$0.hasPrefix("drop=") } ?? []
            decoderPropertyParts.append("drop=bidir")
            let decoderPropertyDuring = decoderPropertyParts.joined(separator: ":")
            if dispatchedIntent.fastPreview { player.setProperty(name: "video.decoder", value: decoderPropertyDuring) }
            let decoderPropertyAfter = player.property(name: "video.decoder") ?? "nil"
            DiagnosticsLogger.shared.playback("MDKDecoderTrace", "id=\\(dispatchedIntent.id) phase=pre-seek propertyBefore=\\(decoderPropertyBefore ?? \"nil\") propertyDuringRequested=\\(dispatchedIntent.fastPreview ? decoderPropertyDuring : \"unchanged\") propertyAfter=\\(decoderPropertyAfter) requestedPolicy=\\(dispatchedIntent.fastPreview ? \"bidir\" : \"unchanged-auto\") preserveExistingOptions=true")
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"accurate-incache-bidir-preserve\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")
'''
if text.count(old_policy) != 1:
    raise SystemExit(f"expected one Build126 decoder-policy anchor, found {text.count(old_policy)}")
text = text.replace(old_policy, new_policy, 1)

old_restore = '''                    guard let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=\\(actualMs) current=false action=discard-stale-player-generation requestGeneration=\\(dispatchedIntent.playerGeneration) activeGeneration=\\(self.generation)")
                        return
                    }
                    guard self.activeNativeSeek?.id == dispatchedIntent.id else {
'''
new_restore = '''                    guard let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=\\(actualMs) current=false action=discard-stale-player-generation requestGeneration=\\(dispatchedIntent.playerGeneration) activeGeneration=\\(self.generation)")
                        return
                    }
                    if dispatchedIntent.fastPreview {
                        if let decoderPropertyBefore, !decoderPropertyBefore.isEmpty {
                            player.setProperty(name: "video.decoder", value: decoderPropertyBefore)
                        } else {
                            player.setProperty(name: "video.decoder", value: "drop=auto")
                        }
                        let decoderPropertyRestored = player.property(name: "video.decoder") ?? "nil"
                        DiagnosticsLogger.shared.playback("MDKDecoderTrace", "id=\\(dispatchedIntent.id) phase=callback-restore restoreRequested=\\(decoderPropertyBefore ?? \"drop=auto\") propertyAfter=\\(decoderPropertyRestored) restoreExactOriginal=\\(decoderPropertyBefore != nil)")
                    }
                    guard self.activeNativeSeek?.id == dispatchedIntent.id else {
'''
if text.count(old_restore) != 1:
    raise SystemExit(f"expected one Build126 callback anchor, found {text.count(old_restore)}")
text = text.replace(old_restore, new_restore, 1)

path.write_text(text)
final = path.read_text()
assert 'decoderPropertyParts.append("drop=bidir")' in final
assert 'value: decoderPropertyDuring' in final
assert 'value: decoderPropertyBefore' in final
assert 'accurate-incache-bidir-preserve' in final
assert 'preserveExistingOptions=true' in final
assert 'dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart' in final
assert 'swift_mdk.logLevel = .All' in final
print("Applied Build128 corrected bidir drop experiment preserving decoder properties")
