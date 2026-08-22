import Foundation

#if canImport(Libavformat) && canImport(Libavutil)
import Libavformat
import Libavutil

enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_LIBAVFORMAT_DIRECT"
    static var runtimeDescription: String { "\(backendMarker) backend=libavformat-direct avformat=\(avformat_version()) avutil=\(avutil_version())" }
}
#else
enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_UNAVAILABLE"
    static var runtimeDescription: String { "\(backendMarker) backend=unavailable reason=Libavformat-or-Libavutil-not-importable" }
}
#endif
