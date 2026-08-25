from pathlib import Path

checkpoint = Path('docs/project/current/dev/DEV-detail-episode-selection-navigation.md')
text = checkpoint.read_text()
old = '- 功能 commit：`6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`；窄 selection/navigation、range jump、Resume 静态合同已通过。Release CI / IPA / Build191 真机仍 pending。'
new = '''- 功能 commit：`6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`；selection/navigation、range jump、Resume 静态合同已通过。
- Dedicated Build191 Release run：**`32875670990` — success**；CI source `63fb252936360b284d75c4477d41587193e4fbd8`；workflow-restored feature head `516f5cf6e8832af083d3c2605e365cb1dcb7119a`。
- Artifact：`OnePlayer-0.14.24-build191-detail-summary-title`；ID **`9573898096`**；digest `sha256:f5403fad91f65ac3cd1810452f7aed9a4537f7a6d46b822f87e83261738dae61`。
- IPA：`OnePlayer-0.14.24-build191-detail-summary-title-unsigned.ipa`；SHA-256 **`03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`**；下载后二次校验与 artifact 内 `.sha256` 一致。
- Source ZIP SHA-256：`25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`；iOS MinOS 15.0 audit passed。
- Build191 real-device 仍 pending；不能把 CI/IPA 描述成真机已验收。'''
if old not in text:
    raise SystemExit('checkpoint Build191 evidence marker missing')
text = text.replace(old, new, 1)
text = text.replace('- Build191：**Code written / narrow static checks passed / Release CI pending / IPA pending / real-device pending / not stable**。', '- Build191：**Code written / source-static checks passed / Release CI passed / IPA produced / real-device pending / not stable**。', 1)
old_next = '''1. 跑 Build191 / 0.14.24 dedicated Xcode 16.4 Release CI/IPA；保持 iOS 15.0 和现有 frozen/P0 合同。
2. Build191 真机确认上方摘要与下方选中卡片标题逐字一致，同时继续验证有 Resume / 无 Resume 的默认蓝框选择与完整 picker 播放后原位返回。
3. 真机验收前不提升 accepted baseline。'''
new_next = '''1. 用户安装 Build191 真机确认上方摘要与下方选中卡片标题逐字一致。
2. 同一轮继续验证有 Resume / 无 Resume 的默认蓝框选择与完整 picker 播放后原位返回。
3. 真机验收前不提升 accepted baseline。'''
if old_next not in text:
    raise SystemExit('checkpoint next marker missing')
text = text.replace(old_next, new_next, 1)
checkpoint.write_text(text)

module = Path('docs/project/MODULE_STATUS.md')
text = module.read_text()
old_row = '| Detail episode selection navigation | **Active Build191 candidate; Build190 real-device partial / follow-up required** | Detail Build190 target-device screenshots confirm quick range jumps retain selection/blue outline and summary state, but exposed summary/card title mismatch. User now requires the summary to be exactly identical to the selected horizontal card title. Build191 / 0.14.24 removes the second summary formatter and directly reuses `displayEpisodeTitle(episode)`; code + narrow contracts passed, Release CI/IPA pending. Default-entry selection and full-picker return still require complete acceptance evidence. Build182 scroll/cache, Build176 player session replacement and Build178 canonical order remain unchanged. |'
new_row = '| Detail episode selection navigation | **Active Build191 candidate; Build190 detail real-device partial** | Detail Build190 target-device screenshots confirm quick range jumps retain selection/blue outline and summary state, but exposed summary/card title mismatch. Build191 / 0.14.24 removes the second summary formatter and directly reuses `displayEpisodeTitle(episode)` so the compact summary and selected horizontal card title are identical. Dedicated Release CI passed and IPA was produced; real-device validation is pending. Default-entry selection and full-picker return still require complete acceptance evidence. Build182 scroll/cache, Build176 player session replacement and Build178 canonical order remain unchanged. |'
if old_row not in text:
    raise SystemExit('module Build191 row missing')
text = text.replace(old_row, new_row, 1)
module.write_text(text)

