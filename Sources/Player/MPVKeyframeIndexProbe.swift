import Foundation

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
