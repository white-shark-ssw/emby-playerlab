from pathlib import Path
import re

MERGE_SHA = "f153a36e9da8a208150fe638e0b9df5835df1dc0"
PR = "#257"


def replace_prefixed_line(text: str, prefix: str, replacement: str, label: str) -> str:
    lines = text.splitlines()
    matches = [i for i, line in enumerate(lines) if line.startswith(prefix)]
    if len(matches) != 1:
        raise SystemExit(f"{label} match count={len(matches)}")
    lines[matches[0]] = replacement
    return "\n".join(lines) + ("\n" if text.endswith("\n") else "")


def replace_paragraph(text: str, prefix: str, replacement: str, label: str) -> str:
    pattern = re.compile(r"(?m)^" + re.escape(prefix) + r".*?(?=\n\n|\Z)", re.S)
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f"{label} match count={len(matches)}")
    match = matches[0]
    return text[:match.start()] + replacement + text[match.end():]


# MODULE_STATUS.md — preserve parallel Build192/193 and the separately confirmed player-overlay regression.
path = Path("docs/project/MODULE_STATUS.md")
text = path.read_text()
text = replace_prefixed_line(
    text,
    "| Detail episode selection navigation |",
    f"| Detail episode selection navigation | **Stable at Build191 / merged to main** | Build191 / 0.14.24 was accepted on the target device and merged through PR {PR} at `{MERGE_SHA}`. Detail horizontal cards select only; normal Series entry selects explicit initial episode → resumable episode → canonical first episode; quick range buttons select the target-range first episode; the compact summary reuses the exact card title formatter; full-picker playback closes back to the same picker/scroll position. Build182 scroll/cache, Build176 source-owned episode-session replacement and Build178 canonical order remain unchanged. This does not resolve the separately confirmed in-player nonstandard season-grouping regression. |",
    "MODULE_STATUS detail row",
)
text = replace_prefixed_line(
    text,
    "| Other product modules |",
    "| Other product modules | Active parallel work | Build191 / 0.14.24 is the accepted overall runtime baseline on `main`. Build192 / 0.14.25 remains the independent Add/Edit Emby candidate and Build193 / 0.14.26 remains the independent home-carousel candidate; both must resync with Build191 and rerun affected validation before final integration. |",
    "MODULE_STATUS other modules row",
)
if "nonstandard season-grouping regression confirmed" not in text or "Build193" not in text:
    raise SystemExit("MODULE_STATUS parallel/regression evidence would be lost")
path.write_text(text)


