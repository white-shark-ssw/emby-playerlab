import Foundation

#if canImport(Libavformat) && canImport(Libavutil)
import Libavformat
import Libavutil

@_cdecl("oneplayer_keyframe_backend_libavformat_direct")
func oneplayerKeyframeBackendProbe() -> Int32 { avformat_version() > 0 && avutil_version() > 0 ? 1 : 0 }

enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_LIBAVFORMAT_DIRECT"
    static var runtimeDescription: String { "\(backendMarker) backend=libavformat-direct probe=\(oneplayerKeyframeBackendProbe()) avformat=\(avformat_version()) avutil=\(avutil_version())" }
}
#else
@_cdecl("oneplayer_keyframe_backend_unavailable")
func oneplayerKeyframeBackendProbe() -> Int32 { 0 }

enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_UNAVAILABLE"
    static var runtimeDescription: String { "\(backendMarker) backend=unavailable probe=\(oneplayerKeyframeBackendProbe()) reason=Libavformat-or-Libavutil-not-importable" }
}
#endif
