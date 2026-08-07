# Changelog 0.9.1 (Build 47)

## Seek latency
- Automatic native-friendly playback now uses AVAssetResourceLoader with the shared UnifiedMediaTransportSession.
- Local TransportHTTPServer remains available only as a diagnostic engine.
- Cached real post-Seek demand now reanchors the unified playback anchor before the cache-hit early return.

## MPV video output
- Replaced unavailable `vo=avfoundation` with a CAMetalLayer-backed `gpu-next` renderer.
- Configured Vulkan/MoltenVK rendering and VideoToolbox hardware decode.
- Removed AVSampleBufferDisplayLayer-specific composite OSD options.

## Buffer timeline
- Increased track/history/live-buffer contrast and thickness.
- Added `[BufferHistory]` monotonic-history diagnostics.

## Compatibility
- Deployment Target remains iOS 15.0.
- Target real device remains iPhone 15 Pro Max / iOS 17.0.
