import Foundation

@main
struct RangeMapSmoke {
    static func main() {
        let mib: Int64 = 1_048_576
        let segment = 32 * mib
        let resource = 512 * mib
        var map = PlaybackRangeMap()

        let a = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2), "missing lane A claim")
        precondition(a == 0..<(32 * mib), "lane A must start at frontier")
        map.setDownloading(a, lane: "A")

        let b = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2), "missing lane B claim")
        precondition(b == (32 * mib)..<(64 * mib), "lane B must be adjacent to lane A")
        map.setDownloading(b, lane: "B")
        precondition(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2) == nil, "two workers must not open a third segment")

        map.insertPlayback(b)
        map.clearDownloading(lane: "B")
        precondition(map.contiguousFrontier(from: 0) == 0, "completed lane B must not jump over lane A hole")
        precondition(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2) == nil, "lane B completion must still wait for lane A")

        map.insertPlayback(0..<(8 * mib))
        precondition(map.contiguousFrontier(from: 0) == 8 * mib, "partial lane A should advance only to delivered bytes")
        map.clearDownloading(lane: "A")
        let repair = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2), "missing hole repair")
        precondition(repair == (8 * mib)..<(32 * mib), "scheduler must repair the earliest hole")
        map.insertPlayback(repair)
        precondition(map.contiguousFrontier(from: 0) == 64 * mib, "frontier should merge through already-complete lane B")

        map.insertMetadata((resource - 16 * mib)..<resource)
        let snapshot = map.snapshot(anchor: 0, resourceLength: resource)
        precondition(snapshot.frontierByte == 64 * mib, "metadata must not advance playback frontier")
        precondition(snapshot.metadataBytes == 16 * mib, "metadata accounting mismatch")
        precondition(snapshot.playbackBytes == 64 * mib, "playback accounting mismatch")

        let next = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2), "missing next sequential claim")
        precondition(next == (64 * mib)..<(96 * mib), "next claim must continue sequentially")
        print("RangeMap smoke OK: adjacent workers, hole repair, metadata isolation")
    }

    private static func require<T>(_ value: T?, _ message: String) -> T {
        guard let value else { fatalError(message) }
        return value
    }
}
