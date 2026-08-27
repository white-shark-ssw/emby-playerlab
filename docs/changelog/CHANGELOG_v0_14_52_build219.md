# OnePlayer 0.14.52 / Build219

- AetherEngine 6.50.0 manual comparison candidate.
- MPV remains the default/automatic playback authority.
- Aether consumes the existing UnifiedTransport byte session through exact IOReader offsets; no time-to-byte approximation is introduced.
- STRM -> 302 -> 115/CDN remains client-direct and NAS does not relay media bytes.
- Candidate deployment target is iOS 16.0 because AetherEngine itself requires iOS 16.
- MDK is not modified in this candidate.
