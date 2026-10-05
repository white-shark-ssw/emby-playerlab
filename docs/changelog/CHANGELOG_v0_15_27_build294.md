# OnePlayer0.15.27 / Build294 — Independent server Dock

Dock presentation and viewport layout now live in `ServerDock.swift`. Server-root retains tab selection, Search model lifetime and Home repeat-tap actions. Page roots declare Dock visibility through one shared host; fixed viewport geometry keeps oversized Home backgrounds from changing the Dock alignment rectangle. The same host owns bottom-safe-area placement and ignores keyboard resizing. All server pages use shared content clearance derived from bar height, the root's physical bottom inset and the12pt content gap.

The old AnyView Dock parameter chain, Search-only root overlay and unused visibility controller are removed. Detail's existing fully-immersive preference selects Dock visibility through the shared host; UIKit still owns push/pop. The accepted40pt bar, icon/title offset, selection and material appearance remain. Settings subpages that do not request Dock retain their existing absence of Dock.

Baseline: current main119ab10eee869488b97415746a0243f51953eba0, with product bytes identical to accepted Build293 fa8ff44ff4a5384fd4603a64b33354f941764a8c. Carousel native/runtime/input, image caching, browsing models, playback/MPV/PiP/Transport/Cache/Emby sessions and iOS15 deployment remain unchanged.

Validation planned: source/scope guard; native fixed-viewport, accepted Home geometry, page-style, visibility, keyboard and extracted-root action regressions; retained nine Build293 native carousel tests; exact-source Release build; independent IPA/version/Build/MinOS verification. Code written is not device acceptance. Target-device tests must cover Home carousel on/off, four tabs, keyboard, nested browsing, detail fully-immersive on/off, native push/pop and interactive edge-back.
