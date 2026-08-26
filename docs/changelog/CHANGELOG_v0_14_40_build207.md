# OnePlayer 0.14.40 / Build207

- Home carousel keeps the Build198 single UIKit gesture owner and the Build205 80% foreground travel.
- Replaces whole-range `progress²` visual mapping with a soft-start-only curve: `progress * (1 - 0.60 * (1-progress)^6)`.
- Initial displacement is less restrained than Build205; mid/late drag converges to raw linear progress and ends with slope 1.0 instead of continued tail acceleration.
- Foreground/backdrop opacity and foreground horizontal offset use the same visual curve.
- Left/right and first↔last wrapping, release/commit thresholds, settle behavior and all playback/transport/cache paths are unchanged.
