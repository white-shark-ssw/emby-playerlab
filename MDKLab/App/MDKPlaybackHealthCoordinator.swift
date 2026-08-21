import Foundation
import QuartzCore

/// Sole policy owner for automatic MDK health/fallback decisions.
/// Timers may submit candidates, but only this coordinator decides whether the current generation is unhealthy.
final class MDKPlaybackHealthCoordinator {
    enum PhaseKind: String {
        case idle
        case preparing
        case firstFrame
        case playing
        case nativeSeek
        case seekFrame
    }

    enum Candidate {
        case prepareTimeout(generation: Int)
        case firstFrameTimeout(generation: Int)
        case renderTimeout(generation: Int)
        case nativeSeekTimeout(generation: Int, seekID: Int, hard: Bool)
        case seekFrameTimeout(generation: Int, seekID: Int, hard: Bool)
        case fatal(generation: Int, reason: String)

        var generation: Int {
            switch self {
            case let .prepareTimeout(generation), let .firstFrameTimeout(generation), let .renderTimeout(generation): return generation
            case let .nativeSeekTimeout(generation, _, _), let .seekFrameTimeout(generation, _, _): return generation
            case let .fatal(generation, _): return generation
            }
        }
    }

    enum Verdict {
        case ignore(reason: String)
        case `defer`(reason: String)
        case fail(reason: String)
    }

    private let lock = NSLock()
    private var generation = -1
    private var phase: PhaseKind = .idle
    private var phaseStartedAt: TimeInterval = 0
    private var lastProgressAt: TimeInterval = 0
    private var seekID: Int?
    private var seekTarget: Double?
    private var callbackLanding: Double?
    private var lastRenderSerial: UInt64 = 0
    private var lastRenderedPosition: Double?
    private var lastNativePosition: Double = 0
    private var lastBufferMs: Int64 = 0
    private var lastCacheBytes: Int64 = 0
    private var lastFrontierByte: Int64 = 0

    func reset(generation: Int, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        self.generation = generation
        phase = .idle
        phaseStartedAt = now
        lastProgressAt = now
        seekID = nil
        seekTarget = nil
        callbackLanding = nil
        lastRenderSerial = 0
        lastRenderedPosition = nil
        lastNativePosition = 0
        lastBufferMs = 0
        lastCacheBytes = 0
        lastFrontierByte = 0
        lock.unlock()
    }

    func beginPrepare(generation: Int, now: TimeInterval = CACurrentMediaTime()) { transition(to: .preparing, generation: generation, seekID: nil, target: nil, callbackLanding: nil, now: now) }

    func beginFirstFrame(generation: Int, renderSerial: UInt64, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation else { lock.unlock(); return }
        phase = .firstFrame
        phaseStartedAt = now
        lastProgressAt = now
        seekID = nil
        seekTarget = nil
        callbackLanding = nil
        lastRenderSerial = renderSerial
        lock.unlock()
    }

    func beginNativeSeek(generation: Int, seekID: Int, target: Double, renderSerial: UInt64, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation else { lock.unlock(); return }
        phase = .nativeSeek
        phaseStartedAt = now
        lastProgressAt = now
        self.seekID = seekID
        seekTarget = target
        callbackLanding = nil
        lastRenderSerial = renderSerial
        lock.unlock()
    }

    func beginSeekFrame(generation: Int, seekID: Int, target: Double, callbackLanding: Double, renderSerial: UInt64, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation else { lock.unlock(); return }
        phase = .seekFrame
        phaseStartedAt = now
        lastProgressAt = now
        self.seekID = seekID
        seekTarget = target
        self.callbackLanding = callbackLanding
        lastRenderSerial = renderSerial
        lock.unlock()
    }

    func finishNativeSeek(generation: Int, seekID: Int, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation, self.seekID == seekID, phase == .nativeSeek else { lock.unlock(); return }
        phase = .playing
        phaseStartedAt = now
        lastProgressAt = now
        self.seekID = nil
        seekTarget = nil
        callbackLanding = nil
        lock.unlock()
    }

    func completeSeek(generation: Int, seekID: Int, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation, self.seekID == seekID, phase == .seekFrame else { lock.unlock(); return }
        phase = .playing
        phaseStartedAt = now
        lastProgressAt = now
        self.seekID = nil
        seekTarget = nil
        callbackLanding = nil
        lock.unlock()
    }

    func noteRenderedFrame(generation: Int, serial: UInt64, position: Double, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation else { lock.unlock(); return }
        let advanced = serial > lastRenderSerial || lastRenderedPosition.map { abs($0 - position) > 0.000_001 } ?? true
        lastRenderSerial = max(lastRenderSerial, serial)
        lastRenderedPosition = position
        guard advanced else { lock.unlock(); return }
        switch phase {
        case .firstFrame:
            phase = .playing
            phaseStartedAt = now
            lastProgressAt = now
        case .playing:
            lastProgressAt = now
        case .nativeSeek:
            if let target = seekTarget, abs(position - target) <= 12 { lastProgressAt = now }
        case .seekFrame:
            if let landing = callbackLanding, abs(position - landing) <= 1 { lastProgressAt = now }
        case .idle, .preparing:
            break
        }
        lock.unlock()
    }

    func noteNativeSample(generation: Int, position: Double, bufferMs: Int64, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation else { lock.unlock(); return }
        let positionAdvanced = abs(position - lastNativePosition) >= 0.05
        let bufferAdvanced = bufferMs >= lastBufferMs + 64
        lastNativePosition = position
        lastBufferMs = bufferMs
        switch phase {
        case .firstFrame:
            if positionAdvanced || bufferAdvanced { lastProgressAt = now }
        case .nativeSeek:
            if let target = seekTarget, positionAdvanced, abs(position - target) <= 12 { lastProgressAt = now }
        case .seekFrame:
            if bufferAdvanced { lastProgressAt = now }
        case .idle, .preparing, .playing:
            break
        }
        lock.unlock()
    }

