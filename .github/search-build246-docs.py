from pathlib import Path
import sys

mode = sys.argv[1]
checkpoint = Path('docs/project/current/dev/DEV-search-page-optimization.md')

if mode == 'branch':
    text = checkpoint.read_text()
    text = text.replace('Status: Active — Build245 target-device rejected as final; Build246 follow-up code written / CI in progress', 'Status: Active — Build245 target-device rejected as final; Build246 CI/IPA verified and ready for target-device test')
    text = text.replace('- Build246 dedicated Xcode 16.4 Release/MPV packaging: **in progress**, run `33255278229`.', '- Build246 CI passed: **yes**, run/job `33255278229 / 99107775908`.\n- Build246 IPA produced + independently verified: **yes**, artifact `9715650501`, IPA SHA-256 `184082a21d850e7203c1be717e27d7fb95301caa5a36de6b814e4930b30750b9`, source ZIP SHA-256 `8cc7e4799e077e47d04c8a3c1d3c1d3a38fde2a3724ca268957d22a112a896c0`, MinOS 15.0.')
    text = text.replace('## Next exact action\n\nFinish Build246 Release/IPA CI. If successful, independently verify the artifact identity/checksums/MinOS, remove temporary Build246 packaging files, synchronize `PROJECT_STATE.md`, `MODULE_STATUS.md`, `BUILD_TEST_INDEX.md` and PR #264, then hand the IPA to the user for target-device validation. Do not describe Build246 as fixing the device issue until that test is reported.', '## Build246 CI / IPA evidence — 2026-08-29\n\n- Exact tested source: **`748d6f31bf724d4f1ec7dab4765d25c9b6a195ac`**.\n- Xcode 16.4 Release/MPV run/job: **`33255278229 / 99107775908` — success**.\n- Artifact: **`OnePlayer-0.14.79-Build246-Search`**, ID **`9715650501`**, artifact digest **`sha256:39bb802573962dca207aa0af02c2974aa73082aaa10dfe049ba39c952bc5c7b3`**.\n- IPA SHA-256: **`184082a21d850e7203c1be717e27d7fb95301caa5a36de6b814e4930b30750b9`**.\n- Source ZIP SHA-256: **`8cc7e4799e077e47d04c8a3c1d3c1d3a38fde2a3724ca268957d22a112a896c0`**.\n- Independent artifact download reproduced both embedded SHA-256 values; IPA `unzip -t` passed.\n- Packaged identity independently confirmed: `com.embyplayerlab.app`, OnePlayer `0.14.79 (246)`, `MinimumOSVersion=15.0`.\n- Evidence: **Code written ✅ / syntax parse ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending / not stable.**\n\n## Next exact action\n\nHand **OnePlayer 0.14.79 / Build246** to the user for iPhone 15 Pro Max / iOS 17.0 validation of: container stability, +15% gear sizing, time-to-first Search poster wall, Movie/Series-only recommendations, and already-seen recommendation-poster retention. Do not describe Build246 as fixed/stable until that target-device test is reported.')
    checkpoint.write_text(text)
