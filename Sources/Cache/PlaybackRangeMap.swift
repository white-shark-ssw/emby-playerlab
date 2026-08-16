import Foundation

struct PlaybackByteRangeSnapshot: Equatable {
    let playbackRanges: [Range<Int64>]
    let metadataRanges: [Range<Int64>]
    let downloadingRanges: [String: Range<Int64>]
    let anchorByte: Int64
    let frontierByte: Int64
    let playbackBytes: Int64
    let metadataBytes: Int64
    let holeCount: Int
}

struct PlaybackRangeMap: Equatable {
    private(set) var playback = SparseByteRangeSet()
    private(set) var metadata = SparseByteRangeSet()
    private(set) var downloading: [String: Range<Int64>] = [:]

    mutating func insertPlayback(_ range: Range<Int64>) { playback.insert(range) }
    mutating func removePlayback(_ range: Range<Int64>) { playback.remove(range) }
    mutating func insertMetadata(_ range: Range<Int64>) { metadata.insert(range) }
    mutating func setDownloading(_ range: Range<Int64>?, lane: String) { downloading[lane] = range }
    mutating func clearDownloading(lane: String) { downloading.removeValue(forKey: lane) }

    func contiguousFrontier(from anchor: Int64) -> Int64 {
        guard let range = playback.ranges.first(where: { $0.lowerBound <= anchor && $0.upperBound > anchor }) else { return anchor }
        return range.upperBound
    }

    func contiguousLength(from anchor: Int64, resourceLength: Int64) -> Int64 {
        let frontier = contiguousFrontier(from: anchor)
        let upper = resourceLength > 0 ? min(frontier, resourceLength) : frontier
        return max(0, upper - anchor)
    }

    func nextClaim(from anchor: Int64, resourceLength: Int64, segmentBytes: Int64, workerLimit: Int, lookaheadSegments: Int? = nil) -> Range<Int64>? {
        guard segmentBytes > 0, workerLimit > 0 else { return nil }
        let frontier = contiguousFrontier(from: anchor)
        let hardUpper = resourceLength > 0 ? resourceLength : Int64.max
        guard frontier < hardUpper else { return nil }
        let relativeFrontier = max(0, frontier - anchor)
        let windowBase = anchor + (relativeFrontier / segmentBytes) * segmentBytes
        let pipelineSegments = max(workerLimit, lookaheadSegments ?? workerLimit)
        let windowUpper = min(hardUpper, safeAdd(windowBase, segmentBytes * Int64(pipelineSegments)))
        var cursor = frontier

        while cursor < windowUpper {
            if let cached = playback.ranges.first(where: { $0.lowerBound <= cursor && $0.upperBound > cursor }) {
                cursor = min(windowUpper, cached.upperBound)
                continue
            }
            if let active = downloading.values.sorted(by: { $0.lowerBound < $1.lowerBound }).first(where: { $0.lowerBound <= cursor && $0.upperBound > cursor }) {
                cursor = min(windowUpper, active.upperBound)
                continue
            }
            let nextBoundary = min(windowUpper, safeAdd(cursor, segmentBytes))
            let nextCachedStart = playback.ranges.filter { $0.lowerBound > cursor }.map(\.lowerBound).min() ?? nextBoundary
            let nextActiveStart = downloading.values.filter { $0.lowerBound > cursor }.map(\.lowerBound).min() ?? nextBoundary
            let end = min(nextBoundary, nextCachedStart, nextActiveStart)
            if end > cursor { return cursor..<end }
            cursor += 1
        }
        return nil
    }

    func snapshot(anchor: Int64, resourceLength: Int64) -> PlaybackByteRangeSnapshot {
        let frontier = contiguousFrontier(from: anchor)
        return PlaybackByteRangeSnapshot(
            playbackRanges: playback.ranges,
            metadataRanges: metadata.ranges,
            downloadingRanges: downloading,
            anchorByte: anchor,
            frontierByte: resourceLength > 0 ? min(frontier, resourceLength) : frontier,
            playbackBytes: playback.totalBytes,
            metadataBytes: metadata.totalBytes,
            holeCount: physicalHoleCount(from: anchor, through: furthestObservedEnd(resourceLength: resourceLength))
        )
    }

    private func furthestObservedEnd(resourceLength: Int64) -> Int64 {
        let value = playback.ranges.map(\.upperBound).max() ?? 0
        return resourceLength > 0 ? min(value, resourceLength) : value
    }

    private func physicalHoleCount(from anchor: Int64, through upperBound: Int64) -> Int {
        guard upperBound > anchor else { return 0 }
        var coverage = playback.ranges
        coverage.sort { $0.lowerBound < $1.lowerBound }
        var cursor = anchor
        var holes = 0
        for range in coverage where range.upperBound > anchor && range.lowerBound < upperBound {
            let lower = max(anchor, range.lowerBound)
            if lower > cursor { holes += 1 }
            cursor = max(cursor, min(upperBound, range.upperBound))
            if cursor >= upperBound { break }
        }
        if cursor < upperBound { holes += 1 }
        return holes
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        if rhs > 0, lhs > Int64.max - rhs { return Int64.max }
        if rhs < 0, lhs < Int64.min - rhs { return Int64.min }
        return lhs + rhs
    }
}
