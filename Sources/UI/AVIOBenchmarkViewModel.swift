import Combine
import Foundation

@MainActor
final class AVIOBenchmarkViewModel: ObservableObject {
    @Published private(set) var resolvedResource: TransportResolvedResource?
    @Published private(set) var isResolving = false
    @Published private(set) var isRunning = false
    @Published private(set) var progress: AVIOBenchmarkProgress?
    @Published private(set) var results: [AVIOBenchmarkResult] = []
    @Published private(set) var probeReport: AVIOProbeReport?
    @Published var errorMessage: String?
    @Published var durationSeconds = 30
    @Published var targetMB = 256
    @Published var requestProfileRaw = AVIORequestProfile.capturedRedirect.rawValue

    private let resolver = RedirectResolver()
    private let runner = AVIOBenchmarkRunner()
    private var currentTask: Task<Void, Never>?

    var requestProfile: AVIORequestProfile {
        AVIORequestProfile(rawValue: requestProfileRaw) ?? .capturedRedirect
    }

    func prepare(source: ResolvedPlaybackSource) {
        guard !isResolving, resolvedResource == nil else { return }
        isResolving = true
        errorMessage = nil
        currentTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isResolving = false }
            do {
                self.resolvedResource = try await self.resolver.resolve(source: source)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func start(mode: AVIOBenchmarkMode) {
        guard let resource = resolvedResource, !isRunning else { return }
        currentTask?.cancel()
        isRunning = true
        progress = nil
        errorMessage = nil

        let configuration = AVIOBenchmarkConfiguration(
            mode: mode,
            requestProfile: requestProfile,
            durationSeconds: durationSeconds,
            targetBytes: Int64(targetMB) * 1_048_576
        )
        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isRunning = false
                self.progress = nil
            }
            do {
                let result = try await self.runner.run(resource: resource, configuration: configuration) { [weak self] value in
                    self?.progress = value
                }
                self.results.insert(result, at: 0)
            } catch is CancellationError {
                DiagnosticsLogger.shared.log("AVIOLab", "benchmark cancelled mode=\(mode.rawValue)")
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func startAll() {
        guard let resource = resolvedResource, !isRunning else { return }
        currentTask?.cancel()
        isRunning = true
        progress = nil
        errorMessage = nil

        let profile = requestProfile
        let duration = durationSeconds
        let targetBytes = Int64(targetMB) * 1_048_576
        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isRunning = false
                self.progress = nil
            }

            do {
                for mode in AVIOBenchmarkMode.allCases {
                    try Task.checkCancellation()
                    let configuration = AVIOBenchmarkConfiguration(
                        mode: mode,
                        requestProfile: profile,
                        durationSeconds: duration,
                        targetBytes: targetBytes
                    )
                    let result = try await self.runner.run(resource: resource, configuration: configuration) { [weak self] value in
                        self?.progress = value
                    }
                    self.results.insert(result, at: 0)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch is CancellationError {
                DiagnosticsLogger.shared.log("AVIOLab", "benchmark suite cancelled")
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func runProbe() {
        guard let resource = resolvedResource, !isRunning else { return }
        currentTask?.cancel()
        isRunning = true
        progress = nil
        errorMessage = nil

        let profile = requestProfile
        currentTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isRunning = false }
            do {
                let context = AVIOProbeContext(resource: resource, requestProfile: profile)
                _ = try await context.read(maxLength: 256 * 1024)
                _ = try await context.read(maxLength: 256 * 1024)
                _ = try await context.seek(offset: resource.contentLength / 2, whence: .start)
                _ = try await context.read(maxLength: 256 * 1024)
                _ = try await context.seek(offset: 1_048_576, whence: .start)
                _ = try await context.read(maxLength: 256 * 1024)
                self.probeReport = await context.report()
            } catch is CancellationError {
                DiagnosticsLogger.shared.log("AVIOLab", "AVIO probe cancelled")
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        progress = nil
    }

    func export() throws -> URL {
        let export = AVIOBenchmarkExport(
            generatedAt: Date(),
            appVersion: AppIdentity.version,
            sourceVersion: AppIdentity.sourceVersion,
            deploymentTarget: "iOS 15.0",
            results: results,
            probe: probeReport
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("EmbyPlayerLab-115AVIO-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
