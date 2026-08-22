import Foundation

struct OnePlayerSessionKeyframeGap: Sendable {
    let previous: Double
    let next: Double

    var span: Double { max(0, next - previous) }

    func contains(_ target: Double) -> Bool { target >= previous - 0.0005 && target <= next + 0.0005 }

    func neighbors(around target: Double) -> OnePlayerKeyframeNeighbors {
        let nearest = abs(target - previous) <= abs(next - target) ? previous : next
        return OnePlayerKeyframeNeighbors(previous: previous, next: next, nearest: nearest, previousStatus: "session-gap-cache", nextStatus: "session-gap-cache")
    }
}

final class OnePlayerSessionKeyframeMap: @unchecked Sendable {
    private let lock = NSLock()
    private var gaps: [OnePlayerSessionKeyframeGap] = []
    private static let maximumGapCount = 4096

    func clear() {
        lock.lock(); gaps.removeAll(keepingCapacity: false); lock.unlock()
    }

    @discardableResult
    func record(_ neighbors: OnePlayerKeyframeNeighbors) -> Int {
        guard let previous = neighbors.previous, let next = neighbors.next, previous.isFinite, next.isFinite, previous >= 0, next >= previous else { return count }
        let gap = OnePlayerSessionKeyframeGap(previous: previous, next: next)
        lock.lock()
        defer { lock.unlock() }
        let insertion = lowerBound(previous)
        if insertion < gaps.count, abs(gaps[insertion].previous - previous) < 0.0005, abs(gaps[insertion].next - next) < 0.0005 { return gaps.count }
        if insertion > 0, abs(gaps[insertion - 1].previous - previous) < 0.0005, abs(gaps[insertion - 1].next - next) < 0.0005 { return gaps.count }
        gaps.insert(gap, at: insertion)
        if gaps.count > Self.maximumGapCount { gaps.removeFirst(gaps.count - Self.maximumGapCount) }
        return gaps.count
    }

    func neighbors(around target: Double) -> (neighbors: OnePlayerKeyframeNeighbors, gap: OnePlayerSessionKeyframeGap, count: Int)? {
        guard target.isFinite, target >= 0 else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard !gaps.isEmpty else { return nil }
        var index = upperBound(target) - 1
        if index < 0 { index = 0 }
        let lower = max(0, index - 1)
        let upper = min(gaps.count - 1, index + 1)
        guard lower <= upper else { return nil }
        var best: OnePlayerSessionKeyframeGap?
        for candidateIndex in lower...upper {
            let candidate = gaps[candidateIndex]
            guard candidate.contains(target) else { continue }
            if best == nil || candidate.span < best!.span { best = candidate }
        }
        guard let gap = best else { return nil }
        return (gap.neighbors(around: target), gap, gaps.count)
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return gaps.count
    }

    private func lowerBound(_ value: Double) -> Int {
        var low = 0
        var high = gaps.count
        while low < high {
            let mid = (low + high) / 2
            if gaps[mid].previous < value { low = mid + 1 } else { high = mid }
        }
        return low
    }

    private func upperBound(_ value: Double) -> Int {
        var low = 0
        var high = gaps.count
        while low < high {
            let mid = (low + high) / 2
            if gaps[mid].previous <= value { low = mid + 1 } else { high = mid }
        }
        return low
    }
}
