from pathlib import Path
import re
import subprocess

hero = Path("Sources/UI/EmbyHomeHeroV3.swift")
text = hero.read_text()
old = '''            if let item = currentCarouselItem {
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
            if let item = transitionTargetCarouselItem {
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
'''
new = '''            if let item = currentCarouselItem {
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(isCarouselDragging ? 1 : carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
            if !isCarouselDragging, let item = transitionTargetCarouselItem {
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
'''
if old not in text:
    raise SystemExit("Build225 expected Hero mount block not found")
hero.write_text(text.replace(old, new, 1))

checkpoint = Path("docs/project/current/dev/DEV-home-carousel-drag-smoothness.md")
current = subprocess.check_output(["git", "show", "origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md"], text=True)
current = re.sub(
    r"^\*\*Active —.*?\*\*$",
    "**Active — Build225 / 0.14.58 is the current horizontal carousel Hero-presentation A/B. It branches from the exact Build219 tested 120Hz carousel source, restores normal persistent current/target presentation, and changes only drag-time Hero mounting: the already-mounted current Hero stays opaque while the target Hero clear 1400px artwork is not mounted until horizontal drag ends. Foreground page travel, acquisition-relative motion, release gates, preload, normal persistent crossfade, device-max refresh request and all P0/Frozen paths remain unchanged. Code written; CI/IPA pending; target-device horizontal test pending. Build221 is real-device rejected as final because overall feel still trails EX and its frozen-persistent strategy introduces a pale/white transition regression.**",
    current,
    count=1,
    flags=re.M,
)
section = '''## Build225 / 0.14.58 — horizontal target-Hero presentation isolation

- branch: `diag/home-carousel-hero-drag-isolation-build225`
- exact base: Build219 tested source `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`
- identity: OnePlayer `0.14.58`, Build `225`
- Build225 does **not** inherit Build221's persistent freeze; persistent current/target crossfade is the normal Build219 behavior.
- During active horizontal drag only, the already-mounted current `carouselHeroArtwork` stays opacity 1 and `transitionTargetCarouselItem` Hero artwork is not mounted. When drag ends, normal Hero target mounting/crossfade resumes for release/settle.
- `carouselHeroArtwork` implementation, image loader, 1400px request, mask/scrim, preload, foreground page motion, acquisition-relative input, 0.28/0.48 release rules and Build219 exact device-max refresh request are unchanged.
- No Player / MPV / PiP / Transport / Cache / Emby Session / P0/Frozen source changes.

Why this variable: Build219's residual gaps correlated with both Hero and persistent callbacks. Build221 directly tested the persistent-side drag isolation and did not close the EX hand-feel gap, while also creating a visual mismatch. The remaining direct horizontal suspect is target Hero first presentation. Suppressing only the target Hero mount during active drag avoids unmounting the already-visible current Hero at touch acquisition and isolates newly presented Hero work without changing gesture ownership or motion math.

Evidence: Code written ✅ / exact source scope review pending CI checker / CI pending / IPA pending / real-device pending / stable ❌.

'''
marker = "## Rejected directions not to repeat\n"
if "## Build225 / 0.14.58 — horizontal target-Hero presentation isolation" not in current:
    current = current.replace(marker, section + marker, 1)
next_start = current.index("## Next exact action")
current = current[:next_start] + '''## Next exact action

Run the dedicated Build225 Xcode 16.4 CI/IPA and independently verify package identity/MinOS/source scope. If CI/IPA succeeds, test only horizontal carousel interaction on iPhone 15 Pro Max / iOS 17.0. Compare sustained tracking and the “smooth glass vs rough paper” gap against Build221/EX; also note visual continuity during drag and release/settle separately. Do not use Home vertical inertial scrolling as the acceptance gate.
'''
checkpoint.write_text(current)
