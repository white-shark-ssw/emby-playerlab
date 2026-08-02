import Foundation
import KSPlayer

final class KSPlayerSparseAVIOContext: AbstractAVIOContext {
    private let coordinator: SparseAVIOReadCoordinator
    private let ffmpegEOF = -541_478_725

    init(coordinator: SparseAVIOReadCoordinator, bufferSize: Int32 = 262_144) {
        self.coordinator = coordinator
        super.init(bufferSize: bufferSize)
    }

    override func read(buffer: UnsafeMutablePointer<UInt8>?, size: Int32) -> Int {
        guard let buffer, size > 0 else { return -5 }
        switch coordinator.read(maxLength: Int(size)) {
        case .success(let data):
            guard !data.isEmpty else { return ffmpegEOF }
            data.copyBytes(to: buffer, count: data.count)
            return data.count
        case .failure(let error):
            DiagnosticsLogger.shared.log("KSAVIO", "read failed: \(error.localizedDescription)")
            return -5
        }
    }

    override func write(buffer: UnsafeMutablePointer<UInt8>?, size: Int32) -> Int { -5 }
    override func seek(offset: Int64, whence: Int32) -> Int64 { coordinator.seek(offset: offset, whence: whence) }
    override func fileSize() -> Int64 { coordinator.fileSize }
    override func close() { coordinator.close() }
}
