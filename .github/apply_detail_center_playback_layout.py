from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)

metrics_path = Path("Sources/UI/ImmersiveUIComponents.swift")
metrics = metrics_path.read_text()
metrics = replace_once(
    metrics,
    "    static let detailCropResponseFactor: CGFloat = 0.90\n    static func detailBaseHeight(width: CGFloat) -> CGFloat { min(488, max(430, width * 1.08)) }\n    static func detailBackdropViewportHeight(width: CGFloat) -> CGFloat { min(410, max(340, width * 0.88)) }",
    "    static let detailCropResponseFactor: CGFloat = 0.90\n    static let detailPlaybackCenterReserve: CGFloat = 72\n    static func detailBaseHeight(width: CGFloat) -> CGFloat { min(488, max(430, width * 1.08)) }\n    static func detailForegroundBaseHeight(width: CGFloat, viewportHeight: CGFloat) -> CGFloat {\n        let legacyHeight = detailBaseHeight(width: width)\n        let centeredPlaybackHeight = max(0, viewportHeight) * 0.5 + detailPlaybackCenterReserve\n        return min(560, max(legacyHeight, centeredPlaybackHeight))\n    }\n    static func detailBackdropViewportHeight(width: CGFloat) -> CGFloat { min(410, max(340, width * 0.88)) }",
    "add independent foreground height",
)
metrics_path.write_text(metrics)

detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
detail = detail_path.read_text()
detail = replace_once(detail, "                            hero(width: geometry.size.width)", "                            hero(width: geometry.size.width, viewportHeight: viewportHeight)", "pass viewport height to Hero")
detail = replace_once(
    detail,
    "    private func hero(width: CGFloat) -> some View {\n        let baseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width)",
    "    private func hero(width: CGFloat, viewportHeight: CGFloat) -> some View {\n        let backdropBaseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width)\n        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight)",
    "separate backdrop and foreground heights",
)
detail = replace_once(detail, "        let visualHeight = baseHeight + stretch", "        let backdropVisualHeight = backdropBaseHeight + stretch\n        let visualHeight = baseHeight + stretch", "add backdrop visual height")
detail = replace_once(detail, "        let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedImageSize, viewportHeight: visualHeight)", "        let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedImageSize, viewportHeight: backdropVisualHeight)", "keep mask tied to backdrop geometry")
detail = replace_once(detail, "            .frame(width: width, height: visualHeight, alignment: .top)\n            .clipped()", "            .frame(width: width, height: backdropVisualHeight, alignment: .top)\n            .clipped()", "keep clear backdrop frame independent")
detail_path.write_text(detail)

check_path = Path("scripts/check_adaptive_hero_reveal.py")
check = check_path.read_text()
marker = "print(\"PASS: adaptive Hero reveal regression checks\")"
insert = '''\n# Detail foreground placement is independent from the already calibrated clear-backdrop geometry.\nrequire(metrics, "detailPlaybackCenterReserve: CGFloat = 72", "detail playback center reserve missing")\nrequire(metrics, "detailForegroundBaseHeight(width: CGFloat, viewportHeight: CGFloat)", "detail foreground height helper missing")\nrequire(metrics, "viewportHeight) * 0.5 + detailPlaybackCenterReserve", "detail foreground no longer targets the viewport midpoint")\nrequire(detail, "hero(width: geometry.size.width, viewportHeight: viewportHeight)", "detail Hero is not receiving viewport height")\nrequire(detail, "let backdropBaseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width)", "detail backdrop base height is no longer independent")\nrequire(detail, "let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight)", "detail foreground height is not independent")\nrequire(detail, "viewportHeight: backdropVisualHeight", "detail clear-backdrop mask was coupled back to foreground height")\nforbid(picker, "detailForegroundBaseHeight", "Episode Picker must remain frozen and must not use detail foreground positioning")\n\n'''
if marker not in check:
    raise SystemExit("regression marker missing")
check = check.replace(marker, insert + marker, 1)
check_path.write_text(check)
