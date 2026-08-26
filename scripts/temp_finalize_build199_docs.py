from pathlib import Path
import re


def replace_once(text, pattern, replacement, label, flags=0):
    new, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 replacement, got {count}")
    return new


# PROJECT_STATE.md
path = Path("docs/project/PROJECT_STATE.md")
text = path.read_text()
text = replace_once(
    text,
    r"_Last updated after .*?_\n",
    "_Last updated after OnePlayer 0.14.32 / Build199 completed target-device acceptance for Add/Edit Emby server management, cached-first auto-start, retained/editable Keychain password handling and opt-in iCloud Keychain password sync. PR #256 merged the accepted code to `main` at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. Build199 is now the accepted overall functional baseline; the home-carousel Build198 line remains a separate active task._\n",
    "PROJECT_STATE header",
    re.S,
)
text = replace_once(
    text,
    r"The latest \*\*real-device accepted\*\* functional baseline is:\n\n(?:- .*\n)+",
    """The latest **real-device accepted** functional baseline is:\n\n- Product: **OnePlayer**\n- Version: **0.14.32**\n- Build: **199**\n- Canonical branch: `main`\n- Final merge PR: **#256**\n- Final merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`\n- Development branch: `feat/add-emby-page-optimization`\n- Real-device-tested product source / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`\n- Final PR head after removing temporary CI helpers: `9357f0cd9395b3e8ef75920d630578d739d5518b`\n- Dedicated standard MPV CI run: **32942618979**\n- Artifact: `OnePlayer-0.14.32-build199-add-emby-password-sync`\n- Artifact ID: `9597143667`\n- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`\n- Deployment Target / MinOS: **iOS 15.0**\n- Required target device: **iPhone 15 Pro Max / iOS 17.0**\n- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for Add/Edit Emby requirements / merged to main**\n\n""",
    "PROJECT_STATE baseline block",
    re.M,
)
build199_para = """Build199 / OnePlayer 0.14.32 is **real-device accepted and merged to `main` through PR #256 at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`**. It completes the Add/Edit Emby line on top of Build192/196: modern server editor, one-tap paste, same-server multi-route validation/selection, cached-first auto-start, local Keychain password retention/edit refill, changed-password same Server ID/User ID reauthentication, and opt-in independent synchronizable Keychain password storage for cross-device iCloud sync. The password is not stored in UserDefaults/plain server configuration/diagnostics. Frozen `Emby / STRM → 302 → 115/CDN → iPhone` client-direct media transport and Player/PiP/UnifiedTransport/Cache/Seek/Resume contracts remain unchanged.\n\n"""
anchor = "Build195 / OnePlayer 0.14.28 changes only that player row from `HStack` to `LazyHStack`;"
idx = text.find(anchor)
if idx < 0:
    raise SystemExit("PROJECT_STATE Build195 anchor missing")
end = text.find("\n\n", idx)
if end < 0:
    raise SystemExit("PROJECT_STATE Build195 paragraph end missing")
if "Build199 / OnePlayer 0.14.32 is **real-device accepted" not in text:
    text = text[:end + 2] + build199_para + text[end + 2:]

text = replace_once(
    text,
    r"### Build196 / OnePlayer 0\.14\.29 — Add/Edit Emby cached-first follow-up\n.*?(?=### Build193 / OnePlayer 0\.14\.26)",
    """### Build199 / OnePlayer 0.14.32 — Add/Edit Emby completion\n\n`DEV-add-emby-page-optimization` is completed and its active checkpoint is retired.\n\n- Build192 target-device feedback accepted the redesigned editor direction but exposed the missing Edit password row and refined auto-start to cached-first\n- Build196 established cached-first auto-start and optional password reauthentication, but its password-exclusion policy was superseded by the user's retained-password/iCloud-sync requirement\n- Build199 stores the server password in a dedicated local Keychain item, preloads it for Edit, avoids reauthentication when unchanged, and uses a separate `kSecAttrSynchronizable` Keychain password item only while that server has iCloud sync enabled\n- synchronized JSON server registry still does not embed the password; UserDefaults/plain server configuration/diagnostics remain password-free\n- dedicated CI run: **`32942618979` — success**\n- artifact: `OnePlayer-0.14.32-build199-add-emby-password-sync`; ID `9597143667`\n- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`\n- tested product source / CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`\n- final PR head after helper cleanup: `9357f0cd9395b3e8ef75920d630578d739d5518b`\n- PR `#256` merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`\n- MinOS: 15.0\n- target device: iPhone 15 Pro Max / iOS 17.0\n- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable / merged to main**\n\n""",
    "PROJECT_STATE candidate section",
    re.S,
)
path.write_text(text)

