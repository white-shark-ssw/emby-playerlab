from pathlib import Path

MERGE_SHA = "f153a36e9da8a208150fe638e0b9df5835df1dc0"
PR = "#257"

# MODULE_STATUS.md
path = Path("docs/project/MODULE_STATUS.md")
text = path.read_text()
old = '| Detail episode selection navigation | **Active Build191 candidate; Build190 detail real-device partial** | Detail Build190 target-device screenshots confirm quick range jumps retain selection/blue outline and summary state, but exposed summary/card title mismatch. Build191 / 0.14.24 removes the second summary formatter and directly reuses `displayEpisodeTitle(episode)` so the compact summary and selected horizontal card title are identical. Dedicated Release CI passed and IPA was produced; real-device validation is pending. Default-entry selection and full-picker return still require complete acceptance evidence. Build182 scroll/cache, Build176 player session replacement and Build178 canonical order remain unchanged. |'
new = f'| Detail episode selection navigation | **Stable at Build191 / merged to main** | Build191 / 0.14.24 was accepted on the target device and merged through PR {PR} at `{MERGE_SHA}`. Detail horizontal cards select only; normal Series entry selects explicit initial episode → resumable episode → canonical first episode; quick range buttons select the target range first episode; the compact summary reuses the exact card title formatter; full-picker playback closes back to the same picker/scroll position. Build182 scroll/cache, Build176 player session replacement and Build178 canonical order remain unchanged. |'
if old not in text:
    raise SystemExit("MODULE_STATUS detail row changed unexpectedly")
text = text.replace(old, new, 1)
old = '| Other product modules | Active parallel work | Build184 / 0.14.17 is the accepted overall runtime baseline on `main`. Build190 / 0.14.23 is the current home-carousel release-owner candidate; Build191 / 0.14.24 is reserved for the independent detail episode-selection follow-up. Neither replaces Build184 until accepted. |'
new = '| Other product modules | Active parallel work | Build191 / 0.14.24 is the accepted overall runtime baseline on `main`. Build190 / 0.14.23 remains the independent home-carousel candidate and Build192 / 0.14.25 is reserved by Add Emby; both must resync with the accepted Build191 baseline before final integration. |'
if old not in text:
    raise SystemExit("MODULE_STATUS other-modules row changed unexpectedly")
text = text.replace(old, new, 1)
path.write_text(text)

# BUILD_TEST_INDEX.md
path = Path("docs/project/BUILD_TEST_INDEX.md")
text = path.read_text()
old184 = '| **Build184 / 0.14.17** | Detail performance/cache + visual hierarchy completion | Inherits accepted Build181/182 detail scroll and persistent presentation cache, moves “视频信息” below “更多类似” and above the bottom glass media-source card, and uses 19 pt bold main detail section headers. Dedicated Release CI/IPA succeeded; user accepted the final result on target device and PR #255 merged to `main`. **Current accepted overall baseline.** |'
new184 = '| **Build184 / 0.14.17** | Detail performance/cache + visual hierarchy completion | Inherits accepted Build181/182 detail scroll and persistent presentation cache, moves “视频信息” below “更多类似” and above the bottom glass media-source card, and uses 19 pt bold main detail section headers. Dedicated Release CI/IPA succeeded; user accepted the final result on target device and PR #255 merged to `main`. **Previous accepted overall baseline; inherited by Build191.** |'
if old184 not in text:
    raise SystemExit("BUILD_TEST_INDEX Build184 row changed unexpectedly")
text = text.replace(old184, new184, 1)
old191 = '| **Build191 / 0.14.24** | Detail selected-episode summary/card title unification | Detail Build190 screenshots positively confirmed quick-range selection retention but exposed inconsistent compact summary formatting. Build191 reuses the exact horizontal-card `displayEpisodeTitle(episode)` formatter instead of maintaining a second summary format. Dedicated Xcode 16.4 Release CI passed, IPA/checksums verified. **Real-device pending.** |'
new191 = f'| **Build191 / 0.14.24** | Detail episode-selection/navigation completion | Inherits Build188/190 selection follow-ups and unifies the compact summary with the exact horizontal-card `displayEpisodeTitle(episode)` formatter. User accepted the complete behavior on the target device and PR {PR} merged to `main` at `{MERGE_SHA}`. **Current accepted overall baseline / stable for this detail-selection task.** |'
if old191 not in text:
    raise SystemExit("BUILD_TEST_INDEX Build191 row changed unexpectedly")
