from pathlib import Path

checkpoint = Path('docs/project/current/dev/DEV-detail-episode-selection-navigation.md')
text = checkpoint.read_text()
text = text.replace('- **Current candidate**：**OnePlayer 0.14.23 / Build190**。', '- **Current candidate**：**OnePlayer 0.14.24 / Build191**。', 1)
text = text.replace('- **Artifact**：`OnePlayer-0.14.23-build190-detail-selection-defaults`。', '- **Target artifact**：`OnePlayer-0.14.24-build191-detail-summary-title`。', 1)
text = text.replace('3. “即将播放”区间行下方、横向卡片上方显示固定高度的 12 pt 当前选中集摘要：有真实标题时 `第 N 集 · 标题`，只有通用“第几集”名称时显示 `第 N 集`。', '3. “即将播放”区间行下方、横向卡片上方显示固定高度的 12 pt 当前选中集摘要；摘要必须直接复用下面横向卡片的 `displayEpisodeTitle(episode)`，与选中卡片标题逐字一致，不维护第二套格式。', 1)
old = '''最小后续修正应只扩展 `isGenericEpisodeName` 的 exact-match candidate，把 `第\\(chineseNumber(number))集` 也认作 generic。这样 `第十集 / 第二十集` 都只显示摘要 `第 10 集 / 第 20 集`；真正有剧情标题的 Episode（例如 `营救`）仍显示 `第 N 集 · 营救`。不需要修改排序、选择、播放或缓存 owner。

## Build identity collision history
'''
new = '''用户随后明确调整显示要求：**上方选中集摘要直接按照下面横向卡片的集名称显示，一模一样即可。** 因此此前“继续扩展 generic-name candidate”的方案被替代，不再增加另一层名称分类规则。

## Build191 implemented follow-up

- `selectedEpisodeSelectionSummary` 不再自行读取/拼接 `episode.name`，而是直接 `return displayEpisodeTitle(episode)`。
- 因此上方摘要与下面选中卡片共用同一个 formatter/owner；例如卡片显示 `10.第十集`，摘要也显示 `10.第十集`；真实标题亦完全按卡片现有结果展示。
- `check_detail_episode_selection_navigation.py` 增加合同：摘要必须调用 `displayEpisodeTitle(episode)`，且不得再包含旧 `第 N 集 · title` 的独立拼接路径。
- Build191 仅改变显示格式 owner；`selectedEpisodeID`、默认 Resume→first 选择、快速区间第一集选择、主 Play/Resume、完整 picker 返回、canonical episode order、Build182 detail cache/scroll、Player/Transport/Cache/PiP 均不变。
- 功能 commit：`6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`；窄 selection/navigation、range jump、Resume 静态合同已通过。Release CI / IPA / Build191 真机仍 pending。

## Build identity collision history
'''
if old not in text:
    raise SystemExit('checkpoint naming follow-up marker missing')
text = text.replace(old, new, 1)
text = text.replace('- 详情 follow-up 唯一有效身份是 **OnePlayer 0.14.23 / Build190**。', '- 详情 Build190 已实际分发并产生本次真机反馈，但并行首页任务随后也占用了 **0.14.23 / Build190**；为避免后续日志/包身份继续冲突，详情后续唯一候选顺延为 **OnePlayer 0.14.24 / Build191**。', 1)
old_evidence = '''- Build190：**Code written / CI passed / IPA produced / real-device partially validated / naming follow-up required / not stable**。
- Build190 quick-range retain-selection fix：**real-device positive evidence YES**。
- Build190 default-entry selection：**acceptance evidence not yet complete**。
- Build190 full-picker return：**acceptance evidence not yet complete**。
- Accepted overall baseline：仍为 **Build184 / 0.14.17**。'''
new_evidence = '''- Detail Build190：**Code written / CI passed / IPA produced / real-device partially validated / summary-format follow-up required / not stable**；该 artifact SHA 仍用于归因用户本次截图，但 0.14.23 / Build190 identity 后续与首页并行候选发生冲突，不再继续复用。
- Build190 quick-range retain-selection fix：**real-device positive evidence YES**。
- Build190 default-entry selection：**acceptance evidence not yet complete**。
- Build190 full-picker return：**acceptance evidence not yet complete**。
- Build191：**Code written / narrow static checks passed / Release CI pending / IPA pending / real-device pending / not stable**。
- Accepted overall baseline：仍为 **Build184 / 0.14.17**。'''
if old_evidence not in text:
    raise SystemExit('checkpoint evidence marker missing')
