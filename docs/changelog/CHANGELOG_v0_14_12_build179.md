# OnePlayer 0.14.12 Build179

- Ports the homepage V3 carousel manual-drag smoothness work onto the current real-device accepted Build178 / OnePlayer 0.14.11 baseline so the test package does not regress accepted episode-selection or canonical episode-ordering behavior.
- Moves high-frequency carousel transition progress/from/to/direction out of the root `V3EmbyHomeView` render state into one dedicated transition owner observed only by the Hero and persistent backdrop scopes.
- Keeps drag-only tap suppression and dragging flags out of root SwiftUI render state so every finger movement no longer invalidates the full homepage ScrollView, media rows, header and dock.
- Reduces `DragGesture` minimum distance from 12 pt to 4 pt, matching the existing horizontal-dominance guard and reducing the initial non-following dead zone.
- Keeps the existing commit/cancel thresholds, release animations, automatic carousel timing, persistent blurred backdrop visual design, detail tap behavior and vertical homepage scrolling semantics unchanged.
- Inherits Build176 player episode-selection/session behavior and Build178 canonical Emby episode ordering unchanged; PlayerController, MPV fast Seek, PiP Build173 architecture, UnifiedTransport, Range/302/115 client-direct playback, session cache, Emby progress/Resume and native navigation are unchanged.
- Deployment Target remains iOS 15.0; target real-device validation remains iPhone 15 Pro Max / iOS 17.0.
