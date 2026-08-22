from pathlib import Path

path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
text = path.read_text()

old_flag = '            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .FastFromStartInCache : .FromStart\n'
new_flag = '            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart\n'
if text.count(old_flag) != 1:
    raise SystemExit(f"expected exactly one Build124 seek flag anchor, found {text.count(old_flag)}")
text = text.replace(old_flag, new_flag, 1)

old_log = '            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"keyframe-preview\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")\n'
new_log = '            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"accurate-incache\" : \"accurate\") flagRaw=\\(seekFlag.rawValue) cacheAware=\\(dispatchedIntent.fastPreview) retry=\\(dispatchedIntent.retryCount)")\n'
if text.count(old_log) != 1:
    raise SystemExit(f"expected exactly one Build124 seek mode log anchor, found {text.count(old_log)}")
text = text.replace(old_log, new_log, 1)

path.write_text(text)

final = path.read_text()
assert 'dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart' in final
assert 'nativeMode=\\(dispatchedIntent.fastPreview ? "accurate-incache" : "accurate")' in final
assert 'dispatchedIntent.fastPreview ? .FastFromStartInCache : .FromStart' not in final
print("Applied Build125 relative Accurate+InCache A/B source change")