# MODULE_STATUS.md
path = Path("docs/project/MODULE_STATUS.md")
text = path.read_text()
text = replace_once(
    text,
    r"^\| Emby server management / multi-route \|.*$",
    "| Emby server management / multi-route | **Stable at Build199 / merged to main** | Build199 / 0.14.32 completed the Add/Edit Emby line: modern editor, same-server multi-route selection, cached-first auto-start, local Keychain password retention/edit refill, unchanged-password no-op reauth behavior, changed-password same Server ID/User ID validation, and opt-in separate synchronizable Keychain password storage for iCloud cross-device sync. User accepted Build199 on the target device and approved completion/merge; PR #256 merged at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. Password remains absent from UserDefaults/plain server configuration/diagnostics, and frozen STRM/302/115 client-direct media transport is untouched. |",
    "MODULE_STATUS emby row",
    re.M,
)
text = replace_once(
    text,
    r"^\| Other product modules \|.*$",
    "| Other product modules | Active parallel work | Build199 / 0.14.32 is the accepted overall runtime baseline on `main`. Home-carousel Build198 / 0.14.31 remains a separate Active task/identity and is not implied accepted by the Build199 merge. |",
    "MODULE_STATUS other row",
    re.M,
)
path.write_text(text)

# BUILD_TEST_INDEX.md
path = Path("docs/project/BUILD_TEST_INDEX.md")
text = path.read_text()
text = replace_once(
    text,
    r"^\| \*\*Build196 / 0\.14\.29\*\* \|.*$",
    "| **Build196 / 0.14.29** | Add/Edit password + cached-first auto-start | Established cached-first Home startup and optional Edit-password reauthentication while keeping same-server routing. Dedicated standard MPV Release CI/IPA passed. Its password-exclusion policy was later superseded by the user's requirement to retain the password and sync it through iCloud Keychain; Build196 is therefore a historical predecessor, not the accepted final Add/Edit Emby baseline. |\n| **Build199 / 0.14.32** | Add/Edit Emby completion + password retention/iCloud sync | Keeps the modern editor, one-tap paste, cached-first auto-start and same-server multi-route selection; stores password in a dedicated local Keychain item, preloads it for Edit, avoids reauth when unchanged, validates same Server ID/User ID when changed, and uses a separate synchronizable Keychain password item only when iCloud sync is enabled. Dedicated standard MPV run `32942618979` passed; artifact `9597143667`, IPA SHA-256 `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`, MinOS 15.0. **User accepted Build199 on iPhone 15 Pro Max / iOS 17.0 and approved completion/merge; PR #256 merged at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. Current accepted overall baseline.** |",
    "BUILD_TEST_INDEX Build196 row",
    re.M,
)
new_baseline = """## Current accepted baseline\n\n- OnePlayer **0.14.32 / Build199**\n- canonical branch: `main`\n- final merge PR: `#256`\n- final merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`\n- development branch: `feat/add-emby-page-optimization`\n- tested product source / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`\n- final PR head after temporary workflow cleanup: `9357f0cd9395b3e8ef75920d630578d739d5518b`\n- CI run: `32942618979`\n- artifact: `OnePlayer-0.14.32-build199-add-emby-password-sync`\n- artifact ID: `9597143667`\n- IPA: `OnePlayer-0.14.32-build199-add-emby-password-sync-unsigned.ipa`\n- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`\n- target device: iPhone 15 Pro Max / iOS 17.0\n- Deployment Target / MinOS: **iOS 15.0**\n- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable for Add/Edit Emby requirements / merged to main**\n\nBuild199 inherits the accepted Build195 player grouping/large-list contract, Build191 detail episode-selection/navigation contract, Build184/182 detail presentation contracts, Build178 canonical TV episode order, Build176 source-owned episode session replacement, Build173 PiP freeze point and the frozen MPV/Transport/Cache/STRM→302→115/CDN client-direct contracts. The independent home-carousel Build198 task remains active and is not made stable by this merge.\n\n## Build199 Add/Edit Emby evidence\n\n- task: `DEV-add-emby-page-optimization` — completed; active checkpoint retired after acceptance/merge\n- Build192 real-device feedback accepted the editor direction but exposed the missing Edit password row and refined auto-start to cached-first\n- Build196 completed cached-first startup and optional reauthentication but was superseded by the retained-password/iCloud-sync requirement\n- Build199 tested source / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`\n- final PR head after removing only the two temporary Build199 workflows: `9357f0cd9395b3e8ef75920d630578d739d5518b`\n- diff from tested source to final PR head: temporary workflow deletions only; the five accepted product source files were unchanged\n- CI run: `32942618979` — success\n- artifact: `OnePlayer-0.14.32-build199-add-emby-password-sync`\n- artifact ID: `9597143667`\n- artifact archive digest: `sha256:94d19775fc82d42232d1d5f3efe40b0f04719e599cb5cfb7317746490ca51972`\n- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`\n- app/runtime MinOS: 15.0\n- real-device evidence: user reported Build199 acceptance on 2026-08-26 and explicitly requested task closure/code merge\n- merge: PR `#256` → `main` at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`\n- stable contract: password is local-Keychain retained and editable; opt-in iCloud sync uses a separate synchronizable Keychain password item; password is not embedded in UserDefaults/plain configuration/diagnostics/synchronized JSON registry; cached-first Home and same-server multi-route behavior remain; media bytes remain client-direct and never transit NAS.\n\n## Episode-selection evidence trail"""
text = replace_once(
    text,
    r"## Current accepted baseline\n.*?## Episode-selection evidence trail",
    new_baseline,
    "BUILD_TEST_INDEX baseline block",
    re.S,
)
path.write_text(text)

