from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    s = p.read_text()
    if new in s:
        return
    if old not in s:
        raise SystemExit(f"missing expected text in {path}: {old[:120]!r}")
    p.write_text(s.replace(old, new, 1))


# MODULE_STATUS
replace_once(
    "docs/project/MODULE_STATUS.md",
    "| Home carousel interaction | **Active Build190 release-owner candidate; Build189 real-device rejected** | Build187 proved SwiftUI initial horizontal samples arrive already at 4–16pt. Build189 native raw/coalesced movement exposed a release regression: lifting the finger could freeze the carousel at intermediate progress because native recognition competed with the SwiftUI-only settle owner. Build190 keeps native movement sampling passive and leaves only SwiftUI `onEnded` as commit/cancel owner; dedicated Release CI passed and IPA was produced. Real-device validation is pending. |",
    "| Home carousel interaction | **Active Build193 release-owner candidate; Build189 real-device rejected** | Build187 proved SwiftUI initial horizontal samples arrive already at 4–16pt. Build189 native raw/coalesced movement exposed a release regression: lifting the finger could freeze the carousel at intermediate progress because native recognition competed with the SwiftUI-only settle owner. Build193 keeps native movement sampling passive and leaves only SwiftUI `onEnded` as commit/cancel owner; dedicated Release CI passed and IPA was produced. Carousel Build190/191 identities were retired because parallel detail work owns those builds, and Build192 belongs to Add/Edit Emby. Real-device validation is pending. |",
)
replace_once(
    "docs/project/MODULE_STATUS.md",
    "| Other product modules | Active parallel work | Build184 / 0.14.17 is the accepted overall runtime baseline on `main`. Build190 / 0.14.23 is the current home-carousel release-owner candidate; Build191 / 0.14.24 is reserved for the independent detail episode-selection follow-up. Neither replaces Build184 until accepted. |",
    "| Other product modules | Active parallel work | Build184 / 0.14.17 is the accepted overall runtime baseline on `main`. Build191 / 0.14.24 belongs to the independent detail episode-selection follow-up, Build192 / 0.14.25 belongs to Add/Edit Emby, and Build193 / 0.14.26 is the independent home-carousel release-owner candidate. None replaces Build184 until accepted. |",
)

# BUILD_TEST_INDEX
replace_once(
    "docs/project/BUILD_TEST_INDEX.md",
    "| **Build190 / 0.14.23** | Passive native movement sampling + single SwiftUI release owner | Native raw/coalesced samples remain the only progress writer; native recognizer no longer claims horizontal recognition, while SwiftUI keeps the original predicted `onEnded` commit/cancel semantics. Dedicated Release CI passed, IPA produced and downloaded checksums verified. **Real-device pending.** |",
    "| **Build190 / 0.14.23** | Carousel release-owner implementation under collided identity | The passive-native / SwiftUI-release implementation passed dedicated Release CI and produced an IPA, but the same Build190 identity was already used by the parallel detail-selection line. **Carousel Build190 identity retired; do not distribute or use for attribution.** |",
)
p = Path("docs/project/BUILD_TEST_INDEX.md")
s = p.read_text()
row = "| **Build193 / 0.14.26** | Carousel passive native movement + single SwiftUI release owner | Same release-owner product fix previously compiled under collided carousel 190/191 identities, now assigned a unique build after Build191 was reserved for detail and Build192 for Add/Edit Emby. Dedicated Release CI passed, IPA/checksums verified. **Real-device pending.** |"
if row not in s:
    anchor = "| **Build191 / 0.14.24** | Detail selected-episode summary/card title unification | Detail Build190 screenshots positively confirmed quick-range selection retention but exposed inconsistent compact summary formatting. Build191 reuses the exact horizontal-card `displayEpisodeTitle(episode)` formatter instead of maintaining a second summary format. Dedicated Xcode 16.4 Release CI passed, IPA/checksums verified. **Real-device pending.** |"
    if anchor not in s:
        raise SystemExit("missing Build191 index anchor")
    p.write_text(s.replace(anchor, anchor + "\n" + row, 1))

