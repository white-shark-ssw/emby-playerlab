from pathlib import Path

identity = Path("Sources/Core/AppIdentity.swift")
text = identity.read_text()
text = text.replace('static let sourceVersion = "0.14.59"', 'static let sourceVersion = "0.14.61"', 1)
text = text.replace('?? "0.14.59"', '?? "0.14.61"', 1)
identity.write_text(text)

interaction = Path("Sources/UI/EmbyHomeCarouselInteractionV3.swift")
text = interaction.read_text()
text = text.replace('''            if axis == .horizontal, state == .began || state == .changed {\n                V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled-new-touch")\n                onHorizontalCancelled?()\n                state = .cancelled\n''', '''            if axis == .horizontal, state == .began || state == .changed {\n                onHorizontalCancelled?()\n                state = .cancelled\n''', 1)
text = text.replace('''        if axis == .horizontal, state == .began || state == .changed {\n            V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)\n            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended")\n            onHorizontalEnded?(translation, latestPredictedTranslation)\n''', '''        if axis == .horizontal, state == .began || state == .changed {\n            V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)\n            onHorizontalEnded?(translation, latestPredictedTranslation)\n''', 1)
text = text.replace('''        if axis == .horizontal, state == .began || state == .changed {\n            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled")\n            onHorizontalCancelled?()\n''', '''        if axis == .horizontal, state == .began || state == .changed {\n            onHorizontalCancelled?()\n''', 1)
text = text.replace('''        if !isCarouselDragging {\n            guard shouldCommit, let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: releaseDirection) else { return }\n''', '''        if !isCarouselDragging {\n            guard shouldCommit, let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: releaseDirection) else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended-no-transition"); return }\n''', 1)
text = text.replace('''        guard let targetID = transitionToID else { return }\n        isCarouselDragging = false\n''', '''        guard let targetID = transitionToID else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended-no-target"); return }\n        isCarouselDragging = false\n''', 1)
text = text.replace('''    func cancelNativeCarouselDrag() {\n        guard isCarouselDragging else { return }\n        isCarouselDragging = false\n        cancelInteractiveTransition()\n    }\n''', '''    func cancelNativeCarouselDrag() {\n        guard isCarouselDragging else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled-no-transition"); return }\n        isCarouselDragging = false\n        cancelInteractiveTransition()\n    }\n''', 1)
interaction.write_text(text)

state = Path("Sources/UI/EmbyHomeCarouselStateV3.swift")
text = state.read_text()
text = text.replace('''            transitionDirection = 1\n            carouselLastSettledAt = Date()\n        }\n    }\n\n    func autoAdvanceCarouselIfNeeded()''', '''            transitionDirection = 1\n            carouselLastSettledAt = Date()\n            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled-settled")\n        }\n    }\n\n    func autoAdvanceCarouselIfNeeded()''', 1)
text = text.replace('''        carouselLastSettledAt = Date()\n        DiagnosticsLogger.shared.log("HomeCarousel", "settled item=\\(itemID)")\n    }\n''', '''        carouselLastSettledAt = Date()\n        DiagnosticsLogger.shared.log("HomeCarousel", "settled item=\\(itemID)")\n        V3HomeCarouselCadenceDiagnostics.shared.end(reason: "settled")\n    }\n''', 1)
state.write_text(text)

checks = {
    identity: ['sourceVersion = "0.14.61"', '?? "0.14.61"'],
    interaction: ['onHorizontalEnded?(translation, latestPredictedTranslation)', 'ended-no-transition', 'ended-no-target', 'cancelled-no-transition'],
    state: ['end(reason: "cancelled-settled")', 'end(reason: "settled")'],
}
for path, needles in checks.items():
    body = path.read_text()
    for needle in needles:
        if needle not in body: raise SystemExit(f"Build228 patch missing {needle} in {path}")

if 'V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended")' in interaction.read_text():
    raise SystemExit("Build228 still ends max-refresh at touchesEnded")
