# OnePlayer 0.14.22 / Build189

## Detail default episode selection follow-up

- Real-device Build188 feedback showed two selection-state gaps: entering a series did not visibly select the resume/default episode, and tapping a quick 10-episode jump cleared the selected episode/title.
- Series detail entry now selects the existing resumable episode when Emby exposes a nonzero playback position; if no resumable episode exists, it selects the canonical first episode. Explicit `initialEpisodeID` still has highest priority.
- The selected default episode also becomes the existing horizontal scroll target, so its blue outline/title are visible on entry.
- Tapping a quick episode-range button now selects the first episode in that range instead of clearing `selectedEpisodeID`; the blue outline, compact selected-episode title and main Play/Resume target remain coherent.
- No Player/Transport/Cache/PiP, canonical episode ordering, detail performance cache, or iOS deployment behavior is changed.

Evidence at changelog creation: code written only; CI/IPA/real-device follow-up pending.
