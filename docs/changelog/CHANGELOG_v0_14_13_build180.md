# OnePlayer 0.14.13 Build180

- Follows the failed Build179 real-device carousel test on iPhone 15 Pro Max / iOS 17.0.
- Removes the remaining manual-drag start dead zone by receiving `DragGesture` movement from 0 pt instead of waiting for a minimum accumulated translation.
- Uses the horizontal-dominance check only to acquire the initial carousel drag; once horizontal dragging is active, movement continues through the center point and direction reversal without re-entering a dead zone.
- Removes the manual carousel artwork blend's delayed first 8% progress so small finger movement produces immediate visual progress instead of an apparent stationary interval followed by a larger jump.
- Keeps the Build179 localized carousel transition owner, existing commit/cancel thresholds, release animations, automatic carousel timing, persistent blurred backdrop design, detail tap behavior and vertical homepage scrolling architecture.
- Build176 player episode-selection/session behavior, Build178 Emby canonical episode ordering, PlayerController, MPV fast Seek, PiP, UnifiedTransport, Range/302/115 client-direct playback, cache and Emby Resume/progress remain unchanged.
- Deployment Target remains iOS 15.0; target real-device validation remains iPhone 15 Pro Max / iOS 17.0.
