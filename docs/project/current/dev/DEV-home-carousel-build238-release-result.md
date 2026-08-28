# Build238 release-intent target-device result

Parent work: `DEV-home-carousel-drag-smoothness`.

## 2026-08-29 target-device evidence

User supplied `OnePlayer-App-1787946638.log` from OnePlayer 0.14.71 / Build238 on iPhone 15 Pro Max / iOS 17.0 after performing the requested quick-flick family followed by short slow drags.

The log contains 28 `HomeCarouselRelease` samples. The first 19 quick flicks and final 9 short slow drags separate very strongly on `last_move_delivered_velocity_x`:

- quick flicks: absolute delivered velocity approximately **1139.8–2239.8 pt/s**;
- short slow drags: absolute delivered velocity approximately **0–160 pt/s**;
- therefore the observed target-device families have a wide empty interval from about **160 to 1140 pt/s**.

`last_move_coalesced_velocity_x` shows the same separation: quick flicks are approximately 1199.6–2319.8 pt/s in magnitude, while slow drags are 0–80 pt/s.

`end_velocity_x` is not a suitable sole signal: many quick flicks report about 400–480 pt/s at touch end, while slow releases include values up to about 480 pt/s. The end sample is therefore already decelerated/quantized enough to overlap.

`predicted_extra_x` is also not reliable as the sole fling signal. Many quick flicks have no predicted endpoint at release, and the available quick-flick extra prediction is only about 6–13.3 pt despite clearly high delivered velocity. This directly explains why predicted-total-distance gating feels like a hard distance wall.

## Controlling conclusion

Build238 validates the user's EX comparison: the missing semantic is **release/flick velocity intent**, not another smaller page-width distance fraction. Keep the accepted Build237 persistent source-over white-flash correction and the ordinary 0.28 slow-drag progress commit. The next candidate should replace the legacy predicted-total-distance fling gate with a direction-aware gate based on the latest delivered move velocity. Do not use `end_velocity_x` alone and do not continue lowering width fractions.

A velocity threshold may be selected only inside the measured empty interval; it should not be presented as an EX-internal constant. The exact threshold remains a OnePlayer tuning choice to validate on target device.

Evidence: Build238 Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic tested ✅ / velocity-intent hypothesis strongly supported ✅ / Build238 behavior itself unchanged / stable ❌.
