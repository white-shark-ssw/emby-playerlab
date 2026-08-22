from pathlib import Path

path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
text = path.read_text()

old_logging = '''        swift_mdk.logLevel = .Info
        swift_mdk.setLogHandler { level, message in
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if let marker = trimmed.range(of: "***buffering progress "), let percentEnd = trimmed[marker.upperBound...].firstIndex(of: "%"), let percent = Int(trimmed[marker.upperBound..<percentEnd]), percent != 0, percent != 25, percent != 50, percent != 75, percent != 100 { return }
            DiagnosticsLogger.shared.playback("MDKNative", "level=\\(String(describing: level)) \\(trimmed)")
        }
'''
new_logging = '''        swift_mdk.logLevel = .All
        swift_mdk.setLogHandler { level, message in
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if let marker = trimmed.range(of: "***buffering progress "), let percentEnd = trimmed[marker.upperBound...].firstIndex(of: "%"), let percent = Int(trimmed[marker.upperBound..<percentEnd]), percent != 0, percent != 25, percent != 50, percent != 75, percent != 100 { return }
            if level == .Debug || level == .All {
                let lower = trimmed.lowercased()
                guard lower.contains("drop") || lower.contains("decoder") || lower.contains("seek") || lower.contains("sync") || lower.contains("vt") else { return }
            }
            DiagnosticsLogger.shared.playback("MDKNative", "level=\\(String(describing: level)) \\(trimmed)")
        }
'''
if text.count(old_logging) != 1:
    raise SystemExit(f"expected one MDK logging anchor, found {text.count(old_logging)}")
text = text.replace(old_logging, new_logging, 1)

old_seek = '''            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"accurate-incache\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")
            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: seekFlag) { [weak self, weak player] actualMs in
'''
new_seek = '''            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart
            let decoderProperty = player.property(name: "video.decoder") ?? "nil"
            DiagnosticsLogger.shared.playback("MDKDecoderTrace", "id=\\(dispatchedIntent.id) phase=pre-seek property=\\(decoderProperty) requestedPolicy=unchanged-default-auto")
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"accurate-incache\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")
            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: seekFlag) { [weak self, weak player] actualMs in
'''
if text.count(old_seek) != 1:
    raise SystemExit(f"expected one Build125 seek anchor, found {text.count(old_seek)}")
text = text.replace(old_seek, new_seek, 1)

path.write_text(text)
final = path.read_text()
assert 'swift_mdk.logLevel = .All' in final
assert 'MDKDecoderTrace' in final
assert 'requestedPolicy=unchanged-default-auto' in final
assert 'dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart' in final
assert 'player.setProperty(name: "video.decoder"' not in final
print("Applied Build126 decoder-drop trace instrumentation without changing decoder policy")