index = Path('docs/project/BUILD_TEST_INDEX.md')
text = index.read_text()
old188 = '| **Build188 / 0.14.21** | Detail episode selection semantics + full picker return | Detail horizontal cards select-only with blue outline and compact selected-episode summary; main Play/Resume plays the selected episode. Full picker no longer dismisses before playback, so closing player should reveal the same picker/scroll position. Dedicated Release CI/IPA succeeded; **real-device evidence pending.** |'
new188 = '| **Build188 / 0.14.21** | Detail episode selection semantics + full picker return | Dedicated Release CI/IPA succeeded. **Real-device follow-up required:** normal Series entry lacked a visible default selection and quick range buttons cleared selection/title; these state issues were addressed on the later detail line. Not accepted/stable. |'
if old188 in text:
    text = text.replace(old188, new188, 1)
row190 = '| **Build190 / 0.14.23** | Passive native movement sampling + single SwiftUI release owner | Native raw/coalesced samples remain the only progress writer; native recognizer no longer claims horizontal recognition, while SwiftUI keeps the original predicted `onEnded` commit/cancel semantics. Dedicated Release CI passed, IPA produced and downloaded checksums verified. **Real-device pending.** |'
row191 = '| **Build191 / 0.14.24** | Detail selected-episode summary/card title unification | Detail Build190 screenshots positively confirmed quick-range selection retention but exposed inconsistent compact summary formatting. Build191 reuses the exact horizontal-card `displayEpisodeTitle(episode)` formatter instead of maintaining a second summary format. Dedicated Xcode 16.4 Release CI passed, IPA/checksums verified. **Real-device pending.** |'
if row191 not in text:
    if row190 not in text:
        raise SystemExit('index Build190 home row missing')
    text = text.replace(row190, row190 + '\n' + row191, 1)
old_summary = 'Build182 remains real-device accepted/frozen for the two detail performance/cache requirements and is inherited by Build184. Build184 / 0.14.17 is the accepted overall runtime baseline merged to `main`; Build187 completed the carousel diagnostic gate, Build189 is real-device rejected for the release-settle regression, Build190 / 0.14.23 is the current independent home-carousel candidate, and Build188 / 0.14.21 remains the independent detail/episode-selection candidate. Build188 and Build190 remain real-device pending and neither replaces Build184.'
new_summary = 'Build182 remains real-device accepted/frozen for the two detail performance/cache requirements and is inherited by Build184. Build184 / 0.14.17 is the accepted overall runtime baseline merged to `main`; Build189 is real-device rejected for the carousel release-settle regression, Build190 / 0.14.23 is the current home-carousel candidate, and Build191 / 0.14.24 is the current detail/episode-selection follow-up candidate. Build190 and Build191 are real-device pending and neither replaces Build184.'
if old_summary in text:
    text = text.replace(old_summary, new_summary, 1)
index.write_text(text)

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
old_updated = '_Last updated after Build189 / OnePlayer 0.14.22 was real-device rejected because releasing a native-sampled drag could leave the carousel frozen at an intermediate progress, and Build190 / OnePlayer 0.14.23 completed dedicated Release CI/IPA with single-owner movement/release semantics. Build188 / OnePlayer 0.14.21 remains the independent detail/episode-selection navigation candidate. Build184 / OnePlayer 0.14.17 remains the accepted overall functional baseline on `main`; neither Build188 nor Build190 replaces it until target-device evidence is accepted._'
new_updated = '_Last updated after Build190 / OnePlayer 0.14.23 completed dedicated carousel Release CI/IPA, while the independent detail line produced Build191 / OnePlayer 0.14.24 after Build190 detail screenshots confirmed quick-range selection retention but exposed summary/card title mismatch. Build191 now reuses the card title formatter and has dedicated Release CI/IPA evidence. Build184 / OnePlayer 0.14.17 remains the accepted overall functional baseline on `main`; neither Build190 nor Build191 replaces it until target-device evidence is accepted._'
if old_updated in text:
    text = text.replace(old_updated, new_updated, 1)
