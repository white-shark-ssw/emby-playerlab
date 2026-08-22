# MDK Fast Seek InCache A/B

Baseline: Build123 strict Seek trace.

Purpose: isolate whether MDK v0.38.0 `SeekFlag::InCache` reduces native Fast Seek latency for already-cached relative +/- seeks.

Frozen variables:
- UnifiedTransport implementation and cache policy
- no predictive preload
- no predecode
- AVIO request size 2 MiB
- relative seek temporary buffer min 50 ms
- absolute seek temporary buffer min 200 ms
- normal buffer min 1000 ms
- single-flight latest-wins scheduling
- Health Coordinator and UI contracts

Only experimental variable: relative Fast Seek flag composition. Absolute Accurate seek remains unchanged.

Acceptance analysis: compare input->first-correct-frame and native-start->callback P50/P90/P95/P99 for full-cache relative seeks; also inspect continuous-seek audio behavior and any new -2/failed seek results.
