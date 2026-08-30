#!/usr/bin/env python3
from pathlib import Path

core = Path('Sources/UI/EmbyHomeCoreV3.swift').read_text(encoding='utf-8')
carousel = Path('Sources/UI/EmbyHomeCarouselStateV3.swift').read_text(encoding='utf-8')
scroll_state = Path('Sources/UI/EmbyHomeHeroScrollStateV3.swift').read_text(encoding='utf-8')
scroll_observer = Path('Sources/UI/EmbyHomeScrollOffsetObserverV3.swift').read_text(encoding='utf-8')
project = Path('project.yml').read_text(encoding='utf-8')

required = [
    (scroll_state, 'private weak var verticalScrollView: UIScrollView?'),
    (scroll_state, 'func attachVerticalScrollView(_ scrollView: UIScrollView?) { verticalScrollView = scrollView }'),
    (scroll_state, 'return verticalScrollView.isDragging || verticalScrollView.isDecelerating'),
    (scroll_observer, 'let onScrollViewChange: (UIScrollView?) -> Void'),
    (scroll_observer, 'onScrollViewChange(scrollView)'),
    (scroll_observer, 'onScrollViewChange(nil)'),
    (core, 'V3HomeScrollOffsetObserver(onScrollViewChange: { scrollView in heroScrollState.attachVerticalScrollView(scrollView) })'),
    (carousel, 'guard !heroScrollState.isVerticalMotionActive else { return }'),
    (project, 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"'),
]
for source, needle in required:
    if needle not in source:
        raise SystemExit(f'missing Home inertia-gate contract: {needle}')

if carousel.count('guard !heroScrollState.isVerticalMotionActive else { return }') != 1:
    raise SystemExit('Home vertical-motion auto-advance gate must exist exactly once')
if 'Timer.publish' in scroll_state or 'Timer.publish' in scroll_observer:
    raise SystemExit('Home vertical-motion ownership must not add a timer')
if 'DispatchQueue.main.asyncAfter' in scroll_state or 'DispatchQueue.main.asyncAfter' in scroll_observer:
    raise SystemExit('Home vertical-motion ownership must not add delayed state repair')
if 'isHomeVerticallyScrolling' in core + carousel + scroll_state + scroll_observer:
    raise SystemExit('duplicate Home vertical-motion boolean state is forbidden')

print('Home inertia auto-advance contract: PASS')
