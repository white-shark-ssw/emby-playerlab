import Foundation

@main
struct RangeMapSmoke {
    static func main() {
        let mib: Int64 = 1_048_576
        let segment = 32 * mib
        let resource = 512 * mib
        var map = PlaybackRangeMap()

        let a = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2, lookaheadSegments: 4), "missing lane A claim")
        precondition(a == 0..<(32 * mib), "lane A must start at frontier")
        map.setDownloading(a, lane: "A")

        let b = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2, lookaheadSegments: 4), "missing lane B claim")
        precondition(b == (32 * mib)..<(64 * mib), "lane B must be adjacent to lane A")
        map.setDownloading(b, lane: "B")

        map.insertPlayback(b)
        map.clearDownloading(lane: "B")
        precondition(map.contiguousFrontier(from: 0) == 0, "completed lane B must not jump over lane A hole")
        let bNext = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2, lookaheadSegments: 4), "fast lane B should receive bounded lookahead work")
        precondition(bNext == (64 * mib)..<(96 * mib), "lane B lookahead must stay directly behind cached/downloading chain")
        map.setDownloading(bNext, lane: "B")

        map.insertPlayback(0..<(8 * mib))
        precondition(map.contiguousFrontier(from: 0) == 8 * mib, "partial lane A should advance only to delivered bytes")
        map.clearDownloading(lane: "A")
        let repair = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2, lookaheadSegments: 4), "missing earliest hole repair")
        precondition(repair == (8 * mib)..<(32 * mib), "scheduler must repair the earliest hole before extending lookahead")
        map.insertPlayback(repair)
        precondition(map.contiguousFrontier(from: 0) == 64 * mib, "frontier should merge through already-complete lane B")

        map.insertPlayback(bNext)
        map.clearDownloading(lane: "B")
        precondition(map.contiguousFrontier(from: 0) == 96 * mib, "frontier should advance after lookahead segment becomes contiguous")

        map.insertMetadata((resource - 16 * mib)..<resource)
        let snapshot = map.snapshot(anchor: 0, resourceLength: resource)
        precondition(snapshot.frontierByte == 96 * mib, "metadata must not advance playback frontier")
        precondition(snapshot.metadataBytes == 16 * mib, "metadata accounting mismatch")
        precondition(snapshot.playbackBytes == 96 * mib, "playback accounting mismatch")

        let next = require(map.nextClaim(from: 0, resourceLength: resource, segmentBytes: segment, workerLimit: 2, lookaheadSegments: 4), "missing next sequential claim")
        precondition(next == (96 * mib)..<(128 * mib), "next claim must continue the contiguous pipeline")

        precondition(map.playbackBytes(in: (32 * mib)..<(80 * mib)) == 48 * mib, "window byte accounting mismatch")
        map.removePlayback((32 * mib)..<(64 * mib))
        precondition(map.playbackBytes(in: 0..<(96 * mib)) == 64 * mib, "rolling eviction accounting mismatch")
        precondition(map.contiguousFrontier(from: 0) == 32 * mib, "rolling eviction must reopen the evicted sparse hole")
        print("RangeMap smoke OK: bounded lookahead, earliest-hole repair, metadata isolation, rolling-window accounting")
    }

    private static func require<T>(_ value: T?, _ message: String) -> T {
        guard let value else { fatalError(message) }
        return value
    }
}
