import Foundation

protocol TransportDataSession: AnyObject {
    func resolve() async throws -> TransportResolvedResource
    func read(offset: Int64, length: Int) async throws -> Data
    func prioritizeSeek(position: Double, duration: Double) async
    func metrics() async -> TransportMetricsSnapshot
    func stop() async
}

extension MediaTransportSession: TransportDataSession {}
