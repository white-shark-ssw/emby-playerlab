# OnePlayer 0.15.38 / Build305 — Library media-only root correction

Build304 target-device evidence refined `DEV-meaningless-detail-routing`: item `180310` is still a `Folder`, and Build304 correctly opens its two child videos instead of the empty media-detail shell. The unwanted root card therefore comes from the Library `.items` query itself, not from detail rendering.

The Build304 log shows the live root request for library `145113` omitted `IncludeItemTypes`, then republished the same 60 cards; tapping the problematic card issued `ParentId=180310&Recursive=false` and returned exactly two child videos. Build305 keeps the existing Folder browser for the dedicated folder path, but changes only the unknown/nil Library collection-type fallback from unrestricted items to `Movie,Series,Video`, matching the existing mixed-library media scope. With the existing recursive root query, Folder cards no longer belong to the normal content tab while media inside those folders remains discoverable.

No Player, Transport, Cache, Emby Session, detail implementation, poster geometry, native navigation ownership or deployment target change. iOS 15.0 remains the minimum.

Evidence at creation: **Build304 target-device rejected for the original UX goal; Build305 code written; CI/IPA/Build305 target-device validation pending.**
