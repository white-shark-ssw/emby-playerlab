import Foundation

struct SparseStoredRange: Codable, Equatable {
    let lowerBound: Int64
    let upperBound: Int64

    var range: Range<Int64> { lowerBound..<upperBound }
}

struct SparseByteRangeSet: Equatable {
    private(set) var ranges: [Range<Int64>] = []

    init(ranges: [Range<Int64>] = []) {
        ranges.forEach { insert($0) }
    }

    mutating func insert(_ newRange: Range<Int64>) {
        guard !newRange.isEmpty else { return }
        var merged = newRange
        var output: [Range<Int64>] = []
        var inserted = false

        for range in ranges {
            if range.upperBound < merged.lowerBound {
                output.append(range)
            } else if merged.upperBound < range.lowerBound {
                if !inserted {
                    output.append(merged)
                    inserted = true
                }
                output.append(range)
            } else {
                merged = min(range.lowerBound, merged.lowerBound)..<max(range.upperBound, merged.upperBound)
            }
        }

        if !inserted { output.append(merged) }
        ranges = output
    }

    mutating func remove(_ removal: Range<Int64>) {
        guard !removal.isEmpty else { return }
        var output: [Range<Int64>] = []
        output.reserveCapacity(ranges.count + 1)

        for range in ranges {
            guard range.overlaps(removal) else {
                output.append(range)
                continue
            }
            if range.lowerBound < removal.lowerBound {
                let left = range.lowerBound..<min(range.upperBound, removal.lowerBound)
                if !left.isEmpty { output.append(left) }
            }
            if range.upperBound > removal.upperBound {
                let right = max(range.lowerBound, removal.upperBound)..<range.upperBound
                if !right.isEmpty { output.append(right) }
            }
        }
        ranges = output
    }

    func contains(_ range: Range<Int64>) -> Bool {
        guard !range.isEmpty else { return true }
        return ranges.contains { $0.lowerBound <= range.lowerBound && $0.upperBound >= range.upperBound }
    }

    func contiguousLength(from offset: Int64, maximumLength: Int64) -> Int64 {
        guard maximumLength > 0 else { return 0 }
        guard let range = ranges.first(where: { $0.lowerBound <= offset && $0.upperBound > offset }) else { return 0 }
        return min(maximumLength, range.upperBound - offset)
    }

    func firstMissingOffset(from offset: Int64, upperBound: Int64) -> Int64? {
        guard offset < upperBound else { return nil }
        var cursor = offset
        for range in ranges where range.upperBound > cursor {
            if range.lowerBound > cursor { return cursor }
            cursor = max(cursor, range.upperBound)
            if cursor >= upperBound { return nil }
        }
        return cursor < upperBound ? cursor : nil
    }

    var totalBytes: Int64 {
        ranges.reduce(Int64(0)) { $0 + Int64($1.count) }
    }

    var storedRanges: [SparseStoredRange] {
        ranges.map { SparseStoredRange(lowerBound: $0.lowerBound, upperBound: $0.upperBound) }
    }
}
