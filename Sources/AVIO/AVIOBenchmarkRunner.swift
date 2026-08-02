import Foundation

final class AVIOBenchmarkRunner {
    private struct SessionOwner {
        let session: URLSession
        let delegate: AVIOBenchmarkSessionDelegate
        let tasks: [URLSessionDataTask]
    }

    func run(
        resource: TransportResolvedResource,
        configuration: AVIOBenchmarkConfiguration,
        onProgress: @MainActor @escaping (AVIOBenchmarkProgress) -> Void
    ) async throws -> AVIOBenchmarkResult {
        let startedAt = Date()
        let owners = try makeOwners(resource: resource, configuration: configuration)
        owners.flatMap(\.tasks).forEach { $0.resume() }

        var samples: [AVIOBenchmarkSample] = []
        var lastSampleAt = startedAt
        var lastSampleBytes: Int64 = 0

        do {
            while true {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 500_000_000)

                let now = Date()
                let lanes = owners.flatMap { $0.delegate.snapshot(now: now) }
                let totalBytes = lanes.reduce(Int64(0)) { $0 + $1.bytesReceived }
                let sampleElapsed = max(now.timeIntervalSince(lastSampleAt), 0.001)
                let currentSpeed = Double(totalBytes - lastSampleBytes) / sampleElapsed
                let activeCount = lanes.filter { !$0.completed }.count

                await onProgress(AVIOBenchmarkProgress(
                    mode: configuration.mode,
                    elapsedSeconds: now.timeIntervalSince(startedAt),
                    totalBytes: totalBytes,
                    currentBytesPerSecond: max(0, currentSpeed),
                    activeLaneCount: activeCount
                ))

                if now.timeIntervalSince(lastSampleAt) >= 1 {
                    samples.append(AVIOBenchmarkSample(
                        id: UUID(),
                        elapsedSeconds: now.timeIntervalSince(startedAt),
                        totalBytes: totalBytes,
                        currentBytesPerSecond: max(0, currentSpeed)
                    ))
                    lastSampleAt = now
                    lastSampleBytes = totalBytes
                }

                let reachedDuration = now.timeIntervalSince(startedAt) >= Double(configuration.durationSeconds)
                let allCompleted = !lanes.isEmpty && lanes.allSatisfy(\.completed)
                if reachedDuration || allCompleted { break }
            }
        } catch {
            stop(owners)
            throw error
        }

        stop(owners)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let finishedAt = Date()
        let lanes = owners.flatMap { $0.delegate.snapshot(now: finishedAt) }
        owners.forEach { $0.delegate.finishFiles(removeTemporaryFiles: true) }
        let totalBytes = lanes.reduce(Int64(0)) { $0 + $1.bytesReceived }
        let elapsed = max(finishedAt.timeIntervalSince(startedAt), 0.001)
        let firstByte = lanes.compactMap(\.firstByteMilliseconds).min()
        let statuses = Array(Set(lanes.compactMap(\.statusCode))).sorted()
        let redirectCount = lanes.reduce(0) { $0 + $1.redirectCount }
        let errors = lanes.compactMap(\.error)

        let result = AVIOBenchmarkResult(
            id: UUID(),
            createdAt: Date(),
            mode: configuration.mode,
            requestProfile: configuration.requestProfile,
            configuredDurationSeconds: configuration.durationSeconds,
            configuredTargetBytes: configuration.targetBytes,
            actualDurationSeconds: elapsed,
            contentLength: resource.contentLength,
            looksLike115CDN: resource.looksLike115CDN,
            totalBytesReceived: totalBytes,
            averageBytesPerSecond: Double(totalBytes) / elapsed,
            firstByteMilliseconds: firstByte,
            httpStatusCodes: statuses,
            redirectCount: redirectCount,
            lanes: lanes,
            samples: samples,
            error: errors.isEmpty ? nil : errors.joined(separator: " | ")
        )

        DiagnosticsLogger.shared.log(
            "AVIOLab",
            "mode=\(configuration.mode.rawValue) profile=\(configuration.requestProfile.rawValue) bytes=\(totalBytes) elapsed=\(elapsed) averageBps=\(Int(result.averageBytesPerSecond)) statuses=\(statuses) redirects=\(redirectCount)"
        )
        return result
    }

    private func makeOwners(resource: TransportResolvedResource, configuration: AVIOBenchmarkConfiguration) throws -> [SessionOwner] {
        let safeTarget = min(max(configuration.targetBytes, 1_048_576), resource.contentLength)
        switch configuration.mode {
        case .sharedSingleOpen:
            return [makeOwner(resource: resource, profile: configuration.requestProfile, ranges: [("lane-0", "bytes=0-", nil)], maximumConnections: 1)]
        case .sharedSingleFinite:
            let end = safeTarget - 1
            return [makeOwner(resource: resource, profile: configuration.requestProfile, ranges: [("lane-0", "bytes=0-\(end)", nil)], maximumConnections: 1)]
        case .sharedDualFinite:
            let half = max(Int64(1), safeTarget / 2)
            let firstEnd = half - 1
            let secondEnd = safeTarget - 1
            return [makeOwner(
                resource: resource,
                profile: configuration.requestProfile,
                ranges: [("lane-0", "bytes=0-\(firstEnd)", nil), ("lane-1", "bytes=\(half)-\(secondEnd)", nil)],
                maximumConnections: 2
            )]
        case .isolatedDualFinite:
            let half = max(Int64(1), safeTarget / 2)
            let first = makeOwner(resource: resource, profile: configuration.requestProfile, ranges: [("lane-0", "bytes=0-\(half - 1)", nil)], maximumConnections: 1)
            let second = makeOwner(resource: resource, profile: configuration.requestProfile, ranges: [("lane-1", "bytes=\(half)-\(safeTarget - 1)", nil)], maximumConnections: 1)
            return [first, second]
        case .sharedSingleDisk:
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("EmbyPlayerLab-AVIOLab", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("benchmark-\(UUID().uuidString).bin")
            return [makeOwner(
                resource: resource,
                profile: configuration.requestProfile,
                ranges: [("lane-0", "bytes=0-\(safeTarget - 1)", fileURL)],
                maximumConnections: 1
            )]
        }
    }

    private func makeOwner(
        resource: TransportResolvedResource,
        profile: AVIORequestProfile,
        ranges: [(label: String, header: String, fileURL: URL?)],
        maximumConnections: Int
    ) -> SessionOwner {
        let delegate = AVIOBenchmarkSessionDelegate(resource: resource)
        let session = AVIOBenchmarkSessionFactory.make(delegate: delegate, maximumConnections: maximumConnections)
        let tasks = ranges.map { item -> URLSessionDataTask in
            let request = AVIORequestBuilder.request(resource: resource, rangeHeader: item.header, profile: profile, timeout: 300)
            let task = session.dataTask(with: request)
            task.priority = URLSessionTask.highPriority
            delegate.register(task: task, label: item.label, requestedRange: item.header, fileURL: item.fileURL)
            return task
        }
        return SessionOwner(session: session, delegate: delegate, tasks: tasks)
    }

    private func stop(_ owners: [SessionOwner]) {
        owners.forEach { owner in
            owner.delegate.markStoppedByRunner()
            owner.tasks.forEach { $0.cancel() }
            owner.session.invalidateAndCancel()
        }
    }
}