# PROJECT_STATE summary/history
replace_once(
    "docs/project/PROJECT_STATE.md",
    "_Last updated after Build190 / OnePlayer 0.14.23 completed dedicated carousel Release CI/IPA, while the independent detail line produced Build191 / OnePlayer 0.14.24 after Build190 detail screenshots confirmed quick-range selection retention but exposed summary/card title mismatch. Build191 now reuses the card title formatter and has dedicated Release CI/IPA evidence. Build184 / OnePlayer 0.14.17 remains the accepted overall functional baseline on `main`; neither Build190 nor Build191 replaces it until target-device evidence is accepted._",
    "_Last updated after Build189 real-device testing exposed a carousel release-settle regression and the corrected passive-native / SwiftUI-release implementation was reassigned around parallel build reservations to OnePlayer 0.14.26 / Build193. Build193 completed dedicated Release CI/IPA and is the current independent carousel candidate. Build191 / 0.14.24 remains the detail summary-title candidate and Build192 / 0.14.25 belongs to Add/Edit Emby. Build184 / 0.14.17 remains the accepted overall functional baseline on `main`; none of these candidates replaces it until target-device evidence is accepted._",
)
replace_once(
    "docs/project/PROJECT_STATE.md",
    "Build180 / OnePlayer 0.14.13 is a **historical partial-improvement carousel build**: real-device testing confirmed reversal continuity improved, but initial motion still felt coarse, so it was not accepted. Build185 / OnePlayer 0.14.18 restored the required page-slide interaction but was also **real-device rejected**. Build187 / OnePlayer 0.14.20 completed the diagnostic gate on real device: first useful SwiftUI horizontal samples were already about 4.33/8.00/15.67/11.00pt with maxFPS=120 and Low Power Mode off. Build189 / OnePlayer 0.14.22 proved native raw/coalesced sampling could drive intermediate progress, but was **real-device rejected** because releasing the finger could leave that partial transition frozen instead of completing/cancelling. Build190 / OnePlayer 0.14.23 is now the valid independent carousel candidate with CI/IPA evidence.",
    "Build180 / OnePlayer 0.14.13 is a **historical partial-improvement carousel build**: real-device testing confirmed reversal continuity improved, but initial motion still felt coarse, so it was not accepted. Build185 / OnePlayer 0.14.18 restored the required page-slide interaction but was also **real-device rejected**. Build187 / OnePlayer 0.14.20 completed the diagnostic gate on real device: first useful SwiftUI horizontal samples were already about 4.33/8.00/15.67/11.00pt with maxFPS=120 and Low Power Mode off. Build189 / OnePlayer 0.14.22 proved native raw/coalesced sampling could drive intermediate progress, but was **real-device rejected** because releasing the finger could leave that partial transition frozen instead of completing/cancelling. The corrected passive-native / SwiftUI-release implementation first passed CI under carousel Build190/191 identities, but those identities conflict with parallel detail work; Build192 belongs to Add/Edit Emby. **Build193 / OnePlayer 0.14.26 is the unique current carousel candidate with CI/IPA evidence.**",
)
project = Path("docs/project/PROJECT_STATE.md")
s = project.read_text()
start = "### Build190 / OnePlayer 0.14.23 — home-carousel native movement + SwiftUI release ownership\n"
end = "\n### Build189 / OnePlayer 0.14.22 — home-carousel native-touch input\n"
if "### Build193 / OnePlayer 0.14.26 — home-carousel native movement + SwiftUI release ownership" not in s:
    i = s.find(start)
    j = s.find(end)
    if i < 0 or j < 0 or j <= i:
        raise SystemExit("missing Build190 project-state section")
    new_section = """### Build193 / OnePlayer 0.14.26 — home-carousel native movement + SwiftUI release ownership

`DEV-home-carousel-drag-smoothness` remains Active. Build193 is the unique valid identity for the Build189 release-settle fix after Build190/191 collided with parallel detail work and Build192 was reserved for Add/Edit Emby.

- Build189 real-device result: **rejected** — drag progress followed the finger, but releasing could leave the page frozen at the exact intermediate progress; supplied recording was 9.07 s / 30 fps and showed repeated partial-transition freezes
- source cause: Build189 native recognizer entered `.began/.changed` for horizontal motion while complete/cancel remained exclusively in SwiftUI `DragGesture.onEnded`
- implementation: native raw/coalesced sampler remains the sole movement-progress owner but no longer claims horizontal recognition; SwiftUI removes per-frame `onChanged` writes and remains the sole `onEnded` / `predictedEndTranslation` / commit-cancel owner
- branch: `fix/home-carousel-native-release-build193`
- product head before dedicated CI helper: `2e162dcfaea98bc8c8d916c843498671bba0396e`
- dedicated CI source: `441d147628d2ad8ea9eee9224ed2baa2a76a7668`
- Release-workflow-restored head: `42eeb10439ecc1d02576082875c055e830f059c5`
- CI run: **`32876508226` — success**
- artifact: `OnePlayer-0.14.26-build193-home-carousel-native-release`; ID `9574238654`; digest `sha256:b7d0d27f39de3e932ae05a8abdf9bd13f0b5e1efa6f983f3f7cbd974e467b8a6`
- IPA SHA-256: `9ad6bc7bb267a6cc61fb2312a7276d41f8989aa11a7883cbc3f3ce97941081a4`; source ZIP SHA-256: `68e11e59daeaf4b245bba1949bb5d8c0825552baf7c97d280546880f5c19b860`
- MinOS: 15.0
- unchanged: 0.28 progress / 0.48×width predicted commit, full-page foreground travel, reversal continuity, backdrop/auto-advance/detail click, Player/PiP/Transport/Cache/Emby session contracts
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**
"""
    project.write_text(s[:i] + new_section + s[j:])

