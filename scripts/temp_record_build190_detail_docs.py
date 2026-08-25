from pathlib import Path
import sys

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')

checkpoint = root / 'docs/project/current/dev/DEV-detail-episode-selection-navigation.md'
text = checkpoint.read_text()
old = '- 窄检查已通过：selection/navigation、range jump、Resume；正式 Build190 CI 仍需跑完整继承合同。'
new = '- 窄检查已通过；Build190 正式 CI 也已通过 selection/navigation、range jump、Resume、Build184 visual、Hero、Build182 detail performance、Build178 canonical ordering、SeasonId grouping 与 Sources scope 合同。'
if old in text:
    text = text.replace(old, new, 1)
ci_marker = '## Build identity collision history\n'
ci_section = '''## Build190 CI / IPA evidence

- Dedicated Release run：**`32870600458` — success**。
- CI source：`943930e5113d0a55472f0bcbf80812bd82e05dd9`。
- Workflow-restored feature head：`5a574ff9abd489504d9a65d7d4132f86c9ccd69d`。
- Artifact：`OnePlayer-0.14.23-build190-detail-selection-defaults`。
- Artifact ID：`9572070999`。
- Artifact digest：`sha256:65cf97d9c6d775125fcc5270063081ab668f4e777a9ae0172692308af99e7098`。
- IPA：`OnePlayer-0.14.23-build190-detail-selection-defaults-unsigned.ipa`。
- IPA SHA-256：`2f05197cebe43b6a50c2eb84225b7d134f364f82baf58772f86d10653f2f298c`；下载 artifact 后二次校验与 artifact 内 `.sha256` 一致。
- Xcode 16.4 Release、0.14.23 (190) app identity、iOS 15.0 MinOS、IPA packaging/upload 全部通过。
- Build190 临时 Release workflow 已在成功后从 feature branch 删除。
- **Real-device pending；不能把 CI/IPA 描述为真机已解决。**

'''
if ci_section.strip() not in text:
    if ci_marker not in text:
        raise SystemExit('checkpoint CI marker missing')
    text = text.replace(ci_marker, ci_section + ci_marker, 1)
old_evidence = '''- Build188：**Code written / CI passed / IPA produced / real-device tested / follow-up required / not stable**。
- Build190 product follow-up：**Code written / narrow static checks passed**。
- Build190 Release CI：pending。
- Build190 IPA：pending。
- Build190 real-device：pending。
- Accepted overall baseline：仍为 **Build184 / 0.14.17**。'''
new_evidence = '''- Build188：**Code written / CI passed / IPA produced / real-device tested / follow-up required / not stable**。
- Build190：**Code written / source-static checks passed / Release CI passed / IPA produced / real-device pending / not stable**。
- Accepted overall baseline：仍为 **Build184 / 0.14.17**。'''
if old_evidence in text:
    text = text.replace(old_evidence, new_evidence, 1)
old_next = '''1. 跑 Build190 dedicated Xcode 16.4 Release CI：selection/navigation + range + Resume + visual + Hero + detail performance + canonical ordering + SeasonId + Sources scope + 0.14.23 (190) identity + iOS 15.0 MinOS + IPA。
2. CI/IPA 成功后删除临时 workflow，同轮更新 `BUILD_TEST_INDEX.md` / `PROJECT_STATE.md`，但不提升 accepted baseline。
3. 真机重点验证：'''
new_next = '''1. 用户安装 Build190 真机验证，不提升 accepted baseline。
2. 真机重点验证：'''
if old_next in text:
    text = text.replace(old_next, new_next, 1)
checkpoint.write_text(text)

index = root / 'docs/project/BUILD_TEST_INDEX.md'
text = index.read_text()
old188 = '| **Build188 / 0.14.21** | Detail episode selection semantics + full picker return | Detail horizontal cards select-only with blue outline and compact selected-episode summary; main Play/Resume plays the selected episode. Full picker no longer dismisses before playback, so closing player should reveal the same picker/scroll position. Dedicated Release CI/IPA succeeded; **real-device evidence pending.** |'
new188 = '| **Build188 / 0.14.21** | Detail episode selection semantics + full picker return | Dedicated Release CI/IPA succeeded. **Real-device follow-up required:** series entry did not visibly select the resume/default episode, and quick 10-episode range buttons cleared `selectedEpisodeID`, blanking the compact selected-episode title. Not accepted/stable. |'
if old188 in text:
    text = text.replace(old188, new188, 1)
row189 = '| **Build189 / 0.14.22** | Carousel native raw/coalesced-touch input | Replaces only manual drag sampling with UIKit raw/coalesced touches while preserving full-page slide semantics and the existing SwiftUI predicted release commit. Dedicated Release CI passed, IPA produced and downloaded checksums verified. **Real-device pending.** |'
row190 = '| **Build190 / 0.14.23** | Detail default episode + quick-range selection follow-up | Inherits Build188 select-only cards/full-picker return path. Series entry now selects explicit initial episode → resumable episode → canonical first episode; quick range buttons select the target range first episode instead of clearing selection. Dedicated Xcode 16.4 Release CI passed, IPA produced/checksum verified. **Real-device pending.** |'
if row190 not in text:
    if row189 not in text:
        raise SystemExit('Build189 row missing')
    text = text.replace(row189, row189 + '\n' + row190, 1)
