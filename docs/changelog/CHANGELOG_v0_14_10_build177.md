# OnePlayer 0.14.10 Build177

- Targets the homepage V3 carousel manual-drag stutter shown in the 2026-08-25 OP vs EX real-device recordings.
- Moves high-frequency carousel transition progress/from/to/direction out of the root `V3EmbyHomeView` render state into one dedicated transition owner observed only by the Hero and persistent backdrop scopes.
- Keeps drag-only tap suppression and dragging flags out of root SwiftUI render state so every finger movement no longer invalidates the full homepage ScrollView, media rows, header and dock.
- Reduces `DragGesture` minimum distance from 12 pt to 4 pt, matching the existing horizontal-dominance guard and reducing the initial non-following dead zone.
- Keeps the existing commit/cancel thresholds, release animations, automatic carousel timing, persistent blurred backdrop visual design, detail tap behavior and vertical homepage scrolling semantics unchanged.
- PlayerController, MPV fast Seek, PiP Build173, UnifiedTransport, Range/302/115 client-direct playback, session cache, Emby progress/Resume and native navigation are unchanged.
- Deployment Target remains iOS 15.0; target real-device validation remains iPhone 15 Pro Max / iOS 17.0.
