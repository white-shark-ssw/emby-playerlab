from pathlib import Path
import re

# App identity
p = Path('Sources/Core/AppIdentity.swift')
text = p.read_text()
if text.count('0.14.69') != 2: raise SystemExit('unexpected AppIdentity 0.14.69 count')
text = text.replace('0.14.69', '0.14.70')
p.write_text(text)

# Release predicted-distance gate only. Keep actual-progress threshold 0.28 unchanged.
p = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift')
text = p.read_text()
old = 'let shouldCommit = actualProgress >= 0.28 || max(actualDistance, predictedDistance) >= width * 0.48'
new = 'let shouldCommit = actualProgress >= 0.28 || max(actualDistance, predictedDistance) >= width * 0.24'
if text.count(old) != 1: raise SystemExit('release gate anchor mismatch')
text = text.replace(old, new, 1)
p.write_text(text)

# Persistent backdrop: keep outgoing fully covering systemBackground and fade incoming over it.
p = Path('Sources/UI/EmbyHomeHeroV3.swift')
text = p.read_text()
old = '''            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }
            if let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }
'''
new = '''            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size)
            }
            if let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(Double(carouselBackdropBlendProgress(transitionProgress)))
            }
'''
if text.count(old) != 1: raise SystemExit('persistent crossfade anchor mismatch')
text = text.replace(old, new, 1)
p.write_text(text)

# Changelog
Path('docs/changelog/CHANGELOG_v0_14_70_build237.md').write_text('''# OnePlayer 0.14.70 / Build237\n\n- Retains the Build236 carousel start-step, Build231 foreground compositing, Build226 Hero residency and Build228 release-tail contracts.\n- Lowers only the predicted-distance fling commit gate from `0.48 × width` to `0.24 × width`; the ordinary actual-progress commit threshold stays `0.28`.\n- Fixes the persistent-backdrop source-over crossfade so the outgoing image stays fully covering the system background while the incoming image fades over it, preventing the mid-transition light-background leak/white flash caused by two complementary semi-transparent image layers.\n- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range path changes.\n''')

# Feature checkpoint: allocate Build237 early and record exact scope.
p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
text = p.read_text()
text = re.sub(r'^\*\*Active — Build236 / 0\.14\.69 target-device testing.*?\*\*$', '**Active — Build236 is now the retained carousel control foundation after target-device testing materially reduced coarse starts and made title jitter very slight. User explicitly accepts freezing most of that work rather than over-optimizing the residual 4/53 double-no-predecessor starts. Build237 / 0.14.70 is the next narrow target-device A/B: retain Build236/231/226/228 behavior, halve only the predicted-distance fling gate from 0.48×width to 0.24×width while keeping actual-progress threshold 0.28, and correct the persistent backdrop source-over crossfade so the outgoing image remains fully opaque while incoming fades over it, preventing systemBackground leakage/white flash. CI/IPA pending; whole carousel not yet stable until this A/B is tested.**', text, count=1, flags=re.M)
text = text.replace('- Working branch: `perf/home-carousel-post-acquisition-baseline-build236`', '- Working branch: `perf/home-carousel-fling-whiteflash-build237`', 1)
text = text.replace('- Current candidate: OnePlayer `0.14.69 (236)`', '- Current candidate: OnePlayer `0.14.70 (237)`', 1)
section = '''\n## Build237 / 0.14.70 — shorter fling gate + persistent white-flash correction\n\nUser accepts freezing most Build236 carousel refinement rather than chasing the residual 4/53 double-no-predecessor starts. A new comparison against EX exposes two remaining release/presentation details: EX can commit after a much shorter drag followed by a fling, while OnePlayer's predicted-distance gate is still `0.48 × width`; and OnePlayer shows a brief bright/white flash during carousel switching.\n\nExact source evidence for the flash: `persistentCarouselBackdrop` places two opaque images above a `systemBackground` root but applies complementary opacities (`1-blend` and `blend`) to the two separate source-over layers. At midpoint, two 0.5-opacity opaque layers cover only 75% in source-over composition, so the underlying light system background can leak through. The existing light/dark scrim and system-background gradient predate Build236 and are not removed. Build237 keeps the outgoing persistent image fully opaque and fades only the incoming persistent image from 0→1 using the unchanged backdrop blend progress, which yields the intended visual color interpolation without exposing the root background.\n\nThe release change is equally narrow: only the predicted-distance gate becomes `0.24 × width`; actual-progress commit remains `0.28`. No velocity owner, timer, interpolation, extra easing or synthetic fling logic is added. Build236 start-step handling, Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 max-refresh-through-settle and all P0/Frozen paths remain unchanged.\n\nEvidence at this checkpoint: code patch prepared on `perf/home-carousel-fling-whiteflash-build237`; CI/IPA pending; target-device pending; stable ❌.\n'''
if '## Build237 / 0.14.70 — shorter fling gate + persistent white-flash correction' not in text:
    anchor = '\n## Rejected directions not to repeat'
    if anchor not in text: raise SystemExit('checkpoint insertion anchor missing')
    text = text.replace(anchor, section + anchor, 1)
next_action = '''## Next exact action\n\nBuild and independently verify OnePlayer 0.14.70 / Build237 from `perf/home-carousel-fling-whiteflash-build237`. Target-device A/B should test: (1) a short drag plus fling now commits naturally at roughly half the old predicted-distance requirement without making ordinary slow drags too eager; (2) the mid-transition white/light flash is gone in the same carousel items where it was visible; (3) Build236 first-step fineness, Build231 title stability and Build228 release-tail feel remain unchanged. Do not reopen the residual 4/53 Build236 start-step family unless new regression evidence appears.\n'''
if '## Next exact action' in text:
    text = text[:text.index('## Next exact action')] + next_action
else:
    text += '\n' + next_action
p.write_text(text)