old188p = 'Build188 / OnePlayer 0.14.21 is the current independent **detail/episode-selection navigation candidate**. Detail horizontal episode cards now select only and retain the blue selected outline; a compact 12 pt selected-episode summary appears above the horizontal cards, while the existing main Play/Resume button remains the playback action. Full picker episode playback no longer dismisses the picker or waits 100 ms before resolving playback; the visible picker presents the shared `model.selectedSource`, so closing player should return to the same picker instance/scroll position. Dedicated Release run `32864835934` passed, artifact `9569812832` was produced, and downloaded IPA SHA-256 `c82fcca99162f4840d8b0fccdb7c2f6203426d12901ef5d6ac4f4879db78b9ff` matched the artifact checksum. **Real-device evidence is pending; accepted baseline remains Build184.**'
new_detail = '''Build188 / OnePlayer 0.14.21 established the independent **detail/episode-selection navigation candidate**: select-only horizontal cards, compact selected-episode summary and non-dismissing full picker playback. Dedicated Release CI/IPA succeeded. Target-device follow-up then showed missing default visible selection and quick range buttons clearing selection/title, so Build188 was not accepted.

The detail branch later produced its own **0.14.23 / Build190** package (`OnePlayer-0.14.23-build190-detail-selection-defaults`, IPA SHA-256 `2f05197cebe43b6a50c2eb84225b7d134f364f82baf58772f86d10653f2f298c`). User screenshots from that exact distributed artifact positively confirm quick `10-19 / 20-24` range jumps now retain the target first episode blue selection and summary state. Those screenshots also exposed a pure display inconsistency between the compact summary and horizontal-card title. The same 0.14.23 / Build190 identity was later occupied independently by the home-carousel candidate, so detail no longer reuses that identity; attribution of the screenshots remains tied to the detail artifact SHA above.

Build191 / OnePlayer 0.14.24 is now the independent **detail summary-title follow-up candidate**. `selectedEpisodeSelectionSummary` directly reuses `displayEpisodeTitle(episode)`, the exact formatter used by the selected horizontal card, so the two strings are intentionally identical. Dedicated Release run `32875670990` passed; artifact `OnePlayer-0.14.24-build191-detail-summary-title` ID `9573898096`; downloaded IPA SHA-256 `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`; source ZIP SHA-256 `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`; MinOS 15.0. **Real-device evidence is pending; accepted baseline remains Build184.**'''
if old188p in text:
    text = text.replace(old188p, new_detail, 1)
elif 'Build191 / OnePlayer 0.14.24 is now the independent **detail summary-title follow-up candidate**.' not in text:
    raise SystemExit('PROJECT_STATE detail paragraph marker missing')
marker = '## Current parallel feature candidates\n\n### Build190 / OnePlayer 0.14.23 — home-carousel native movement + SwiftUI release ownership\n'
section = '''## Current parallel feature candidates

### Build191 / OnePlayer 0.14.24 — detail selected-episode title unification

`DEV-detail-episode-selection-navigation` remains Active. Build191 preserves Build190-detail selection/navigation behavior and changes only the compact selected-episode summary formatter.

- branch: `feat/detail-episode-selection-navigation`
- functional commit: `6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`
- dedicated CI source: `63fb252936360b284d75c4477d41587193e4fbd8`
- workflow-restored head: `516f5cf6e8832af083d3c2605e365cb1dcb7119a`
- CI run: **`32875670990` — success**
- artifact: `OnePlayer-0.14.24-build191-detail-summary-title`; ID `9573898096`; digest `sha256:f5403fad91f65ac3cd1810452f7aed9a4537f7a6d46b822f87e83261738dae61`
- IPA SHA-256: `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`; source ZIP SHA-256: `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`
- MinOS: 15.0
- implementation: compact selected-episode summary returns the existing `displayEpisodeTitle(episode)` result used by the horizontal card; no second title-format owner remains
- unchanged: default selection, quick-range selection, full-picker playback return path, canonical ordering, detail cache/scroll, Player/PiP/Transport/Cache
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

### Build190 / OnePlayer 0.14.23 — home-carousel native movement + SwiftUI release ownership
'''
if marker in text:
    text = text.replace(marker, section, 1)
elif '### Build191 / OnePlayer 0.14.24 — detail selected-episode title unification' not in text:
    raise SystemExit('PROJECT_STATE parallel marker missing')
state.write_text(text)
