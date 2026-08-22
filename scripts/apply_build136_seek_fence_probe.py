from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


app = Path("Sources/Core/AppIdentity.swift")
text = app.read_text()
if '"0.13.69"' not in text:
    count = text.count('"0.13.67"')
    if count != 2:
        raise SystemExit(f"AppIdentity version anchors: expected 2, got {count}")
    text = text.replace('"0.13.67"', '"0.13.69"')
    app.write_text(text)

engine = Path("Sources/Player/MPVPlayerEngine.swift")
text = engine.read_text()

old_state = '''    private var playbackRateGeneration: UInt64 = 0
    private var seekGeneration: UInt64 = 0
    private let sharedTransportSession: TransportDataSession?
'''
new_state = '''    private var playbackRateGeneration: UInt64 = 0
    private var seekGeneration: UInt64 = 0
    private var latestNativeSeekDispatchID: UInt64?
    private var activeSeekingEpochID: UInt64?
    private var seekingPropertyActive = false
    private let sharedTransportSession: TransportDataSession?
'''
if "private var activeSeekingEpochID" not in text:
    text = replace_once(text, old_state, new_state, "seek fence state")

old_dispatch = '''                let dispatchAt = CACurrentMediaTime()
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.3f", target), mode])
'''
new_dispatch = '''                let dispatchAt = CACurrentMediaTime()
                self.latestNativeSeekDispatchID = seekID
                self.activeSeekingEpochID = nil
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(seekID) phase=native-dispatch owner=awaiting-seeking-true")
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.3f", target), mode])
'''
if 'owner=awaiting-seeking-true' not in text:
    text = replace_once(text, old_dispatch, new_dispatch, "seek native dispatch")

old_properties = '''            ("seekable", MPV_FORMAT_FLAG),
            ("partially-seekable", MPV_FORMAT_FLAG),
            ("demuxer-via-network", MPV_FORMAT_FLAG)
'''
new_properties = '''            ("seekable", MPV_FORMAT_FLAG),
            ("partially-seekable", MPV_FORMAT_FLAG),
            ("seeking", MPV_FORMAT_FLAG),
            ("demuxer-via-network", MPV_FORMAT_FLAG)
'''
if '("seeking", MPV_FORMAT_FLAG)' not in text:
    text = replace_once(text, old_properties, new_properties, "observe seeking property")

old_property_case = '''        case MPV_EVENT_PROPERTY_CHANGE:
            if let namePointer = event.data?.assumingMemoryBound(to: mpv_event_property.self).pointee.name { refreshProperty(name: String(cString: namePointer), handle: handle) }
'''
new_property_case = '''        case MPV_EVENT_PROPERTY_CHANGE:
            if let propertyPointer = event.data?.assumingMemoryBound(to: mpv_event_property.self), let namePointer = propertyPointer.pointee.name {
                let name = String(cString: namePointer)
                if name == "seeking", propertyPointer.pointee.format == MPV_FORMAT_FLAG, let data = propertyPointer.pointee.data {
                    let active = data.assumingMemoryBound(to: Int32.self).pointee != 0
                    handleSeekingPropertyChange(active)
                } else { refreshProperty(name: name, handle: handle) }
            }
'''
if 'handleSeekingPropertyChange(active)' not in text:
    text = replace_once(text, old_property_case, new_property_case, "property change routing")

