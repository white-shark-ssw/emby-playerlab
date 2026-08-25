# OnePlayer 0.14.28 / Build195

## Player episode picker large-list performance

- Keeps Build194 SeasonId-first player grouping and the full canonical Emby episode array.
- Replaces the in-player episode row's eager `HStack` with `LazyHStack` so large seasons instantiate visible/near-visible cards and thumbnails on demand.
- Does not truncate, paginate or reorder large episode lists.
- PlayerController, MPV Seek, PiP, UnifiedTransport, Cache, STRM/302/115 client-direct playback, Emby Resume/progress and trusted-natural-end auto-next are unchanged.
- Deployment Target remains iOS 15.0.
