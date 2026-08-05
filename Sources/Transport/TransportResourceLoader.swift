import AVFoundation
import Foundation
import UniformTypeIdentifiers

final class TransportResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    let session: TransportDataSession
    private let stopSessionOnInvalidate: Bool

    private final class ActiveRequest {
        let token: UUID
        let request: AVAssetResourceLoadingRequest
        let range: Range<Int64>?
        var task: Task<Void, Never>?

        init(token: UUID, request: AVAssetResourceLoadingRequest, range: Range<Int64>?) {
            self.token = token
            self.request = request
            self.range = range
        }
    }

    private let queue = DispatchQueue(label: "com.embyplayerlab.transport.resource-loader", qos: .userInitiated)
    private let lock = NSLock()
    private var requests: [ObjectIdentifier: ActiveRequest] = [:]
    private var invalidated = false

    init(session: TransportDataSession, stopSessionOnInvalidate: Bool = true) {
        self.session = session
        self.stopSessionOnInvalidate = stopSessionOnInvalidate
    }

    func makeAsset(fileExtension: String) -> AVURLAsset {
        let normalizedExtension = fileExtension.isEmpty ? "mp4" : fileExtension
        let url = URL(string: "embytransport://session/media.\(normalizedExtension)")!
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(self, queue: queue)
        return asset
    }

    func prioritizeSeek(position: Double, duration: Double) {
        Task { [session] in await session.prioritizeSeek(position: position, duration: duration) }
    }

    func recoverStall(position: Double, duration: Double) {
        Task { [session] in await session.recoverStall(position: position, duration: duration) }
    }

    func invalidate() {
        let running = invalidateAndTakeRequests()
        running.forEach { $0.task?.cancel() }
        if stopSessionOnInvalidate { Task { [session] in await session.stop() } }
    }

    func metrics() async -> TransportMetricsSnapshot { await session.metrics() }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard !isInvalidated() else { return false }

        let identifier = ObjectIdentifier(loadingRequest)
        let token = UUID()
        let active = ActiveRequest(token: token, request: loadingRequest, range: requestedRange(for: loadingRequest))
        guard storeRequest(active, for: identifier) else { return false }

        let task = Task { [weak self, weak loadingRequest] in
            guard let self, let loadingRequest else { return }
            do {
                try await self.fulfill(loadingRequest)
                self.completeRequest(identifier: identifier, token: token, error: nil)
            } catch is CancellationError {
                self.removeRequest(for: identifier, matching: token)
            } catch {
                DiagnosticsLogger.shared.log("ResourceLoader", "request failed: \(error.localizedDescription)")
                self.completeRequest(identifier: identifier, token: token, error: error)
            }
        }
        guard attachTask(task, identifier: identifier, token: token) else {
            task.cancel()
            return true
        }

        DiagnosticsLogger.shared.log(
            "ResourceLoader",
            "accepted offset=\(loadingRequest.dataRequest?.requestedOffset ?? -1) length=\(loadingRequest.dataRequest?.requestedLength ?? 0) allToEnd=\(loadingRequest.dataRequest?.requestsAllDataToEndOfResource ?? false) active=\(requestCount())"
        )
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let identifier = ObjectIdentifier(loadingRequest)
        removeRequest(for: identifier)?.task?.cancel()
        DiagnosticsLogger.shared.log("ResourceLoader", "cancelled active=\(requestCount())")
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

        guard let dataRequest = loadingRequest.dataRequest else { return }

        var cursor = max(dataRequest.requestedOffset, dataRequest.currentOffset)
        let requestedEnd: Int64
        if dataRequest.requestsAllDataToEndOfResource {
            requestedEnd = resource.contentLength
        } else {
            requestedEnd = min(resource.contentLength, dataRequest.requestedOffset + Int64(dataRequest.requestedLength))
        }
        guard cursor < requestedEnd else { return }

        await session.noteDemand(range: cursor..<requestedEnd)
        let deliveryChunk = 1 * 1_048_576
        while cursor < requestedEnd {
            try Task.checkCancellation()
            let length = min(deliveryChunk, Int(requestedEnd - cursor))
            let data = try await session.read(offset: cursor, length: length)
            guard !data.isEmpty else { break }
            queue.sync { dataRequest.respond(with: data) }
            cursor += Int64(data.count)
        }
    }

    private func completeRequest(identifier: ObjectIdentifier, token: UUID, error: Error?) {
        queue.async { [weak self] in
            guard let self, let active = self.removeRequest(for: identifier, matching: token) else { return }
            if let error { active.request.finishLoading(with: error) }
            else { active.request.finishLoading() }
        }
    }

    private func requestedRange(for request: AVAssetResourceLoadingRequest) -> Range<Int64>? {
        guard let data = request.dataRequest else { return nil }
        let start = max(data.requestedOffset, data.currentOffset)
        if data.requestsAllDataToEndOfResource { return start..<Int64.max }
        return start..<(start + Int64(data.requestedLength))
    }

    private func isInvalidated() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return invalidated
    }

    @discardableResult
    private func storeRequest(_ request: ActiveRequest, for identifier: ObjectIdentifier) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !invalidated else { return false }
        requests[identifier] = request
        return true
    }

    private func attachTask(_ task: Task<Void, Never>, identifier: ObjectIdentifier, token: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let request = requests[identifier], request.token == token, !invalidated else { return false }
        request.task = task
        return true
    }

    @discardableResult
    private func removeRequest(for identifier: ObjectIdentifier) -> ActiveRequest? {
        lock.lock(); defer { lock.unlock() }
        return requests.removeValue(forKey: identifier)
    }

    @discardableResult
    private func removeRequest(for identifier: ObjectIdentifier, matching token: UUID) -> ActiveRequest? {
        lock.lock(); defer { lock.unlock() }
        guard requests[identifier]?.token == token else { return nil }
        return requests.removeValue(forKey: identifier)
    }

    private func requestCount() -> Int {
        lock.lock(); defer { lock.unlock() }
        return requests.count
    }

    private func invalidateAndTakeRequests() -> [ActiveRequest] {
        lock.lock(); defer { lock.unlock() }
        invalidated = true
        let running = Array(requests.values)
        requests.removeAll()
        return running
    }
}
