from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


root = Path("Sources/UI/EmbyServerRootViewV3.swift")
text = root.read_text()
marker = ".environment(\\.serverDockContent, AnyView(serverTabBar))"
if marker not in text:
    old = """                    }
                    .frame(width: geometry.size.width, height: fullHeight, alignment: .top)
                    .ignoresSafeArea(.container, edges: .bottom)
"""
    new = """                    }
                    .environment(\\.serverDockContent, AnyView(serverTabBar))
                    .frame(width: geometry.size.width, height: fullHeight, alignment: .top)
                    .ignoresSafeArea(.container, edges: .bottom)
"""
    text = replace_once(text, old, new, "server dock environment injection")
    root.write_text(text)


detail = Path("Sources/UI/EmbyMediaDetailView.swift")
text = detail.read_text()
if "let fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom" in text:
    text = replace_once(text, "            let fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom\n", "", "detail fullHeight declaration")
    count = text.count(".frame(width: geometry.size.width, height: fullHeight)")
    if count != 2:
        raise SystemExit(f"detail fullHeight frames: expected 2 matches, got {count}")
    text = text.replace(".frame(width: geometry.size.width, height: fullHeight)", ".frame(width: geometry.size.width, height: geometry.size.height)")
if ".hidesServerDockWhileVisible()" in text:
    text = replace_once(
        text,
        "        .hidesServerDockWhileVisible()\n",
        "        .detailPagePresentation()\n        .onAppear { DiagnosticsLogger.shared.log(\"NavigationRace\", \"event=detail-appear item=\\(model.item.id)\") }\n        .onDisappear { DiagnosticsLogger.shared.log(\"NavigationRace\", \"event=detail-disappear item=\\(model.item.id)\") }\n",
        "detail presentation modifier",
    )
detail.write_text(text)

for staged_path in [
    Path(".github/workflows/one-shot-detail-immersive-patch.yml"),
    Path("scripts/apply_detail_immersive_feature.py"),
]:
    if staged_path.exists():
        staged_path.unlink()

print("Applied detail immersive feature patch.")
