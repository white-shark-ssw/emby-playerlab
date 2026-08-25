# OnePlayer 0.14.24 / Build191

## Selected episode summary display unification

- Build190 real-device screenshots confirmed the selected-episode state/range behavior works, but the compact summary could differ from the episode card title because it maintained a separate formatting path.
- The compact selected-episode summary now directly reuses `displayEpisodeTitle(episode)`, the exact formatter already used by the horizontal episode card.
- Therefore the summary and selected card title are intentionally identical for every episode, including Emby generic names such as `10.第十集` / `20.第二十集` and real episode titles.
- No selection state, playback action, canonical ordering, full-picker return path, Player/Transport/Cache/PiP, detail performance cache or iOS deployment behavior is changed.

Evidence at changelog creation: code written; CI/IPA/real-device follow-up pending.
