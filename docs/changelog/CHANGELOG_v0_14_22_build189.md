# OnePlayer 0.14.22 / Build189

- 首页轮播手动拖动改用 UIKit 原始 touch sampling 驱动交互 progress，直接针对 Build187 真机日志中 SwiftUI `DragGesture` 首次有效横向 translation 已跳到约 4–16pt 的证据。
- 新 native recognizer 从 `touchesMoved` 读取 coalesced touches，第一次约 0.5pt 的有效方向向量即可锁定横向/纵向。
- 横向拖动继续使用原 `abs(translation) / width` progress 与整页 foreground 横向平移；Logo、评分、年份、类型、剧情简介仍随所属轮播页移动。
- 保留原 SwiftUI `DragGesture` 与 `predictedEndTranslation`，继续负责既有 0.28 progress / 0.48×width predicted commit 判定和 cancel/complete 吸附逻辑。
- native recognizer 允许与纵向 ScrollView simultaneous recognition，并且不 cancel/delay touches，保护首页纵向滚动和点击详情。
- Build188 / 0.14.21 已被并行详情选集任务正式占用；carousel native-touch 候选顺延为唯一的 Build189 / 0.14.22 身份，冲突 Build188 carousel 包不得用于真机归因。
- 不修改 Player、MPV、PiP、Transport、Cache、Emby Session/Resume 或 115/302/Range 合同。
- Deployment Target 保持 iOS 15.0；目标真机 iPhone 15 Pro Max / iOS 17.0。
