import Foundation

protocol TransportDataSession: AnyObject {
    func resolve() async throws -> TransportResolvedResource
    func noteDemand(range: Range<Int64>) async
    func read(offset: Int64, length: Int) async throws -> Data
    func prioritizeSeek(position: Double, duration: Double) async
    func prioritizeOffset(_ offset: Int64) async
    func recoverStall(position: Double, duration: Double) async
    func setPlaybackAdvancing(_ advancing: Bool) async
    func metrics() async -> TransportMetricsSnapshot
    func stop() async
}

extension TransportDataSession {
    func noteDemand(range: Range<Int64>) async {}
    func prioritizeOffset(_ offset: Int64) async { await noteDemand(range: offset..<(offset + 1)) }
    func recoverStall(position: Double, duration: Double) async {}
    func setPlaybackAdvancing(_ advancing: Bool) async {}
}

extension MediaTransportSession: TransportDataSession {}
