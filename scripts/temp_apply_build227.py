from pathlib import Path

state = Path("Sources/UI/EmbyHomeCarouselStateV3.swift")
text = state.read_text()
old = '''    func carouselForegroundOffset(for itemID: String, width: CGFloat) -> CGFloat {
        guard let fromID = transitionFromID, let toID = transitionToID else { return 0 }
        let direction = CGFloat(transitionDirection)
        let visualProgress = min(1, max(0, transitionProgress))
        let pageStep = width
        if itemID == fromID { return -direction * visualProgress * pageStep }
        if itemID == toID { return direction * (1 - visualProgress) * pageStep }
        return 0
    }
'''
new = '''    func carouselForegroundOffset(for itemID: String, width: CGFloat) -> CGFloat {
        guard let fromID = transitionFromID, let toID = transitionToID else { return 0 }
        let direction = CGFloat(transitionDirection)
        let visualProgress = min(1, max(0, transitionProgress))
        let pageStep = width
        let rawOffset: CGFloat
        if itemID == fromID { rawOffset = -direction * visualProgress * pageStep }
        else if itemID == toID { rawOffset = direction * (1 - visualProgress) * pageStep }
        else { return 0 }
        let displayScale = max(1, UIScreen.main.scale)
        return (rawOffset * displayScale).rounded() / displayScale
    }
'''
if new in text:
    raise SystemExit(0)
if old not in text:
    raise SystemExit("Build227 foreground-offset baseline not found")
state.write_text(text.replace(old, new, 1))
