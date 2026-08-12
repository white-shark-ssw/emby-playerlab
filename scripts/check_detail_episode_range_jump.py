from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
project = Path("project.yml").read_text()
require("Button { jumpToEpisodeRange(range, proxy: proxy) }" in detail, "episode range buttons must use the deterministic jump helper")
require(".frame(minHeight: 44)" in detail and ".contentShape(Rectangle())" in detail, "episode range buttons need a 44pt minimum tap target")
require("private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy)" in detail, "deterministic range jump helper is missing")
require("DispatchQueue.main.async" in detail, "range jump must run after the current SwiftUI update cycle")
require("transaction.animation = nil" in detail, "range jump must not depend on interruptible scroll animation")
require("proxy.scrollTo(target.id, anchor: .leading)" in detail, "range jump must directly target the requested episode")
require("withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo" not in detail, "old interruptible animated range jump must stay removed")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("detail episode range jump invariants: OK")