old_summary = 'Build182 remains real-device accepted/frozen for the two detail performance/cache requirements and is inherited by Build184. Build184 / 0.14.17 is the accepted overall runtime baseline merged to `main`; Build187 has now completed the carousel diagnostic gate on real device, Build189 / 0.14.22 is the current independent home-carousel native-touch candidate, and Build188 / 0.14.21 remains the independent detail/episode-selection candidate. Build188 and Build189 remain real-device pending and neither replaces Build184.'
new_summary = 'Build182 remains real-device accepted/frozen for the two detail performance/cache requirements and is inherited by Build184. Build184 / 0.14.17 is the accepted overall runtime baseline merged to `main`; Build187 completed the carousel diagnostic gate, Build189 / 0.14.22 is the independent home-carousel native-touch candidate, Build188 was real-device tested and requires detail-selection follow-up, and Build190 / 0.14.23 is the current independent detail follow-up candidate. Build189 and Build190 are real-device pending and neither replaces Build184.'
if old_summary in text:
    text = text.replace(old_summary, new_summary, 1)
index.write_text(text)

state = root / 'docs/project/PROJECT_STATE.md'
text = state.read_text()
old_updated = '_Last updated after Build187 real-device diagnostics confirmed that the home-carousel first useful SwiftUI drag samples already arrive at roughly 4–16pt, and Build189 / OnePlayer 0.14.22 completed dedicated Release CI/IPA as the valid native-touch carousel candidate. Build188 / OnePlayer 0.14.21 remains the independent detail/episode-selection navigation candidate. Build184 / OnePlayer 0.14.17 remains the accepted overall functional baseline on `main`; neither Build188 nor Build189 replaces it until target-device evidence is accepted._'
new_updated = '_Last updated after Build188 / OnePlayer 0.14.21 was real-device tested and exposed two detail-selection state gaps, and Build190 / OnePlayer 0.14.23 completed dedicated Release CI/IPA with those follow-ups. Build189 / OnePlayer 0.14.22 remains the independent home-carousel native-touch candidate. Build184 / OnePlayer 0.14.17 remains the accepted overall functional baseline on `main`; neither Build189 nor Build190 replaces it until target-device evidence is accepted._'
if old_updated in text:
    text = text.replace(old_updated, new_updated, 1)
old188p = 'Build188 / OnePlayer 0.14.21 is the current independent **detail/episode-selection navigation candidate**. Detail horizontal episode cards now select only and retain the blue selected outline; a compact 12 pt selected-episode summary appears above the horizontal cards, while the existing main Play/Resume button remains the playback action. Full picker episode playback no longer dismisses the picker or waits 100 ms before resolving playback; the visible picker presents the shared `model.selectedSource`, so closing player should return to the same picker instance/scroll position. Dedicated Release run `32864835934` passed, artifact `9569812832` was produced, and downloaded IPA SHA-256 `c82fcca99162f4840d8b0fccdb7c2f6203426d12901ef5d6ac4f4879db78b9ff` matched the artifact checksum. **Real-device evidence is pending; accepted baseline remains Build184.**'
new188p = 'Build188 / OnePlayer 0.14.21 established the independent **detail/episode-selection navigation candidate**: select-only horizontal cards, compact selected-episode summary and a full picker that no longer dismisses before playback. Dedicated Release CI/IPA succeeded. **Target-device follow-up is required:** normal Series entry left `selectedEpisodeID` empty instead of visibly selecting the resume/default episode, and quick 10-episode range buttons cleared the selected episode/title. Build188 is real-device tested but not accepted/stable.'
build190p = '\n\nBuild190 / OnePlayer 0.14.23 is the current independent **detail-selection follow-up candidate**. It preserves Build188 navigation/presentation ownership and changes only selection defaults: explicit `initialEpisodeID` wins, otherwise the existing resumable episode is selected, otherwise canonical `episodes.first`; quick range buttons now select the first episode in the target range rather than clearing state. Dedicated Release run `32870600458` passed, artifact `9572070999` was produced, and downloaded IPA SHA-256 `2f05197cebe43b6a50c2eb84225b7d134f364f82baf58772f86d10653f2f298c` matched the artifact checksum. iOS MinOS remains 15.0. **Real-device evidence is pending; accepted baseline remains Build184.**'
if old188p in text:
    text = text.replace(old188p, new188p + build190p, 1)
elif build190p.strip() not in text:
    raise SystemExit('PROJECT_STATE Build188 marker missing')
state.write_text(text)
