# OnePlayer 0.14.24 / Build191

- 修复 Build189 真机暴露的“手指松开后轮播停在中间 progress、不再完整切换/回弹”。
- Build189 native recognizer 横向时进入 `.began/.changed`，但 settle 仍只由 SwiftUI `DragGesture.onEnded` 负责；真机证明两者竞争后 release owner 可能收不到结束。
- Build191 将 native recognizer 改为被动 raw/coalesced-touch sampler：横向采样时保持 `.possible`，不 claim 手势，并明确不 prevent / 不被其他 recognizer prevent；纵向仍立即 fail 让首页 ScrollView 继续主导。
- SwiftUI `DragGesture` 删除逐帧 `onChanged` 状态写入，只保留原 `onEnded`、`predictedEndTranslation`、0.28 progress / 0.48×width predicted commit 和原 complete/cancel settle。
- 因此移动 progress 只有 native 一个 owner，松手 settle 只有 SwiftUI 一个 owner；不引入 fallback、timer、watchdog、debounce、throttle 或插值。
- 保留整页 foreground 横向平移、左右反向穿越中心、自动轮播、详情点击和 persistent backdrop 视觉合同。
- Player、MPV、PiP、Transport、Cache、Emby Session/Resume、115/302/Range 均不修改；Deployment Target 保持 iOS 15.0。
- 0.14.23 / Build190 已被并行详情选集任务正式占用，carousel 对应身份作废；本轮播候选唯一有效身份为 0.14.24 / Build191。