elif mode == 'main':
    module = Path('docs/project/MODULE_STATUS.md')
    text = module.read_text()
    old_start = '| Search page / multi-Emby search | **Active — Build244 target-device rejected as final; Build245 CI/IPA verified, target-device pending** |'
    for line in text.splitlines():
        if line.startswith(old_start):
            new = '| Search page / multi-Emby search | **Active — Build245 target-device rejected as final; Build246 CI/IPA verified, target-device pending** | Build245 / 0.14.78 was tested on iPhone 15 Pro Max / iOS 17.0 and rejected as final: recording shows recommendation/container twitch, gear should be +15%, Search first-poster latency trails the same-server Library/competitor path, recommendations must be Movie+Series only, and seen recommendation posters visibly fall back to placeholders after lazy-cell recycling. Build246 / 0.14.79 exact source `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac` adds a Search-specific lean 18-item poster query, Movie/Series Suggestions whitelist, append-only recommendation expansion without incremental layout spinner, and Search-lifetime decoded poster pins on top of the existing persistent `EmbyImageDiskCache`; gear becomes 18.6pt/30pt frame. Run/job `33255278229 / 99107775908` passed; artifact `9715650501`; IPA SHA-256 `184082a21d850e7203c1be717e27d7fb95301caa5a36de6b814e4930b30750b9`; MinOS 15.0. Build246 is not real-device tested or stable yet. |'
            text = text.replace(line, new)
            break
    else:
        raise SystemExit('Search module status line not found')
    text = text.replace('Search Build245, poster and Aether remain separate Active tasks with independent checkpoints/branches.', 'Search Build246, poster and Aether remain separate Active tasks with independent checkpoints/branches.')
    module.write_text(text)

    state = Path('docs/project/PROJECT_STATE.md')
    text = state.read_text().rstrip()
    marker = '## Active: Search page / multi-Emby Search — Build246'
    if marker not in text:
        text += '''\n\n## Active: Search page / multi-Emby Search — Build246\n\nBuild245 / 0.14.78 is now target-device tested and rejected as final. The supplied recording shows Search/recommendation container twitch; the user requests the Build245 gear be enlarged 15%, Search time-to-first poster wall be brought closer to the same-server Library/competitor behavior, recommendations be whitelisted to Movie+Series, and already-seen recommendation posters avoid placeholder reload when lazy cells are recreated.\n\nSource inspection identified two direct Search-specific costs/triggers rather than a server-wide problem: Build245 direct full-grid Search waited for 60 results using heavyweight `commonBrowseFields`, while the accepted Library route can also restore persisted presentation snapshots; and recommendation load-more replaced the entire visible prefix plus inserted/removed a bottom ProgressView. The shared image path already persists bytes in `EmbyImageDiskCache`, so a second disk cache is not justified.\n\nBuild246 / 0.14.79 exact source `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac` adds a Search-only lean poster query with 18-item pages, retains existing search sorting/type semantics, applies an Emby Suggestions `Movie,Series` whitelist, appends only newly returned recommendation IDs, removes the incremental layout spinner, and pins decoded recommendation posters for the Search view-model lifetime while leaving the existing persistent disk cache authoritative. Gear is 18.6pt in a 30pt frame (+~15% from Build245). No shared poster-grid owner or P0/Frozen playback/transport/cache path is changed.\n\nDedicated Xcode 16.4 run/job `33255278229 / 99107775908` succeeded; artifact `OnePlayer-0.14.79-Build246-Search` ID `9715650501`, digest `sha256:39bb802573962dca207aa0af02c2974aa73082aaa10dfe049ba39c952bc5c7b3`; IPA SHA-256 `184082a21d850e7203c1be717e27d7fb95301caa5a36de6b814e4930b30750b9`; source ZIP SHA-256 `8cc7e4799e077e47d04c8a3c1d3c1d3a38fde2a3724ca268957d22a112a896c0`; packaged MinOS 15.0. Evidence: **Code written / CI passed / IPA produced+verified / target-device pending / not stable**.\n'''
    state.write_text(text + '\n')

    index = Path('docs/project/BUILD_TEST_INDEX.md')
    text = index.read_text().rstrip()
    marker = '## Search Build245/Build246 target-device follow-up — 2026-08-29'
    if marker not in text:
        text += '''\n\n## Search Build245/Build246 target-device follow-up — 2026-08-29\n\n- **Build245 / 0.14.78**: target-device tested and rejected as final. Recording/user evidence: recommendation/container twitch; gear needs +15%; same-server Search first poster wall is much slower than competitor and OnePlayer Library; recommendations must be Movie+Series only; already-seen recommendation posters visibly return to placeholders after scrolling away/back.\n- **Build246 / 0.14.79**: exact source `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac`; Search-specific lean 18-item poster query, Movie/Series Suggestions whitelist, append-only recommendation expansion without incremental bottom spinner, Search-lifetime decoded recommendation image pins over the existing persistent disk cache, +15% gear. Run/job `33255278229 / 99107775908` success; artifact `9715650501` (`sha256:39bb802573962dca207aa0af02c2974aa73082aaa10dfe049ba39c952bc5c7b3`); IPA SHA-256 `184082a21d850e7203c1be717e27d7fb95301caa5a36de6b814e4930b30750b9`; source ZIP SHA-256 `8cc7e4799e077e47d04c8a3c1d3c1d3a38fde2a3724ca268957d22a112a896c0`; MinOS 15.0. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**\n'''
    index.write_text(text + '\n')

    decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
    text = decisions.read_text().rstrip()
    marker = '## Search poster-query and recommendation-image ownership — Build246'
    if marker not in text:
        text += '''\n\n## Search poster-query and recommendation-image ownership — Build246\n\n- Search poster-wall presentation may use an additive Search-specific lean Emby item query rather than weakening the shared/general browse fields. Poster-first Search needs only identity/name/type plus image tags/aspect, user-data progress, year and minimal series identity before detail navigation.\n- The existing `EmbyImageDiskCache` remains the persistent byte-cache authority. Search must not create a second disk cache. Search may retain strong decoded-image pins for posters already presented during the current Search view-model lifetime so lazy-cell recycling does not visibly regress to placeholders while persistent bytes are reread/decoded.\n- Recommendation expansion should preserve already-visible item identity and append new IDs from the larger Emby Suggestions prefix; do not replace the full visible prefix merely because the API lacks `StartIndex`.\n'''
    decisions.write_text(text + '\n')
else:
    raise SystemExit(f'unknown mode {mode}')