text = text.replace(old191, new191, 1)
start = text.index('## Current accepted baseline\n')
end = text.index('## Episode-selection evidence trail\n', start)
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

Build182 remains real-device accepted/frozen for detail scrolling and force-quit/relaunch presentation restoration; Build184 remains the accepted detail visual-hierarchy foundation. Build191 is now the accepted overall runtime baseline and adds the accepted detail episode-selection/navigation contract. Build190 / 0.14.23 home-carousel remains an independent pre-Build191 candidate, and Build192 / 0.14.25 is reserved by Add Emby; either line must resync with Build191 and rerun affected validation before final integration.

'''
text = text[:start] + accepted + text[end:]
marker = '## Maintenance rule\n'
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
- accepted real-device behavior: detail horizontal cards select without autoplay; normal entry selects explicit initial → resumable → canonical first episode; quick-range buttons select that range's first episode; main Play/Resume plays the selected episode; full picker stays mounted during playback and returns at the same scroll position; compact selected summary exactly matches the selected horizontal card title.
- inherited/frozen: Build176 source-owned episode-session replacement, Build178 canonical Emby ordering, Build182 detail scroll/presentation cache, Build173 PiP, MPV fast Seek, UnifiedTransport/Range/302/115 client-direct.
- evidence: **Code written / CI passed / IPA produced / real-device accepted / stable / merged to main**.

'''
if '## Build191 detail episode-selection acceptance\n' not in text:
    if marker not in text:
        raise SystemExit("BUILD_TEST_INDEX maintenance marker missing")
    text = text.replace(marker, section + marker, 1)
path.write_text(text)

# PROJECT_STATE.md
path = Path("docs/project/PROJECT_STATE.md")
text = path.read_text()
first_start = text.index('_Last updated')
first_end = text.index('\n', first_start)
new_updated = f'_Last updated after Build191 / OnePlayer 0.14.24 was accepted on the target device and merged to `main` through PR {PR} at `{MERGE_SHA}`. Build191 is now the accepted overall functional baseline. Build190 / 0.14.23 home-carousel and Build192 / 0.14.25 Add Emby remain independent Active candidates and must resync with Build191 before final integration._'
text = text[:first_start] + new_updated + text[first_end:]
old_block = '''The latest **real-device accepted** functional baseline is:

- Product: **OnePlayer**
- Version: **0.14.17**
- Build: **184**
- Canonical branch: `main`
- Final merge PR: **#255**
- Final merge commit: `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`
- Development branch: `feat/detail-episode-page-optimization`
- Clean product head before merge: `63d4114ca6ef97b419ec31163e6431af5cf2d002`
- Dedicated CI source: `0238f2c8fd202df6e7ba52d582b1614c9230eef9`
- Dedicated CI run: **32851745960**
- Artifact: `OnePlayer-0.14.17-build184-detail-visual-refinement`
- IPA SHA-256: `d89953c76b678fe1bc0b9f3fcc8b5b5b3ea430ec74bdd420834b427c91d47eb4`
- Deployment Target: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**
'''
new_block = f'''The latest **real-device accepted** functional baseline is:

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
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**
'''
if old_block not in text:
    raise SystemExit("PROJECT_STATE baseline block changed unexpectedly")
text = text.replace(old_block, new_block, 1)
old184p = 'Build184 / OnePlayer 0.14.17 is **real-device accepted, stable for the completed detail-page requirements, and merged to `main` through PR #255**. It preserves Build182 detail performance/cache behavior and only adds the accepted visual hierarchy changes: `视频信息` below `更多类似`, above the bottom glass media-source summary, with the main section headers at 19 pt bold.'
new184p = 'Build184 / OnePlayer 0.14.17 remains **real-device accepted and stable as the detail performance/cache + visual-hierarchy foundation**, merged through PR #255. Its behavior is inherited unchanged by Build191.'
if old184p not in text:
    raise SystemExit("PROJECT_STATE Build184 paragraph changed unexpectedly")