old_restart = '''        case MPV_EVENT_PLAYBACK_RESTART:
            snapshot.isBuffering = false
            snapshot.waitingReason = nil

            var actualPosition = snapshot.position
            var queriedPosition = Double(0)
            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0, queriedPosition.isFinite {
                actualPosition = queriedPosition
                snapshot.position = queriedPosition
            }

            if let pending = pendingSeek {
                pendingSeek = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                let delta = actualPosition - pending.target
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) event=playback-restart")
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(
                        requestedAt: pending.requestedAt,
                        target: pending.target,
                        actualPosition: actualPosition,
                        bufferHit: pending.bufferHit,
                        completionLatencyMs: latency,
                        measurement: "MPV playback-restart after latest seek"
                    ))
                }
            } else {
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: \"%.3f\", actualPosition)) event=playback-restart-without-pending")
            }
            emitOnMain()
'''
new_restart = '''        case MPV_EVENT_PLAYBACK_RESTART:
            var actualPosition = snapshot.position
            var queriedPosition = Double(0)
            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0, queriedPosition.isFinite {
                actualPosition = queriedPosition
                snapshot.position = queriedPosition
            }

            if let pending = pendingSeek, pending.id > 0, activeSeekingEpochID != pending.id {
                snapshot.isBuffering = true
                snapshot.waitingReason = "MPV seek"
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=playback-restart ignored=true reason=no-latest-seeking-epoch actual=\\(String(format: \"%.3f\", actualPosition)) nativeOwner=\\(latestNativeSeekDispatchID.map(String.init) ?? \"none\") seekingOwner=\\(activeSeekingEpochID.map(String.init) ?? \"none\") seeking=\\(seekingPropertyActive)")
                emitOnMain()
                return
            }

            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            if let pending = pendingSeek {
                pendingSeek = nil
                latestNativeSeekDispatchID = nil
                activeSeekingEpochID = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                let delta = actualPosition - pending.target
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=playback-restart accepted=true owner=seeking-epoch")
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) event=playback-restart")
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(
                        requestedAt: pending.requestedAt,
                        target: pending.target,
                        actualPosition: actualPosition,
                        bufferHit: pending.bufferHit,
                        completionLatencyMs: latency,
                        measurement: "MPV playback-restart after latest seeking epoch"
                    ))
                }
            } else {
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: \"%.3f\", actualPosition)) event=playback-restart-without-pending")
            }
            emitOnMain()
'''
if 'reason=no-latest-seeking-epoch' not in text:
    text = replace_once(text, old_restart, new_restart, "playback restart fence")

refresh_anchor = '''    private func refreshProperty(name: String, handle: OpaquePointer) {
'''
seeking_handler = '''    private func handleSeekingPropertyChange(_ active: Bool) {
        seekingPropertyActive = active
        let pendingID = pendingSeek?.id
        if active, let pending = pendingSeek, pending.id > 0, latestNativeSeekDispatchID == pending.id {
            activeSeekingEpochID = pending.id
            DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=seeking-property active=true owner=claimed")
        } else {
            DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pendingID.map(String.init) ?? \"none\") phase=seeking-property active=\\(active) nativeOwner=\\(latestNativeSeekDispatchID.map(String.init) ?? \"none\") seekingOwner=\\(activeSeekingEpochID.map(String.init) ?? \"none\")")
        }
    }

    private func refreshProperty(name: String, handle: OpaquePointer) {
'''
if 'private func handleSeekingPropertyChange' not in text:
    text = replace_once(text, refresh_anchor, seeking_handler, "seeking property handler")

old_stop = '''        pendingSeek = nil
        pendingRendererLayout = nil
'''
new_stop = '''        pendingSeek = nil
        latestNativeSeekDispatchID = nil
        activeSeekingEpochID = nil
        seekingPropertyActive = false
        pendingRendererLayout = nil
'''
if 'activeSeekingEpochID = nil\n        seekingPropertyActive = false\n        pendingRendererLayout' not in text:
    text = replace_once(text, old_stop, new_stop, "stop fence reset")

old_initialized = '''        DiagnosticsLogger.shared.log("MPVVideo", "renderer=gpu-next gpu-api=vulkan gpu-context=moltenvk layer=CAMetalLayer hwdec=videotoolbox")
        observeProperties(handle)
'''
new_initialized = '''        DiagnosticsLogger.shared.log("MPVVideo", "renderer=gpu-next gpu-api=vulkan gpu-context=moltenvk layer=CAMetalLayer hwdec=videotoolbox")
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", OnePlayerKeyframeIndexProbe.runtimeDescription)
        observeProperties(handle)
'''
if 'OnePlayerKeyframeIndexProbe.runtimeDescription' not in text:
    text = replace_once(text, old_initialized, new_initialized, "keyframe probe log")

engine.write_text(text)

probe = Path("Sources/Player/MPVKeyframeIndexProbe.swift")
if not probe.exists():
    probe.write_text(r'''import Foundation

#if canImport(Libavformat) && canImport(Libavutil)
import Libavformat
import Libavutil

enum OnePlayerKeyframeIndexProbe {
    static var runtimeDescription: String { "backend=libavformat-direct avformat=\(avformat_version()) avutil=\(avutil_version())" }
}

@_cdecl("oneplayer_keyframe_backend_libavformat_direct")
func oneplayerKeyframeBackendProbe() -> Int32 { avformat_version() > 0 && avutil_version() > 0 ? 1 : 0 }
#else
enum OnePlayerKeyframeIndexProbe {
    static let runtimeDescription = "backend=unavailable reason=Libavformat-or-Libavutil-not-importable"
}

@_cdecl("oneplayer_keyframe_backend_unavailable")
func oneplayerKeyframeBackendProbe() -> Int32 { 0 }
#endif
''')
