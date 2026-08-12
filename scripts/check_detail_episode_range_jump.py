from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
project = Path("project.yml").read_text()
require(".highPriorityGesture(TapGesture().onEnded { jumpToEpisodeRange(range, proxy: proxy) })" in detail, "episode range taps must have priority over the parent horizontal ScrollView")
require(".frame(minHeight: 44)" in detail and ".contentShape(Rectangle())" in detail, "episode range controls need a 44pt minimum tap target")
require(".accessibilityAddTraits(.isButton)" in detail and ".accessibilityAction { jumpToEpisodeRange(range, proxy: proxy) }" in detail, "episode range controls must preserve button accessibility")
require("private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy)" in detail, "range jump helper is missing")
require("DispatchQueue.main.async" in detail, "range jump must run after the current SwiftUI update cycle")
require("withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo(target.id, anchor: .leading) }" in detail, "range jump must restore real horizontal animated movement")
require("transaction.animation = nil" not in detail, "non-animated range jump must stay removed")
require('DiagnosticsLogger.shared.log("EpisodeRangeJump", "tap' in detail, "range tap diagnostics are missing")
require('DiagnosticsLogger.shared.log("EpisodeRangeJump", "scroll' in detail, "range scroll diagnostics are missing")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("detail episode range jump invariants: OK")