    func noteTransport(generation: Int, cacheBytes: Int64, frontierByte: Int64, activeRequests: Int, networkBps: Double, rangeFailures: Int, now: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        guard self.generation == generation else { lock.unlock(); return }
        let cacheAdvanced = cacheBytes > lastCacheBytes
        let frontierAdvanced = frontierByte != lastFrontierByte && frontierByte > 0
        let networkActive = rangeFailures == 0 && networkBps >= 65_536
        lastCacheBytes = max(lastCacheBytes, cacheBytes)
        if frontierByte > 0 { lastFrontierByte = frontierByte }
        if cacheAdvanced || frontierAdvanced || networkActive {
            switch phase {
            case .preparing, .firstFrame, .nativeSeek, .seekFrame: lastProgressAt = now
            case .idle, .playing: break
            }
        } else if activeRequests > 0, rangeFailures == 0 {
            // An open request alone is not progress. Keep the old timestamp so a stalled socket can time out.
        }
        lock.unlock()
    }

    func evaluate(_ candidate: Candidate, now: TimeInterval = CACurrentMediaTime(), shouldPlay: Bool, buffering: Bool) -> Verdict {
        lock.lock()
        defer { lock.unlock() }
        guard candidate.generation == generation else { return .ignore(reason: "generation-changed") }
        if case let .fatal(_, reason) = candidate { return .fail(reason: reason) }

        let wall = max(0, now - phaseStartedAt)
        let idle = max(0, now - lastProgressAt)
        switch candidate {
        case .prepareTimeout:
            guard phase == .preparing else { return .ignore(reason: "phase=\(phase.rawValue)") }
            if wall >= 30 { return .fail(reason: "prepare-absolute-limit") }
            if wall < 6 { return .defer(reason: "prepare-minimum-window") }
            if idle < 4 { return .defer(reason: "prepare-progress-recent") }
            return .fail(reason: "prepare-no-progress")
        case .firstFrameTimeout:
            guard phase == .firstFrame else { return .ignore(reason: "phase=\(phase.rawValue)") }
            guard shouldPlay else { return .ignore(reason: "playback-not-requested") }
            if wall >= 20 { return .fail(reason: "first-frame-absolute-limit") }
            if wall < 5 { return .defer(reason: "first-frame-minimum-window") }
            if idle < 3 || buffering { return .defer(reason: buffering ? "first-frame-buffering" : "first-frame-progress-recent") }
            return .fail(reason: "first-frame-no-progress")
        case .renderTimeout:
            guard phase == .playing else { return .ignore(reason: "phase=\(phase.rawValue)") }
            guard shouldPlay, !buffering else { return .ignore(reason: buffering ? "buffering" : "playback-not-requested") }
            if idle < 3 { return .defer(reason: "render-progress-recent") }
            return .fail(reason: "render-no-progress")
        case let .nativeSeekTimeout(_, candidateSeekID, hard):
            guard phase == .nativeSeek, seekID == candidateSeekID else { return .ignore(reason: "phase=\(phase.rawValue)-seek=\(seekID ?? -1)") }
            if !hard { return .defer(reason: "native-seek-soft-probe") }
            if wall >= 12 { return .fail(reason: "native-seek-absolute-limit") }
            if wall < 5 { return .defer(reason: "native-seek-minimum-window") }
            if idle < 2.5 { return .defer(reason: "native-seek-progress-recent") }
            return .fail(reason: "native-seek-no-progress")
        case let .seekFrameTimeout(_, candidateSeekID, hard):
            guard phase == .seekFrame, seekID == candidateSeekID else { return .ignore(reason: "phase=\(phase.rawValue)-seek=\(seekID ?? -1)") }
            guard shouldPlay else { return .ignore(reason: "playback-not-requested") }
            if !hard { return .defer(reason: "seek-frame-soft-probe") }
            if wall >= 10 { return .fail(reason: "seek-frame-absolute-limit") }
            if wall < 4 { return .defer(reason: "seek-frame-minimum-window") }
            if idle < 2.5 || buffering { return .defer(reason: buffering ? "seek-frame-buffering" : "seek-frame-progress-recent") }
            return .fail(reason: "seek-frame-no-progress")
        case .fatal:
            return .fail(reason: "fatal")
        }
    }

    func debugState(now: TimeInterval = CACurrentMediaTime()) -> String {
        lock.lock()
        defer { lock.unlock() }
        return "phase=\(phase.rawValue) generation=\(generation) seek=\(seekID.map(String.init) ?? "none") wallMs=\(Int(max(0, now - phaseStartedAt) * 1_000)) idleMs=\(Int(max(0, now - lastProgressAt) * 1_000)) target=\(seekTarget.map { String(format: "%.3f", $0) } ?? "none") rendered=\(lastRenderedPosition.map { String(format: "%.3f", $0) } ?? "none")"
    }

    private func transition(to phase: PhaseKind, generation: Int, seekID: Int?, target: Double?, callbackLanding: Double?, now: TimeInterval) {
        lock.lock()
        self.generation = generation
        self.phase = phase
        phaseStartedAt = now
        lastProgressAt = now
        self.seekID = seekID
        seekTarget = target
        self.callbackLanding = callbackLanding
        lock.unlock()
    }
}
