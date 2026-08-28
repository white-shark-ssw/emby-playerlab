# OnePlayer 0.14.57 / Build224

Diagnostic Home-carousel vertical smoothness A/B.

- Base: current accepted Build216/main product behavior with the normal full-screen persistent backdrop and Dock presentation restored.
- Only runtime presentation change: `immersiveCarouselHero` no longer mounts the current/target `carouselHeroArtwork` 1400px clear-image layers.
- `carouselHeroArtwork` implementation remains in source; this is a mount isolation, not a redesign or deletion.
- Persistent backdrop, carousel preload, foreground/logo/text, page indicators, auto-advance, horizontal carousel interaction and all Player/MPV/PiP/Transport/Cache/Emby Session contracts remain unchanged.
- Evidence at creation: Code written + exact diff scope reviewed. CI/IPA/real-device pending.