text = text.replace(old_evidence, new_evidence, 1)
old_next = '''1. 若继续修复当前摘要不一致，只改 `isGenericEpisodeName` 的中文数字 generic exact-match，并补静态合同；不碰 selection/playback/order/cache。
2. 新候选出包前重新检查并行 Build 编号占用，不能直接假定 Build191 可用。
3. 后续真机继续验证：有 Resume / 无 Resume 的默认蓝框选择、完整 picker 播放后原位返回，以及真实标题 Episode 是否仍按 `第 N 集 · 标题` 展示。'''
new_next = '''1. 跑 Build191 / 0.14.24 dedicated Xcode 16.4 Release CI/IPA；保持 iOS 15.0 和现有 frozen/P0 合同。
2. Build191 真机确认上方摘要与下方选中卡片标题逐字一致，同时继续验证有 Resume / 无 Resume 的默认蓝框选择与完整 picker 播放后原位返回。
3. 真机验收前不提升 accepted baseline。'''
if old_next not in text:
    raise SystemExit('checkpoint next marker missing')
text = text.replace(old_next, new_next, 1)
checkpoint.write_text(text)

module = Path('docs/project/MODULE_STATUS.md')
text = module.read_text()
old_row = '| Detail episode selection navigation | **Active Build190 candidate; real-device partial / follow-up required** | Build190 / 0.14.23 dedicated Release CI passed and IPA was produced. Target-device screenshots confirm quick range jumps now retain a selected episode/blue outline and the compact summary no longer disappears. A remaining presentation inconsistency is confirmed: Chinese-numeral generic Emby names such as `第十集` are not recognized by `isGenericEpisodeName`, so the summary can render `第 10 集 · 第十集` while another generic episode renders only `第 20 集`. Default-entry selection and full-picker return still require complete acceptance evidence. Build182 scroll/cache, Build176 player session replacement and Build178 canonical order remain unchanged. |'
new_row = '| Detail episode selection navigation | **Active Build191 candidate; Build190 real-device partial / follow-up required** | Detail Build190 target-device screenshots confirm quick range jumps retain selection/blue outline and summary state, but exposed summary/card title mismatch. User now requires the summary to be exactly identical to the selected horizontal card title. Build191 / 0.14.24 removes the second summary formatter and directly reuses `displayEpisodeTitle(episode)`; code + narrow contracts passed, Release CI/IPA pending. Default-entry selection and full-picker return still require complete acceptance evidence. Build182 scroll/cache, Build176 player session replacement and Build178 canonical order remain unchanged. |'
if old_row not in text:
    raise SystemExit('MODULE_STATUS detail row missing')
text = text.replace(old_row, new_row, 1)
old_other = '| Other product modules | Active parallel work | Build184 / 0.14.17 is the accepted overall runtime baseline on `main`. Build190 / 0.14.23 carousel release-owner candidate and Build188 / 0.14.21 detail episode-selection are independent real-device-pending lines; neither replaces Build184 until accepted. |'
new_other = '| Other product modules | Active parallel work | Build184 / 0.14.17 is the accepted overall runtime baseline on `main`. Build190 / 0.14.23 is the current home-carousel release-owner candidate; Build191 / 0.14.24 is reserved for the independent detail episode-selection follow-up. Neither replaces Build184 until accepted. |'
if old_other in text:
    text = text.replace(old_other, new_other, 1)
module.write_text(text)