text = text.replace(old184p, new184p, 1)
old191p = 'Build191 / OnePlayer 0.14.24 is now the independent **detail summary-title follow-up candidate**. `selectedEpisodeSelectionSummary` directly reuses `displayEpisodeTitle(episode)`, the exact formatter used by the selected horizontal card, so the two strings are intentionally identical. Dedicated Release run `32875670990` passed; artifact `OnePlayer-0.14.24-build191-detail-summary-title` ID `9573898096`; downloaded IPA SHA-256 `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`; source ZIP SHA-256 `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`; MinOS 15.0. **Real-device evidence is pending; accepted baseline remains Build184.**'
new191p = f'Build191 / OnePlayer 0.14.24 is **real-device accepted and merged to `main` through PR {PR} at `{MERGE_SHA}`**. It completes the detail episode-selection/navigation line: select-only horizontal cards with blue selection, explicit-initial → Resume → canonical-first default selection, range-first quick jumps, main Play/Resume targeting the selected episode, non-dismissing full-picker playback that returns at the same scroll position, and a compact summary that exactly reuses the card title formatter. Build176 session replacement, Build178 canonical order and Build182 detail performance/cache remain unchanged.'
if old191p not in text:
    raise SystemExit("PROJECT_STATE Build191 paragraph changed unexpectedly")
text = text.replace(old191p, new191p, 1)
accepted_marker = 'The original failing non-standard series had 165 episodes with `nilIndex=164`; Build178 was accepted on real device after switching the shared data path to Emby\'s TV ordering authority.\n'
accepted_add = '''

Build191 adds the accepted detail-browsing contract on top of those player/order owners:

- tapping a horizontal detail episode card changes `selectedEpisodeID` only; it does not autoplay;
- the blue outline represents the current selected episode, not a separate “currently playing” owner;
- normal Series entry selects explicit `initialEpisodeID`, otherwise a resumable episode, otherwise canonical `episodes.first`;
- quick range buttons select the first episode in that canonical range instead of clearing selection;
- the existing main Play/Resume button plays the selected episode through the existing source-owned playback path;
- the full episode picker stays mounted while its selected episode plays, so closing player returns to the same picker/ScrollView position without a second manual offset cache;
- the compact selected-episode summary directly reuses `displayEpisodeTitle(episode)`, the same formatter as the horizontal card.
'''
if accepted_marker not in text:
    raise SystemExit("PROJECT_STATE accepted ordering marker missing")
if 'Build191 adds the accepted detail-browsing contract' not in text:
    text = text.replace(accepted_marker, accepted_marker + accepted_add, 1)
parallel_start = text.index('### Build191 / OnePlayer 0.14.24 — detail selected-episode title unification\n')
parallel_next = text.index('### Build190 / OnePlayer 0.14.23 — home-carousel native movement + SwiftUI release ownership\n', parallel_start)
text = text[:parallel_start] + text[parallel_next:]
path.write_text(text)

# TECHNICAL_DECISIONS.md
path = Path("docs/project/TECHNICAL_DECISIONS.md")
text = path.read_text()
if '## D014 — Detail episode browsing separates selection from playback' not in text:
    text = text.rstrip() + f'''\n\n## D014 — Detail episode browsing separates selection from playback and keeps one selected-episode owner

Build191 establishes the accepted detail/episode-page interaction contract. Detail browsing selection and playback are intentionally separate actions, while `selectedEpisodeID` remains the single visible selection owner.

- tapping a horizontal detail episode card only selects it and moves the blue outline; it does not immediately play;
- the existing main Play/Resume button remains the detail-page playback action and targets the selected episode through the existing source-owned playback path;
- normal Series entry chooses explicit `initialEpisodeID` first, otherwise the existing resumable episode, otherwise canonical `episodes.first` from the Build178 Emby TV order;
- quick range buttons select that range's first canonical episode rather than clearing selection;
- the compact selected-episode summary must reuse `displayEpisodeTitle(episode)`, the exact formatter used by the horizontal card, instead of maintaining a second naming/classification path;
- full-picker row taps may select and play directly, but the picker must not dismiss before playback and must not add a fixed delay; the visible picker presents the shared `model.selectedSource`, so closing player reveals the same picker/ScrollView instance and preserves its position without a second offset cache;
- no second playback-source owner, selected-episode owner, timer, retry, watchdog or manual scroll-position reconciliation is part of this architecture.

This contract inherits Build176 source-owned episode session replacement, Build178 canonical Emby episode ordering, and Build182 detail scroll/presentation-cache ownership unchanged. **Build191 / OnePlayer 0.14.24 passed dedicated Xcode 16.4 Release CI, produced the validated IPA, was accepted by the user on the target device, and merged to `main` through PR {PR} at `{MERGE_SHA}`.** Treat this detail selection/navigation behavior as stable unless new target-device regression evidence requires reopening it.\n'''
path.write_text(text)
