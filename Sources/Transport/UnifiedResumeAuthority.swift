import Foundation

extension UnifiedMediaTransportSession {
    func confirmConcretePlaybackByte(_ offset: Int64) async {
        guard offset >= 0 else { return }
        DiagnosticsLogger.shared.playback("Resume", "exact-byte authority confirmed offset=\(offset) source=engine-consumption byteGuess=disabled")
        // Reuse the established seek-authority path only as an authority token. The following
        // byte offset is an exact engine-consumed byte, never a media-time/file-size estimate.
        await prioritizeSeek(position: 0, duration: 0)
        await prioritizeOffset(offset)
    }
}
