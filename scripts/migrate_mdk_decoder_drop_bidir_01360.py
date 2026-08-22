from pathlib import Path

path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
text = path.read_text()

old_policy = '''            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart
            let decoderProperty = player.property(name: "video.decoder") ?? "nil"
            DiagnosticsLogger.shared.playback("MDKDecoderTrace", "id=\\(dispatchedIntent.id) phase=pre-seek property=\\(decoderProperty) requestedPolicy=unchanged-default-auto")
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"accurate-incache\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")
'''
new_policy = '''            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart
            let decoderPropertyBefore = player.property(name: "video.decoder") ?? "nil"
            let experimentalDropPolicy = dispatchedIntent.fastPreview ? "bidir" : "auto"
            if dispatchedIntent.fastPreview { player.setProperty(name: "video.decoder", value: "drop=bidir") }
            let decoderPropertyAfter = player.property(name: "video.decoder") ?? "nil"
            DiagnosticsLogger.shared.playback("MDKDecoderTrace", "id=\\(dispatchedIntent.id) phase=pre-seek propertyBefore=\\(decoderPropertyBefore) propertyAfter=\\(decoderPropertyAfter) requestedPolicy=\\(experimentalDropPolicy) scope=relative-native-seek-only")
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"accurate-incache-bidir\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")
'''
if text.count(old_policy) != 1:
    raise SystemExit(f"expected one Build126 decoder-policy anchor, found {text.count(old_policy)}")
text = text.replace(old_policy, new_policy, 1)

old_restore = '''                    guard self.activeNativeSeek?.id == dispatchedIntent.id else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=\\(actualMs) action=discard-nonactive-native")
                        return
                    }

                    self.activeNativeSeek = nil
'''
new_restore = '''                    guard self.activeNativeSeek?.id == dispatchedIntent.id else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=\\(actualMs) action=discard-nonactive-native")
                        return
                    }
                    if dispatchedIntent.fastPreview {
                        player.setProperty(name: "video.decoder", value: "drop=auto")
                        let restoredDecoderProperty = player.property(name: "video.decoder") ?? "nil"
                        DiagnosticsLogger.shared.playback("MDKDecoderTrace", "id=\\(dispatchedIntent.id) phase=callback-restore requestedPolicy=auto property=\\(restoredDecoderProperty) scope=relative-native-seek-only")
                    }

                    self.activeNativeSeek = nil
'''
if text.count(old_restore) != 1:
    raise SystemExit(f"expected one active callback restore anchor, found {text.count(old_restore)}")
text = text.replace(old_restore, new_restore, 1)

path.write_text(text)
final = path.read_text()
assert 'value: "drop=bidir"' in final
assert 'value: "drop=auto"' in final
assert 'nativeMode=\\(dispatchedIntent.fastPreview ? "accurate-incache-bidir" : "accurate")' in final
assert 'scope=relative-native-seek-only' in final
assert 'dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart' in final
assert 'swift_mdk.logLevel = .All' in final
print("Applied Build127 relative-seek-only bidir decoder drop experiment")
