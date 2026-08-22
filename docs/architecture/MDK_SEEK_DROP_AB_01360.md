# Build127 MDK decoder drop A/B

Build127 is a true-device diagnostic/performance A/B based on Build126.

## Proven before this experiment

- Build124 `FromStart|KeyFrame|InCache` (1282) was fast but often rendered a pre-target keyframe and then visually caught up at roughly 2–4x.
- Build125 `FromStart|InCache` (1026) landed accurately but was too slow even with UnifiedTransport 100% cache-hit.
- Build126 native logs proved Accurate seek flushes decoders and drops output until the seek target; audio commonly becomes renderable well before video completes accurate decode-to-target.
- MDK 0.37+ documents decoder `drop=auto` as the default and specifically states that auto drops non-reference frames when seeking. Therefore an explicit `drop=nonref` A/B would not be a meaningful next variable.

## Build127 variable

Only relative forward/backward 1026 native seeks temporarily use:

`video.decoder = drop=bidir`

The policy is restored to:

`video.decoder = drop=auto`

as soon as the current native seek callback is accepted. Absolute seek never changes decoder drop policy. Audio decoder policy is untouched.

## Frozen behavior

- relative seek flag: `FromStart|InCache` = 1026
- absolute seek flag: `FromStart` = 2
- relative buffer minimum: 50 ms
- absolute buffer minimum: 200 ms
- normal buffer minimum: 1000 ms
- AVIO request size: 2 MiB
- single-flight latest-wins
- UnifiedTransport/cache policy
- Health Coordinator ownership
- no preload/predecode
- MDK `All` decoder trace logging retained from Build126 so Build126 vs Build127 is a same-observation-cost A/B

## Acceptance

A useful result requires all of the following:

1. native and input-to-first-correct-frame latency materially lower than Build126;
2. first rendered frame remains close to target;
3. no Build124-style post-seek visual catch-up burst;
4. no decoder corruption or VideoToolbox instability;
5. early audio recovery remains intact.

If `bidir` is promising, a later Info-log build must confirm real performance without diagnostic logging overhead before it can become a candidate baseline.