# TECHNICAL_DECISIONS
replace_once(
    "docs/project/TECHNICAL_DECISIONS.md",
    "Build190 establishes the corrected single-owner split: native raw/coalesced touch capture is a **passive movement sampler only** and does not enter `.began/.changed`; it explicitly cannot prevent or be prevented by other recognizers and fails at touch end. SwiftUI `DragGesture` no longer writes per-frame progress and remains the sole release owner using the existing `predictedEndTranslation`, 0.28 progress / 0.48×width predicted commit thresholds, and existing complete/cancel settle. This avoids both duplicate movement writers and a missing release owner without introducing fallback, timer, watchdog, debounce, throttle or interpolation. Build190 passed dedicated Release CI and produced IPA; real-device acceptance is still pending.",
    "The corrected single-owner split is now tracked under **Build193 / OnePlayer 0.14.26**: native raw/coalesced touch capture is a **passive movement sampler only** and does not enter `.began/.changed`; it explicitly cannot prevent or be prevented by other recognizers and fails at touch end. SwiftUI `DragGesture` no longer writes per-frame progress and remains the sole release owner using the existing `predictedEndTranslation`, 0.28 progress / 0.48×width predicted commit thresholds, and existing complete/cancel settle. This avoids both duplicate movement writers and a missing release owner without introducing fallback, timer, watchdog, debounce, throttle or interpolation. The same product fix passed CI under carousel Build190/191 identities, but those identities collided with parallel detail work and Build192 belongs to Add/Edit Emby; only Build193 is valid for carousel attribution. Build193 passed dedicated Release CI and produced IPA; real-device acceptance is still pending.",
)

# Current checkpoint: replace final candidate section by heading boundaries.
checkpoint = Path("docs/project/current/dev/DEV-home-carousel-drag-smoothness.md")
s = checkpoint.read_text()
start = "## Build189 real-device release regression / Build190 candidate\n"
if "## Build189 real-device release regression / Build193 candidate" not in s:
    i = s.find(start)
    if i < 0:
        raise SystemExit("missing Build190 checkpoint section")
    new = """## Build189 real-device release regression / Build193 candidate

- **Build189 real-device result — REJECTED**：用户安装 0.14.22 / Build189 后提供 `RPReplay_Final1787675510.mp4`（510×1108 / 30 fps / 9.07 s），明确报告“不能完整切换，滑到哪里就定格在那里”。录屏多次显示手动 progress 能随拖动到中间位置，但松手后没有 complete/cancel settle，页面停在两页之间。
- **Source evidence**：Build189 native recognizer 横向采样时进入 `.began/.changed`，而 complete/cancel 的唯一入口仍是 SwiftUI `carouselDragGesture(...).onEnded`，形成结束所有权竞争。
- **Build193 architecture**：native raw/coalesced sampler 保留，但横向时保持 passive；`canPrevent` / `canBePrevented` 均为 false，touch end/cancel 只令 sampler `.failed`。SwiftUI `DragGesture` 删除全部 per-frame `onChanged` progress 写入，只保留原 `onEnded`、`predictedEndTranslation`、0.28 / 0.48×width commit 与原 complete/cancel。移动 progress 单 owner = native；release settle 单 owner = SwiftUI。
- **Identity guard**：carousel Build190 与 Build191 均因并行 detail 任务占用相同 Build 身份而作废；Build192 已由 Add/Edit Emby 任务正式预留。carousel 本轮唯一有效身份为 **OnePlayer 0.14.26 / Build193**。
- **Build / branch**：OnePlayer **0.14.26 / Build193**；`fix/home-carousel-native-release-build193`。
- **Product head before dedicated CI helper**：`2e162dcfaea98bc8c8d916c843498671bba0396e`。
- **CI source / run**：`441d147628d2ad8ea9eee9224ed2baa2a76a7668`；run **`32876508226` success**；Release workflow restored at `42eeb10439ecc1d02576082875c055e830f059c5`。
- **Artifact**：`OnePlayer-0.14.26-build193-home-carousel-native-release`；ID `9574238654`；digest `sha256:b7d0d27f39de3e932ae05a8abdf9bd13f0b5e1efa6f983f3f7cbd974e467b8a6`。IPA SHA-256 **`9ad6bc7bb267a6cc61fb2312a7276d41f8989aa11a7883cbc3f3ce97941081a4`**；source ZIP SHA-256 `68e11e59daeaf4b245bba1949bb5d8c0825552baf7c97d280546880f5c19b860`；MinOS 15.0。
- **Evidence**：Build189 = **real-device rejected / not stable**；Build193 = **Code written / CI passed / IPA produced / real-device pending / not stable**。
- **Next exact action**：真机先验证松手必定完整 commit/cancel，再重新比较极小起滑、慢拖、连续反向与 EX 的细腻度。
"""
    checkpoint.write_text(s[:i] + new)
