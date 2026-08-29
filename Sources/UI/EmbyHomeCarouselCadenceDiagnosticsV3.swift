import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class V3HomeCarouselCadenceDiagnostics: NSObject {
    static let shared = V3HomeCarouselCadenceDiagnostics()

    private struct IntervalStats {
        var sampleCount = 0
        var intervalCount = 0
        var totalGapMS: Double = 0
        var maxGapMS: Double = 0
        var over12_5MS = 0
        var over20MS = 0
        var over30MS = 0
        var lastTimestamp: CFTimeInterval?

        mutating func record(_ timestamp: CFTimeInterval) {
            sampleCount += 1
            if let lastTimestamp {
                let gapMS = max(0, (timestamp - lastTimestamp) * 1000)
                intervalCount += 1
                totalGapMS += gapMS
                maxGapMS = max(maxGapMS, gapMS)
                if gapMS >= 12.5 { over12_5MS += 1 }
                if gapMS >= 20 { over20MS += 1 }
                if gapMS >= 30 { over30MS += 1 }
            }
            lastTimestamp = timestamp
        }

        var averageGapMS: Double { intervalCount > 0 ? totalGapMS / Double(intervalCount) : 0 }
    }

    private struct ImageEvent {
        let role: String
        let itemID: String
        let timestamp: CFTimeInterval
    }

    private struct DisplayGapEvent {
        let gapMS: Double
        let imageRole: String
        let imageItemID: String
        let imageAgeMS: Double
    }

    private var displayLink: CADisplayLink?
    private var active = false
    private var dragStartedAt: CFTimeInterval = 0
    private var acquisitionTranslation: CGFloat = 0
    private var touchDownToAcquisitionMS: Double = 0
    private var acquisitionTouchTimestamp: TimeInterval = 0
    private var acquisitionCoalescedCount = 0
    private var acquisitionPredecessorStatus = "unknown"
    private var acquisitionPredecessorDelta: CGFloat?
    private var acquisitionPredecessorAgeMS: Double?
    private var postAcquisitionCoalescedCount = 0
    private var postAcquisitionPredecessorStatus = "not-needed"
    private var postAcquisitionPredecessorDelta: CGFloat?
    private var postAcquisitionPredecessorAgeMS: Double?
    private var firstRenderTranslation: CGFloat?
    private var firstRenderTotalTranslation: CGFloat?
    private var acquisitionToFirstRenderMS: Double?
    private var maximumFPS = 60
    private var requestedFPS = 0
    private var deliveredTouchStats = IntervalStats()
    private var coalescedTouchStats = IntervalStats()
    private var progressPublishStats = IntervalStats()
    private var renderUpdateStats = IntervalStats()
    private var displayStats = IntervalStats()
    private var displayGapSamples: [Double] = []
    private var worstDisplayGaps: [DisplayGapEvent] = []
    private var lastCoalescedTouchTimestamp: TimeInterval?
    private var progressPublishCalls = 0
    private var lastPublishedProgress: CGFloat?
    private var lastRenderProgress: CGFloat?
    private var lastProgressPublishAt: CFTimeInterval?
    private var maxPublishToRenderLagMS: Double = 0
    private var latestImageEvent: ImageEvent?
    private var imageEventsDuringDrag = 0
    private var imageRoleCounts: [String: Int] = [:]

    private override init() {}

    func begin(acquisitionTranslation: CGFloat, touchDownTimestamp: TimeInterval, acquisitionCoalescedCount: Int, acquisitionPredecessorStatus: String, acquisitionPredecessorDelta: CGFloat?, acquisitionPredecessorAgeMS: Double?, touch: UITouch, event: UIEvent) {
        precondition(Thread.isMainThread)
        if active { end(reason: "restarted") }
        active = true
        dragStartedAt = CACurrentMediaTime()
        self.acquisitionTranslation = acquisitionTranslation
        acquisitionTouchTimestamp = touch.timestamp
        self.acquisitionCoalescedCount = acquisitionCoalescedCount
        self.acquisitionPredecessorStatus = acquisitionPredecessorStatus
        self.acquisitionPredecessorDelta = acquisitionPredecessorDelta
        self.acquisitionPredecessorAgeMS = acquisitionPredecessorAgeMS
        postAcquisitionCoalescedCount = 0
        postAcquisitionPredecessorStatus = "not-needed"
        postAcquisitionPredecessorDelta = nil
        postAcquisitionPredecessorAgeMS = nil
        touchDownToAcquisitionMS = max(0, (touch.timestamp - touchDownTimestamp) * 1000)
        firstRenderTranslation = nil
        firstRenderTotalTranslation = nil
        acquisitionToFirstRenderMS = nil
        maximumFPS = max(60, UIScreen.main.maximumFramesPerSecond)
        requestedFPS = maximumFPS > 60 ? maximumFPS : 0
        deliveredTouchStats = IntervalStats()
        coalescedTouchStats = IntervalStats()
        progressPublishStats = IntervalStats()
        renderUpdateStats = IntervalStats()
        displayStats = IntervalStats()
        displayGapSamples.removeAll(keepingCapacity: true)
        worstDisplayGaps.removeAll(keepingCapacity: true)
        lastCoalescedTouchTimestamp = nil
        progressPublishCalls = 0
        lastPublishedProgress = nil
        lastRenderProgress = nil
        lastProgressPublishAt = nil
        maxPublishToRenderLagMS = 0
        imageEventsDuringDrag = 0
        imageRoleCounts.removeAll(keepingCapacity: true)
        deliveredTouchStats.record(touch.timestamp)
        recordCoalescedTouches(for: touch, event: event)
        let link = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))
        if requestedFPS > 0 {
            let requested = Float(requestedFPS)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: requested, maximum: requested, preferred: requested)
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func recordTouch(_ touch: UITouch, event: UIEvent) {
        precondition(Thread.isMainThread)
        guard active else { return }
        deliveredTouchStats.record(touch.timestamp)
        recordCoalescedTouches(for: touch, event: event)
    }

    func recordPostAcquisitionSample(count: Int, status: String, delta: CGFloat?, ageMS: Double?) {
        precondition(Thread.isMainThread)
        guard active else { return }
        postAcquisitionCoalescedCount = count
        postAcquisitionPredecessorStatus = status
        postAcquisitionPredecessorDelta = delta
        postAcquisitionPredecessorAgeMS = ageMS
    }

    func recordFirstRender(translation: CGFloat, totalTranslation: CGFloat, touchTimestamp: TimeInterval) {
        precondition(Thread.isMainThread)
        guard active, firstRenderTranslation == nil else { return }
        firstRenderTranslation = translation
        firstRenderTotalTranslation = totalTranslation
        acquisitionToFirstRenderMS = max(0, (touchTimestamp - acquisitionTouchTimestamp) * 1000)
    }

    func recordProgressPublish(_ progress: CGFloat) {
        precondition(Thread.isMainThread)
        guard active else { return }
        progressPublishCalls += 1
        let now = CACurrentMediaTime()
        lastProgressPublishAt = now
        if let lastPublishedProgress, abs(progress - lastPublishedProgress) <= 0.000001 { return }
        lastPublishedProgress = progress
        progressPublishStats.record(now)
    }

    func recordSwiftUIUpdate(progress: CGFloat) {
        precondition(Thread.isMainThread)
        guard active else { return }
        if let lastRenderProgress, abs(progress - lastRenderProgress) <= 0.000001 { return }
        lastRenderProgress = progress
        let now = CACurrentMediaTime()
        renderUpdateStats.record(now)
        if let lastProgressPublishAt { maxPublishToRenderLagMS = max(maxPublishToRenderLagMS, max(0, (now - lastProgressPublishAt) * 1000)) }
    }

    func recordImageCallback(role: String, itemID: String) {
        precondition(Thread.isMainThread)
        let event = ImageEvent(role: role, itemID: itemID, timestamp: CACurrentMediaTime())
        latestImageEvent = event
        guard active else { return }
        imageEventsDuringDrag += 1
        imageRoleCounts[role, default: 0] += 1
    }

    func end(reason: String) {
        precondition(Thread.isMainThread)
        guard active else { return }
        active = false
        displayLink?.invalidate()
        displayLink = nil
        let now = CACurrentMediaTime()
        let durationMS = max(0, (now - dragStartedAt) * 1000)
        let p95DisplayGap = percentile95(displayGapSamples)
        let roles = imageRoleCounts.keys.sorted().map { "\($0):\(imageRoleCounts[$0] ?? 0)" }.joined(separator: ",")
        let worst = worstDisplayGaps.map { event in
            let age = event.imageAgeMS >= 0 ? String(format: "%.1f", event.imageAgeMS) : "none"
            return "\(String(format: "%.1f", event.gapMS))@\(event.imageRole):\(event.imageItemID):\(age)"
        }.joined(separator: ",")
        let firstRenderX = firstRenderTranslation.map { String(format: "%.2f", $0) } ?? "none"
        let firstTotalX = firstRenderTotalTranslation.map { String(format: "%.2f", $0) } ?? "none"
        let firstDelayMS = acquisitionToFirstRenderMS.map { String(format: "%.2f", $0) } ?? "none"
        let predecessorDeltaX = acquisitionPredecessorDelta.map { String(format: "%.2f", $0) } ?? "none"
        let predecessorAgeMS = acquisitionPredecessorAgeMS.map { String(format: "%.2f", $0) } ?? "none"
        let postPredecessorDeltaX = postAcquisitionPredecessorDelta.map { String(format: "%.2f", $0) } ?? "none"
        let postPredecessorAgeMS = postAcquisitionPredecessorAgeMS.map { String(format: "%.2f", $0) } ?? "none"
        DiagnosticsLogger.shared.app(
            "HomeCarouselCadence",
            "reason=\(reason) duration_ms=\(String(format: "%.1f", durationMS)) maximum_fps=\(maximumFPS) requested_fps=\(requestedFPS) touch_down_to_acquire_ms=\(String(format: "%.2f", touchDownToAcquisitionMS)) acquisition_x=\(String(format: "%.2f", acquisitionTranslation)) acq_coalesced_count=\(acquisitionCoalescedCount) acq_predecessor_status=\(acquisitionPredecessorStatus) acq_predecessor_delta_x=\(predecessorDeltaX) acq_predecessor_age_ms=\(predecessorAgeMS) post_acq_coalesced_count=\(postAcquisitionCoalescedCount) post_acq_predecessor_status=\(postAcquisitionPredecessorStatus) post_acq_predecessor_delta_x=\(postPredecessorDeltaX) post_acq_predecessor_age_ms=\(postPredecessorAgeMS) acquire_to_first_render_ms=\(firstDelayMS) first_render_x=\(firstRenderX) first_total_x=\(firstTotalX) delivered_samples=\(deliveredTouchStats.sampleCount) delivered_avg_gap_ms=\(String(format: "%.2f", deliveredTouchStats.averageGapMS)) delivered_max_gap_ms=\(String(format: "%.2f", deliveredTouchStats.maxGapMS)) delivered_ge12_5=\(deliveredTouchStats.over12_5MS) delivered_ge20=\(deliveredTouchStats.over20MS) delivered_ge30=\(deliveredTouchStats.over30MS) coalesced_samples=\(coalescedTouchStats.sampleCount) coalesced_avg_gap_ms=\(String(format: "%.2f", coalescedTouchStats.averageGapMS)) coalesced_max_gap_ms=\(String(format: "%.2f", coalescedTouchStats.maxGapMS)) publish_calls=\(progressPublishCalls) publish_changes=\(progressPublishStats.sampleCount) publish_avg_gap_ms=\(String(format: "%.2f", progressPublishStats.averageGapMS)) publish_max_gap_ms=\(String(format: "%.2f", progressPublishStats.maxGapMS)) render_changes=\(renderUpdateStats.sampleCount) render_avg_gap_ms=\(String(format: "%.2f", renderUpdateStats.averageGapMS)) render_max_gap_ms=\(String(format: "%.2f", renderUpdateStats.maxGapMS)) publish_to_render_max_ms=\(String(format: "%.2f", maxPublishToRenderLagMS)) display_intervals=\(displayStats.intervalCount) display_avg_gap_ms=\(String(format: "%.2f", displayStats.averageGapMS)) display_p95_gap_ms=\(String(format: "%.2f", p95DisplayGap)) display_max_gap_ms=\(String(format: "%.2f", displayStats.maxGapMS)) display_ge12_5=\(displayStats.over12_5MS) display_ge20=\(displayStats.over20MS) display_ge30=\(displayStats.over30MS) image_events=\(imageEventsDuringDrag) image_roles=\(roles.isEmpty ? "none" : roles) worst_display=\(worst.isEmpty ? "none" : worst)"
        )
    }

    private func recordCoalescedTouches(for touch: UITouch, event: UIEvent) {
        let samples = (event.coalescedTouches(for: touch) ?? [touch]).sorted { $0.timestamp < $1.timestamp }
        for sample in samples {
            if let lastCoalescedTouchTimestamp, sample.timestamp <= lastCoalescedTouchTimestamp + 0.000001 { continue }
            coalescedTouchStats.record(sample.timestamp)
            lastCoalescedTouchTimestamp = sample.timestamp
        }
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        guard active else { return }
        let previousTimestamp = displayStats.lastTimestamp
        displayStats.record(link.timestamp)
        guard let previousTimestamp else { return }
        let gapMS = max(0, (link.timestamp - previousTimestamp) * 1000)
        displayGapSamples.append(gapMS)
        let imageAgeMS: Double
        let imageRole: String
        let imageItemID: String
        if let latestImageEvent {
            imageAgeMS = max(0, (link.timestamp - latestImageEvent.timestamp) * 1000)
            imageRole = latestImageEvent.role
            imageItemID = latestImageEvent.itemID
        } else {
            imageAgeMS = -1
            imageRole = "none"
            imageItemID = "none"
        }
        worstDisplayGaps.append(DisplayGapEvent(gapMS: gapMS, imageRole: imageRole, imageItemID: imageItemID, imageAgeMS: imageAgeMS))
        worstDisplayGaps.sort { $0.gapMS > $1.gapMS }
        if worstDisplayGaps.count > 5 { worstDisplayGaps.removeLast(worstDisplayGaps.count - 5) }
    }

    private func percentile95(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)
        return sorted[max(0, index)]
    }
}

struct V3HomeCarouselCadenceRenderProbe: UIViewRepresentable {
    let progress: CGFloat

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        V3HomeCarouselCadenceDiagnostics.shared.recordSwiftUIUpdate(progress: progress)
    }
}
