import Foundation

protocol TransportDataSession: AnyObject {
    func resolve() async throws -> TransportResolvedResource
    func noteDemand(range: Range<Int64>) async
    func read(offset: Int64, length: Int) async throws -> Data
    func readCachedMetadata(offset: Int64, length: Int) async -> Data?
    func prioritizeSeek(position: Double, duration: Double) async
    func prioritizeOffset(_ offset: Int64) async
    func confirmConcretePlaybackByte(_ offset: Int64) async
    func reportPlaybackProgress(position: Double, isBuffering: Bool) async
    func recoverStall(position: Double, duration: Double) async
    func setPlaybackAdvancing(_ advancing: Bool) async
    func confirmInitialResumePlayback() async
    func metrics() async -> TransportMetricsSnapshot
    func stop() async
}

extension TransportDataSession {
    func noteDemand(range: Range<Int64>) async {}
    func readCachedMetadata(offset: Int64, length: Int) async -> Data? { nil }
    func prioritizeOffset(_ offset: Int64) async { await noteDemand(range: offset..<(offset + 1)) }
    func confirmConcretePlaybackByte(_ offset: Int64) async {}
    func reportPlaybackProgress(position: Double, isBuffering: Bool) async {}
    func recoverStall(position: Double, duration: Double) async {}
    func setPlaybackAdvancing(_ advancing: Bool) async {}
    func confirmInitialResumePlayback() async {}
}

extension MediaTransportSession: TransportDataSession {}
