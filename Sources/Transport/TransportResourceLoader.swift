import AVFoundation
import Foundation
import UniformTypeIdentifiers

final class TransportResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    let session: MediaTransportSession

    private let queue = DispatchQueue(label: "com.embyplayerlab.transport.resource-loader")
    private let lock = NSLock()
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var invalidated = false

    init(session: MediaTransportSession) {
        self.session = session
    }

    func makeAsset(fileExtension: String) -> AVURLAsset {
        let normalizedExtension = fileExtension.isEmpty ? "mp4" : fileExtension
        let url = URL(string: "embytransport://session/media.\(normalizedExtension)")!
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(self, queue: queue)
        return asset
    }

    func invalidate() {
        let runningTasks = invalidateAndTakeTasks()
        runningTasks.forEach { $0.cancel() }
        Task { await session.stop() }
    }

    func metrics() async -> TransportMetricsSnapshot {
        await session.metrics()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard !isInvalidated() else { return false }

        let identifier = ObjectIdentifier(loadingRequest)
        let task = Task { [weak self, loadingRequest] in
            guard let self else { return }
            do {
                try await self.fulfill(loadingRequest)
            } catch is CancellationError {
                // AVFoundation already cancelled this request; do not finish it twice.
            } catch {
                DiagnosticsLogger.shared.log("TransportLoader", "request failed: \(error.localizedDescription)")
                self.finish(loadingRequest, error: error)
            }
            _ = self.removeTask(for: identifier)
        }

        DiagnosticsLogger.shared.log(
            "TransportLoader",
            "request accepted offset=\(loadingRequest.dataRequest?.requestedOffset ?? -1) length=\(loadingRequest.dataRequest?.requestedLength ?? 0) allToEnd=\(loadingRequest.dataRequest?.requestsAllDataToEndOfResource ?? false)"
        )
        storeTask(task, for: identifier)
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let identifier = ObjectIdentifier(loadingRequest)
        removeTask(for: identifier)?.cancel()
    }

    private func isInvalidated() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return invalidated
    }

    private func storeTask(_ task: Task<Void, Never>, for identifier: ObjectIdentifier) {
        lock.lock()
        tasks[identifier] = task
        lock.unlock()
    }

    @discardableResult
    private func removeTask(for identifier: ObjectIdentifier) -> Task<Void, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return tasks.removeValue(forKey: identifier)
    }

    private func invalidateAndTakeTasks() -> [Task<Void, Never>] {
        lock.lock()
        defer { lock.unlock() }
        invalidated = true
        let runningTasks = Array(tasks.values)
        tasks.removeAll()
        return runningTasks
    }

    private func fulfill(_ loadingRequest: AVAssetResourceLoadingRequest) async throws {
        let resource = try await session.resolve()
        if let info = loadingRequest.contentInformationRequest {
            let type = resource.contentType.flatMap { UTType(mimeType: $0)?.identifier }
                ?? UTType(filenameExtension: resource.finalURL.pathExtension)?.identifier
                ?? AVFileType.mp4.rawValue
            queue.sync {
                info.contentType = type
                info.contentLength = resource.contentLength
                info.isByteRangeAccessSupported = true
            }
        }

        guard let dataRequest = loadingRequest.dataRequest else {
            finish(loadingRequest, error: nil)
            return
        }

        var cursor = max(dataRequest.requestedOffset, dataRequest.currentOffset)
        let requestedEnd: Int64
        if dataRequest.requestsAllDataToEndOfResource {
            requestedEnd = resource.contentLength
        } else {
            requestedEnd = min(resource.contentLength, dataRequest.requestedOffset + Int64(dataRequest.requestedLength))
        }

        let deliveryChunk = 1_048_576
        while cursor < requestedEnd {
            try Task.checkCancellation()
            let length = min(deliveryChunk, Int(requestedEnd - cursor))
            let data = try await session.read(offset: cursor, length: length)
            guard !data.isEmpty else { break }
            queue.sync { dataRequest.respond(with: data) }
            cursor += Int64(data.count)
        }
        finish(loadingRequest, error: nil)
    }

    private func finish(_ request: AVAssetResourceLoadingRequest, error: Error?) {
        queue.async {
            if let error {
                request.finishLoading(with: error)
            } else {
                request.finishLoading()
            }
        }
    }
}
