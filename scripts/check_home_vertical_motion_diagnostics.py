#!/usr/bin/env python3
from pathlib import Path

observer = Path("Sources/UI/EmbyHomeScrollOffsetObserverV3.swift").read_text(encoding="utf-8")
carousel = Path("Sources/UI/EmbyHomeCarouselStateV3.swift").read_text(encoding="utf-8")
identity = Path("Sources/Core/AppIdentity.swift").read_text(encoding="utf-8")

required_observer = [
    "final class V3HomeVerticalMotionDiagnostics: NSObject",
    "private var displayLink: CADisplayLink?",
    "func observe(_ scrollView: UIScrollView)",
    "func stopObserving(_ scrollView: UIScrollView)",
    "func carouselAutoAdvanceDidStart(fromID: String, toID: String)",
    "func carouselSettleDidStart(itemID: String) -> CFTimeInterval",
    "func carouselSettleDidComplete(itemID: String, startedAt: CFTimeInterval)",
    "let link = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))",
    "guard moving, gap >= 0.018 || layoutShift else { return }",
    'DiagnosticsLogger.shared.log("HomeVerticalHitch"',
    "gap_ms=\\(gapText)",
    "content_delta_h=\\(contentDeltaText)",
    "inset_delta_top=\\(insetDeltaText)",
    "auto_age_ms=\\(autoAgeText)",
    "settle_age_ms=\\(settleAgeText)",
    "settle_duration_ms=\\(settleDurationText)",
    "V3HomeVerticalMotionDiagnostics.shared.observe(scrollView)",
    "V3HomeVerticalMotionDiagnostics.shared.stopObserving",
]
for needle in required_observer:
    if needle not in observer:
        raise SystemExit(f"missing Home vertical diagnostic contract: {needle}")

required_carousel = [
    "guard Date().timeIntervalSince(carouselLastSettledAt) >= 6 else { return }",
    "V3HomeVerticalMotionDiagnostics.shared.carouselAutoAdvanceDidStart(fromID: currentID, toID: targetID)",
    "withAnimation(.easeInOut(duration: 0.62)) { transitionProgress = 1 }",
    "DispatchQueue.main.asyncAfter(deadline: .now() + 0.63)",
    "let diagnosticStartedAt = V3HomeVerticalMotionDiagnostics.shared.carouselSettleDidStart(itemID: itemID)",
    "V3HomeVerticalMotionDiagnostics.shared.carouselSettleDidComplete(itemID: itemID, startedAt: diagnosticStartedAt)",
    'DiagnosticsLogger.shared.log("HomeCarousel", "settled item=\\(itemID)")',
]
for needle in required_carousel:
    if needle not in carousel:
        raise SystemExit(f"missing unchanged carousel/timing contract: {needle}")

for forbidden in ["debounce", "throttle", "watchdog", "retry", "fallback"]:
    if forbidden in observer.lower():
        raise SystemExit(f"diagnostic observer introduced forbidden smoothing behavior: {forbidden}")

if 'static let sourceVersion = "0.14.63"' not in identity:
    raise SystemExit("Build230 source identity must be 0.14.63")

print("home vertical motion diagnostics source contract: PASS")