# BUILD_TEST_INDEX.md
path = Path("docs/project/BUILD_TEST_INDEX.md")
text = path.read_text()
text = replace_prefixed_line(
    text,
    "| **Build184 / 0.14.17** |",
    "| **Build184 / 0.14.17** | Detail performance/cache + visual hierarchy completion | Inherits accepted Build181/182 detail scroll and persistent presentation cache, moves “视频信息” below “更多类似” and above the bottom glass media-source card, and uses 19 pt bold main detail section headers. Dedicated Release CI/IPA succeeded; user accepted the final result on target device and PR #255 merged to `main`. **Previous accepted overall baseline; inherited unchanged by Build191.** |",
    "BUILD_TEST_INDEX Build184 row",
)
text = replace_prefixed_line(
    text,
    "| **Build191 / 0.14.24** |",
    f"| **Build191 / 0.14.24** | Detail episode-selection/navigation completion | Inherits the Build188/190 detail-selection follow-ups and unifies the compact summary with the exact horizontal-card `displayEpisodeTitle(episode)` formatter. User accepted the complete detail/episode-page behavior on the target device and PR {PR} merged to `main` at `{MERGE_SHA}`. **Current accepted overall baseline / stable for this detail-selection task.** |",
    "BUILD_TEST_INDEX Build191 row",
)
start = text.index("## Current accepted baseline\n")
end = text.index("## Episode-selection evidence trail\n", start)
accepted = f'''## Current accepted baseline

- OnePlayer **0.14.24 / Build191**
- canonical branch: `main`
- final merge PR: `{PR}`
- final merge commit: `{MERGE_SHA}`
- development branch: `feat/detail-episode-selection-navigation`
- final feature head before merge: `8279df9f8ceb7605bad1fade9bcba2582cddbbd6`
- functional Build191 commit: `6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`
- dedicated CI source: `63fb252936360b284d75c4477d41587193e4fbd8`
- CI run: `32875670990`
- artifact: `OnePlayer-0.14.24-build191-detail-summary-title`
- artifact ID: `9573898096`
- IPA: `OnePlayer-0.14.24-build191-detail-summary-title-unsigned.ipa`
- IPA SHA-256: `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`
- source ZIP SHA-256: `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`
- target device: iPhone 15 Pro Max / iOS 17.0
- Deployment Target / MinOS: **iOS 15.0**
- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable for completed detail-selection requirements / merged to main**

Build182 remains accepted/frozen for detail scrolling and force-quit/relaunch presentation restoration; Build184 remains the accepted detail visual-hierarchy foundation. Build191 is now the accepted overall runtime baseline and adds the accepted detail episode-selection/navigation contract. Build192 / 0.14.25 Add/Edit Emby and Build193 / 0.14.26 home-carousel remain independent candidates; each must resync with Build191 and rerun affected validation before final integration. The separately confirmed in-player nonstandard season-grouping regression remains unresolved and is not part of Build191 acceptance.

'''
text = text[:start] + accepted + text[end:]
marker = "## Maintenance rule\n"
section = f'''## Build191 detail episode-selection acceptance

- task: `DEV-detail-episode-selection-navigation` — completed and checkpoint retired after merge
- branch: `feat/detail-episode-selection-navigation`
- PR: `{PR}` — merged
- merge commit: `{MERGE_SHA}`
- functional Build191 commit: `6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`
- dedicated CI source / run: `63fb252936360b284d75c4477d41587193e4fbd8` / `32875670990` — success
- artifact: `OnePlayer-0.14.24-build191-detail-summary-title`; ID `9573898096`; digest `sha256:f5403fad91f65ac3cd1810452f7aed9a4537f7a6d46b822f87e83261738dae61`
- IPA SHA-256: `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`
- source ZIP SHA-256: `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`
- MinOS: 15.0
- accepted real-device behavior: detail horizontal cards select without autoplay; normal entry selects explicit initial → resumable → canonical first episode; quick-range buttons select that range's first episode; main Play/Resume plays the selected episode; full picker stays mounted during playback and returns at the same scroll position; compact selected summary exactly matches the selected horizontal-card title.
- inherited/frozen: Build176 source-owned episode-session replacement, Build178 canonical Emby ordering, Build182 detail scroll/presentation cache, Build173 PiP, MPV fast Seek, UnifiedTransport/Range/302/115 client-direct.
- scope boundary: the separate in-player episode-overlay nonstandard season-grouping regression remains unresolved and is not claimed fixed by Build191.
- evidence: **Code written / CI passed / IPA produced / real-device accepted / stable / merged to main**.

'''
if "## Build191 detail episode-selection acceptance\n" not in text:
    if marker not in text:
        raise SystemExit("BUILD_TEST_INDEX maintenance marker missing")
    text = text.replace(marker, section + marker, 1)
if "Build193 / 0.14.26" not in text:
    raise SystemExit("BUILD_TEST_INDEX Build193 evidence would be lost")
path.write_text(text)


# PROJECT_STATE.md
path = Path("docs/project/PROJECT_STATE.md")
text = path.read_text()
text = replace_prefixed_line(
    text,
    "_Last updated",
    f"_Last updated after Build191 / OnePlayer 0.14.24 was accepted on the target device and merged to `main` through PR {PR} at `{MERGE_SHA}`. Build191 is now the accepted overall functional baseline. Build192 / OnePlayer 0.14.25 Add/Edit Emby and Build193 / OnePlayer 0.14.26 home-carousel remain independent Active candidates and must resync with Build191 before final integration. The separately confirmed in-player nonstandard season-grouping regression remains unresolved._",
    "PROJECT_STATE last-updated line",
)
base_start = text.index("The latest **real-device accepted** functional baseline is:\n")
base_end_marker = "\n\nBuild184 inherits"
base_end = text.index(base_end_marker, base_start)
new_base = f'''The latest **real-device accepted** functional baseline is:

- Product: **OnePlayer**
- Version: **0.14.24**
- Build: **191**
- Canonical branch: `main`
- Final merge PR: **{PR}**
- Final merge commit: `{MERGE_SHA}`
- Development branch: `feat/detail-episode-selection-navigation`
- Final feature head before merge: `8279df9f8ceb7605bad1fade9bcba2582cddbbd6`
- Functional Build191 commit: `6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`
- Dedicated CI source: `63fb252936360b284d75c4477d41587193e4fbd8`
- Dedicated CI run: **32875670990**
- Artifact: `OnePlayer-0.14.24-build191-detail-summary-title`
- IPA SHA-256: `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`
- Deployment Target: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**'''
text = text[:base_start] + new_base + text[base_end:]
text = replace_paragraph(
    text,
    "Build184 / OnePlayer 0.14.17 is",
    "Build184 / OnePlayer 0.14.17 remains **real-device accepted and stable as the detail performance/cache + visual-hierarchy foundation**, merged through PR #255. Its behavior is inherited unchanged by Build191.",
    "PROJECT_STATE Build184 paragraph",
)
text = replace_paragraph(
    text,
    "Build191 / OnePlayer 0.14.24 is",
    f"Build191 / OnePlayer 0.14.24 is **real-device accepted and merged to `main` through PR {PR} at `{MERGE_SHA}`**. It completes the detail episode-selection/navigation line: select-only horizontal cards with blue selection, explicit-initial → Resume → canonical-first default selection, range-first quick jumps, main Play/Resume targeting the selected episode, non-dismissing full-picker playback that returns at the same scroll position, and a compact summary that exactly reuses the card title formatter. Build176 session replacement, Build178 canonical order and Build182 detail performance/cache remain unchanged. This acceptance does not cover the separately confirmed in-player nonstandard season-grouping regression.",
    "PROJECT_STATE Build191 paragraph",
)
accepted_marker = "The original failing non-standard series had 165 episodes with `nilIndex=164`; Build178 was accepted on real device after switching the shared data path to Emby's TV ordering authority.\n"
accepted_add = '''

Build191 adds the accepted detail-browsing contract on top of those player/order owners:

- tapping a horizontal detail episode card changes `selectedEpisodeID` only; it does not autoplay;
- the blue outline represents the current selected episode, not a separate “currently playing” owner;
- normal Series entry selects explicit `initialEpisodeID`, otherwise a resumable episode, otherwise canonical `episodes.first`;
- quick range buttons select the first episode in that canonical range instead of clearing selection;
- the existing main Play/Resume button plays the selected episode through the existing source-owned playback path;
- the full episode picker stays mounted while its selected episode plays, so closing player returns to the same picker/ScrollView position without a second manual offset cache;
- the compact selected-episode summary directly reuses `displayEpisodeTitle(episode)`, the same formatter as the horizontal card.

This detail-page acceptance is separate from the in-player episode overlay. The confirmed nonstandard season-grouping regression in that player overlay remains unresolved.
'''
if accepted_marker not in text:
    raise SystemExit("PROJECT_STATE accepted-order marker missing")