# TECHNICAL_DECISIONS.md
path = Path("docs/project/TECHNICAL_DECISIONS.md")
text = path.read_text()
text = replace_once(
    text,
    r"- Opt-in iCloud server sync uses a separate `kSecAttrSynchronizable` Keychain record\. It may contain server configuration, AccessToken and auto-start flag; it must never contain the user's password\. Existing local AccessToken storage keeps its prior `ThisDeviceOnly` accessibility contract\.",
    "- Opt-in iCloud server sync keeps the synchronized server registry separate from password storage. The registry may contain server configuration, AccessToken and auto-start flag but does not embed the password. Build199 adds a dedicated local Keychain password item for retained/editable credentials and, only while iCloud sync is enabled for that server, an independent `kSecAttrSynchronizable` Keychain password item for cross-device propagation. Existing local AccessToken storage keeps its prior `ThisDeviceOnly` accessibility contract.",
    "TECH D014 sync bullet",
)
text = replace_once(
    text,
    r"Build192 / OnePlayer 0\.14\.25 passed dedicated Xcode 16\.4 standard MPV Release CI and produced an iOS 15\.0-compatible IPA\. This confirms implementation/build evidence only\. Route behavior, root auto-start presentation and synchronizable Keychain behavior—especially cross-device behavior under TrollStore/ad-hoc signing—remain \*\*real-device pending\*\* and are not frozen\.",
    "Build192 established this ownership boundary; Build196 refined auto-start to cached-first. Build199 / OnePlayer 0.14.32 then completed the retained/editable password and opt-in iCloud Keychain password-sync requirement, passed dedicated standard MPV CI, produced the validated iOS 15.0 IPA, was accepted by the user on the target device, and merged through PR #256 at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. Treat the Add/Edit Emby server-management ownership and credential split as stable unless new target-device regression evidence requires reopening it.",
    "TECH D014 conclusion",
)
final_autostart = """## D014A — Auto-start is cached-first; retained password is Keychain-owned\n\nBuild192 target-device feedback and the accepted Build196/199 follow-ups refine D014 without reopening playback transport.\n\n- Auto-start must not gate Home construction on network route selection. After local session/token restore, `RootView` creates the normal authenticated client synchronously and constructs the target Emby root immediately.\n- Existing `V3EmbyHomeViewModel` UserDefaults snapshots (libraries / resume / latest / carousel) and `EmbyImageDiskCache` are the only cached-home authorities. Do not add a second offline-home model or duplicate state owner.\n- Best-route selection still runs concurrently. If the winner differs, Home is rebuilt with that client so the existing refresh path fetches current data. If route selection fails while an initial local client exists, retain stale cached Home; do not close back to the first-level server page.\n- `EmbyImageDiskCache.stableKey(for:)` removes token query items but retains scheme/host/path. Therefore the runtime same-server winner is persisted as the current session `serverURL`, allowing the next cached-first launch to generate image URLs on the previous winner and maximize disk-cache hits.\n- Server password is retained in a dedicated local Keychain item and is preloaded into Edit Server. Saving an unchanged password does not force reauthentication.\n- A changed password authenticates the stored username on the validated same-server best route and must preserve the same Server ID (when returned) and exact User ID before replacing the AccessToken.\n- When `iCloud 同步` is enabled for that server, the password is additionally stored in a separate synchronizable Keychain item. Turning sync off removes that synchronizable password item while retaining the local credential.\n- Password remains absent from UserDefaults, plain `EmbyServerConfiguration`, diagnostics and the synchronized JSON server registry. Token storage and password storage remain separate Keychain records.\n- Manual entry from the first-level server list keeps its pre-Home route-selection behavior; cached-first is specifically required for auto-start.\n- Build199 / OnePlayer 0.14.32 passed dedicated standard MPV CI (`32942618979`), produced the validated iOS 15.0 IPA, was accepted by the user on iPhone 15 Pro Max / iOS 17.0, and merged through PR #256 at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. This contract is stable for the accepted Add/Edit Emby requirements.\n\n## D016 — Player episode grouping follows real SeasonId; very large rows are lazy"""
text = replace_once(
    text,
    r"## D015 — Auto-start is cached-first; Edit password is optional reauthentication\n.*?## D016 — Player episode grouping follows real SeasonId; very large rows are lazy",
    final_autostart,
    "TECH cached-first section",
    re.S,
)
path.write_text(text)

# Retire active Add/Edit Emby checkpoint after global evidence is updated.
checkpoint = Path("docs/project/current/dev/DEV-add-emby-page-optimization.md")
if not checkpoint.exists():
    raise SystemExit("active Add/Edit Emby checkpoint missing")
checkpoint.unlink()

# Remove temporary helper files in the same finalization commit.
workflow = Path(".github/workflows/temp-finalize-build199-docs.yml")
if workflow.exists():
    workflow.unlink()
helper = Path("scripts/temp_finalize_build199_docs.py")
if helper.exists():
    helper.unlink()

for p in [Path("docs/project/PROJECT_STATE.md"), Path("docs/project/MODULE_STATUS.md"), Path("docs/project/BUILD_TEST_INDEX.md"), Path("docs/project/TECHNICAL_DECISIONS.md")]:
    value = p.read_text()
    if "Build199" not in value:
        raise SystemExit(f"{p}: Build199 evidence missing")
if "password is never stored" in Path("docs/project/TECHNICAL_DECISIONS.md").read_text():
    raise SystemExit("stale password exclusion remains in TECHNICAL_DECISIONS")
print("Build199 project documentation finalized")