if "Build191 adds the accepted detail-browsing contract" not in text:
    text = text.replace(accepted_marker, accepted_marker + accepted_add, 1)
heading = "### Build191 / OnePlayer 0.14.24 — detail selected-episode title unification\n"
if heading in text:
    hs = text.index(heading)
    hn = text.index("\n### ", hs + len(heading))
    text = text[:hs] + text[hn + 1:]
if "Build193 / OnePlayer 0.14.26" not in text or "Build192 / OnePlayer 0.14.25" not in text:
    raise SystemExit("PROJECT_STATE parallel candidates would be lost")
path.write_text(text)


# TECHNICAL_DECISIONS.md
path = Path("docs/project/TECHNICAL_DECISIONS.md")
text = path.read_text()
if "## D014 — Detail episode browsing separates selection from playback" not in text:
    text = text.rstrip() + f'''\n\n## D014 — Detail episode browsing separates selection from playback and keeps one selected-episode owner

Build191 establishes the accepted detail/episode-page interaction contract. Detail browsing selection and playback are intentionally separate actions, while `selectedEpisodeID` remains the single visible selection owner.

- tapping a horizontal detail episode card only selects it and moves the blue outline; it does not immediately play;
- the existing main Play/Resume button remains the detail-page playback action and targets the selected episode through the existing source-owned playback path;
- normal Series entry chooses explicit `initialEpisodeID` first, otherwise the existing resumable episode, otherwise canonical `episodes.first` from the Build178 Emby TV order;
- quick range buttons select that range's first canonical episode rather than clearing selection;
- the compact selected-episode summary must reuse `displayEpisodeTitle(episode)`, the exact formatter used by the horizontal card, instead of maintaining a second naming/classification path;
- full-picker row taps may select and play directly, but the picker must not dismiss before playback and must not add a fixed delay; the visible picker presents the shared `model.selectedSource`, so closing player reveals the same picker/ScrollView instance and preserves its position without a second offset cache;
- no second playback-source owner, selected-episode owner, timer, retry, watchdog or manual scroll-position reconciliation is part of this architecture.

This contract inherits Build176 source-owned episode-session replacement, Build178 canonical Emby episode ordering, and Build182 detail scroll/presentation-cache ownership unchanged. It applies to detail-page and full-detail-picker browsing; it does **not** claim to fix the separately confirmed in-player episode-overlay nonstandard season-grouping regression. **Build191 / OnePlayer 0.14.24 passed dedicated Xcode 16.4 Release CI, produced the validated IPA, was accepted by the user on the target device, and merged to `main` through PR {PR} at `{MERGE_SHA}`.** Treat this detail selection/navigation behavior as stable unless new target-device regression evidence requires reopening it.\n'''
path.write_text(text)
