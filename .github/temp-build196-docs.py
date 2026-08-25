from pathlib import Path


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def write(path, text):
    Path(path).write_text(text)


# BUILD_TEST_INDEX.md
path = "docs/project/BUILD_TEST_INDEX.md"
text = Path(path).read_text()
old192 = '| **Build192 / 0.14.25** | Add/Edit Emby modernization + same-server multi-route startup | Modern card editor, one-tap clipboard import, editor-only route latency, root-level auto-start, synchronizable Keychain opt-in server registry, and first-valid same-Server-ID route selection before Home client creation. Dedicated Xcode 16.4 standard MPV Release CI passed, app identity/MinOS 15.0 validated and unsigned IPA produced. **Real-device pending; does not replace Build191.** |'
new192 = '| **Build192 / 0.14.25** | Add/Edit Emby modernization + same-server multi-route startup | Dedicated Release CI/IPA passed. **Real-device follow-up:** Edit Server rendered correctly, the tested route showed 73 ms / fastest and auto-start+iCloud toggles were visible/on, but Edit hid the password row. User also superseded the pre-Home network gate with a cached-first auto-start requirement. **Tested with actionable feedback / not accepted; superseded by Build196.** |'
if old192 in text:
    text = text.replace(old192, new192, 1)
if '| **Build196 / 0.14.29** |' not in text:
    marker = '| **Build195 / 0.14.28** | Lazy player episode row for very large seasons | Replaces only the player picker\'s eager episode `HStack` with `LazyHStack`; full canonical data, SeasonId grouping, UI and auto-next remain unchanged. Dedicated Xcode 16.4 Release CI passed, MinOS 15.0 validated and TrollStore-friendly IPA produced. **Real-device performance validation pending; does not replace Build191.** |'
    require(marker in text, 'Build195 row missing')
    row = '| **Build196 / 0.14.29** | Add/Edit password + cached-first auto-start | Edit always shows an empty password field; blank keeps the current token while a supplied password reauthenticates only the same Server ID/User ID. Auto-start creates Home immediately from the existing persisted Home snapshots and image disk cache, selects/routes/refreshes in parallel, retains stale Home if route selection fails, and remembers the runtime winner for future host-based image-cache hits. Dedicated Xcode 16.4 standard MPV Release CI passed, app identity/MinOS 15.0 validated, and unsigned IPA produced. **Real-device Build196 validation pending; does not replace Build191.** |'
    text = text.replace(marker, marker + '\n' + row, 1)
summary_old = 'Build192 / 0.14.25 Add/Edit Emby and Build193 / 0.14.26 home-carousel remain independent candidates; each must resync with Build191 and rerun affected validation before final integration.'
summary_new = 'Build192 / 0.14.25 Add/Edit Emby now has real-device feedback and is superseded by Build196 / 0.14.29; Build196 is the current Add/Edit Emby cached-first candidate with CI/IPA complete and real-device validation pending. Build193 / 0.14.26 home-carousel remains a rejected/investigation line.'
if summary_old in text:
    text = text.replace(summary_old, summary_new, 1)
if '## Build196 Add/Edit Emby cached-first evidence' not in text:
    marker = '## Main integration evidence'
    require(marker in text, 'BUILD_TEST_INDEX main integration marker missing')
    section = """## Build196 Add/Edit Emby cached-first evidence

- task: `DEV-add-emby-page-optimization` — Active
- branch / Draft PR: `feat/add-emby-page-optimization` / `#256`
- accepted overall baseline remains Build191 / 0.14.24
- Build192 real-device feedback: Edit Server UI rendered; tested route 73 ms / fastest; auto-start and iCloud toggles visible/on; password row missing, so Build192 not accepted
- Build196 product commit: `571f54647ebc2d8ac811c63bf8c548f234172152`
- exact dedicated CI source: `a28430b6087db67cd4fac2c71a56240992b8f46d`
- clean feature head after temporary workflow removal: `113b9bdc79e499750bb9ef98150bb2f7bc805e17`
- CI run: **`32885369998` — success**
- artifact: `OnePlayer-0.14.29-build196-add-emby-cached-startup`; ID **`9577471047`**
- artifact digest: `sha256:f420f2e9f6767ff1739aa0de601e89a6641213b297a3597bfd8ec6831ea6c23c`
- IPA: `OnePlayer-0.14.29-build196-add-emby-cached-startup-unsigned.ipa`
- IPA SHA-256: **`b2c0e0a7af6aa29ad0f7117b88fadf3eb9a2c45c73bb961c7a63f50a2c763c66`**
- source ZIP: `OnePlayer-0.14.29-build196-add-emby-cached-startup-a28430b-source.zip`
- source ZIP SHA-256: **`10044e843155e2460cc023b7457acfb5c8cadc0c82def04cf3b4a0fb380d36ef`**
- app identity: `com.embyplayerlab.app`, OnePlayer 0.14.29 (196), display name OnePlayer
- MinOS: app and main runtime Mach-O 15.0; compatibility audit OK
- source/frozen contract: passed; PR product diff remains only RootView / KeychainStore / SessionStore / EmbyServerRootViewV3 / ServerListView; no Home model, Player, Transport or Cache implementation change
- evidence level: **Code written / CI passed / IPA produced / Build196 real-device pending / not stable**

"""
    text = text.replace(marker, section + marker, 1)
write(path, text)

# MODULE_STATUS.md
path = "docs/project/MODULE_STATUS.md"
text = Path(path).read_text()
old = '| Emby server management / multi-route | **Active Build192 candidate** | SessionStore-owned same-Server-ID route configuration/selection, root-level auto-start and opt-in synchronizable Keychain server registry. Dedicated Release CI/IPA passed; real-device route/iCloud/startup validation pending. This does not reopen the Frozen STRM/302/115 client-direct media path. |'
new = '| Emby server management / multi-route | **Active Build196 candidate; Build192 device feedback superseded** | Build192 target-device Edit UI exposed the missing password row. Build196 keeps SessionStore ownership, makes Edit password actionable without persisting it, and changes auto-start to cached-first Home: existing Home snapshots/image disk cache render before network, route selection/refresh runs concurrently, stale Home survives route failure, and runtime winner serverURL is remembered for future image-cache hits. Dedicated Release CI/IPA passed; Build196 real-device + cross-device iCloud validation pending. Frozen STRM/302/115 client-direct media path remains untouched. |'
require(old in text or new in text, 'MODULE_STATUS Emby row missing')
if old in text:
    text = text.replace(old, new, 1)
old_other = '| Other product modules | Active parallel work | Build191 / 0.14.24 is the accepted overall runtime baseline on `main`. Build192 / 0.14.25 remains the independent Add/Edit Emby candidate, Build193 / 0.14.26 remains the rejected/investigation home-carousel line, Build194 / 0.14.27 proved player SeasonId grouping correctness but exposed large-list picker open latency, and Build195 / 0.14.28 is the CI/IPA-complete lazy-row performance candidate pending real-device validation. |'
new_other = '| Other product modules | Active parallel work | Build191 / 0.14.24 is the accepted overall runtime baseline on `main`. Build192 / 0.14.25 Add/Edit Emby has real-device feedback and is superseded by Build196 / 0.14.29, whose cached-first/password follow-up has CI/IPA complete but awaits target-device validation. Build193 remains the rejected/investigation carousel line; Build194 proved player SeasonId grouping correctness; Build195 is the CI/IPA-complete lazy-row performance candidate pending real-device validation. |'
if old_other in text:
    text = text.replace(old_other, new_other, 1)
write(path, text)

# TECHNICAL_DECISIONS.md
path = "docs/project/TECHNICAL_DECISIONS.md"
text = Path(path).read_text()
if '## D015 — Auto-start is cached-first; Edit password is optional reauthentication' not in text:
    section = """## D015 — Auto-start is cached-first; Edit password is optional reauthentication

Build192 target-device feedback and the user's startup requirement refine D014 without reopening playback transport.

- Auto-start must not gate Home construction on network route selection. After local session/token restore, `RootView` creates the normal authenticated client synchronously and constructs the target Emby root immediately.
- Existing `V3EmbyHomeViewModel` UserDefaults snapshots (libraries / resume / latest / carousel) and `EmbyImageDiskCache` are the only cached-home authorities. Do not add a second offline-home model or duplicate state owner.
- Best-route selection still runs concurrently. If the winner differs, Home is rebuilt with that client so the existing refresh path fetches current data. If route selection fails while an initial local client exists, retain stale cached Home; do not close back to the first-level server page.
- `EmbyImageDiskCache.stableKey(for:)` removes token query items but retains scheme/host/path. Therefore the runtime same-server winner is persisted as the current session `serverURL`, allowing the next cached-first launch to generate image URLs on the previous winner and maximize disk-cache hits.
- Edit Server always exposes the password row, initially empty because password is never stored. Empty means keep the current AccessToken. Non-empty means authenticate the stored username on the validated same-server best route, require the same Server ID (when returned) and exact same User ID, then replace only the AccessToken.
- Password remains absent from UserDefaults, local server configuration and synchronizable Keychain registry. Existing local token and opt-in synchronizable token contracts remain unchanged.
- Manual entry from the first-level server list keeps its pre-Home route-selection behavior; cached-first is specifically required for auto-start in this decision.
- Build196 / OnePlayer 0.14.29 passed dedicated Xcode 16.4 standard MPV Release CI, app/runtime MinOS 15.0 validation and IPA packaging. This is build evidence only; cached-first presentation, offline/stale behavior, edit-password runtime semantics and iCloud cross-device behavior remain target-device pending.

"""
    text = text.rstrip() + '\n\n' + section.rstrip() + '\n'
write(path, text)

# PROJECT_STATE.md
path = "docs/project/PROJECT_STATE.md"
text = Path(path).read_text()
if '## Build196 / OnePlayer 0.14.29 — Add/Edit Emby cached-first follow-up' not in text:
    section = """## Build196 / OnePlayer 0.14.29 — Add/Edit Emby cached-first follow-up

`DEV-add-emby-page-optimization` remains Active. Build192 has now been tested on the target device: the redesigned Edit Server UI rendered, the tested route reported 73 ms / fastest, and auto-start/iCloud controls were visible and enabled; the missing Edit password row was rejected. The user also required auto-start to enter cached Home before network, with stale Home retained if Emby is temporarily unreachable.

Build196 implements that follow-up without modifying Home-model/cache ownership or playback transport. Edit always shows an empty password field; blank retains the token, while non-empty reauthenticates the stored username and requires the same Server ID/User ID before token replacement. Auto-start supplies a local-token client immediately so existing Home snapshots and disk-cached images can render; best-route selection and live refresh then proceed, route failure does not close the cached auto-start root, and a successful runtime winner is remembered as `serverURL` because image cache keys retain host.

Dedicated run `32885369998` passed the Build196 source/Frozen contract, Xcode 16.4 standard MPV Release build, OnePlayer 0.14.29 (196) app validation and iOS 15.0 MinOS audit. Artifact `OnePlayer-0.14.29-build196-add-emby-cached-startup` ID `9577471047`; IPA SHA-256 `b2c0e0a7af6aa29ad0f7117b88fadf3eb9a2c45c73bb961c7a63f50a2c763c66`; exact source ZIP SHA-256 `10044e843155e2460cc023b7457acfb5c8cadc0c82def04cf3b4a0fb380d36ef`. Build191 / 0.14.24 remains the accepted overall baseline. **Build196 is Code written / CI passed / IPA produced / real-device pending / not stable.**

"""
    text = text.rstrip() + '\n\n' + section.rstrip() + '\n'
write(path, text)

# Task checkpoint: update Build196 evidence without overwriting its detailed acceptance contract.
path = "docs/project/current/dev/DEV-add-emby-page-optimization.md"
text = Path(path).read_text()
text = text.replace('- Current clean feature head after applicator cleanup：`85a16c5bbbf02556c5c8ed4c2fe532b0b3d8d269`。', '- Current clean feature head after Build196 workflow cleanup：`113b9bdc79e499750bb9ef98150bb2f7bc805e17`。')
text = text.replace('- CI：**pending**。\n- IPA：**pending**。\n- Real-device：**pending**。', '- Exact dedicated CI source：`a28430b6087db67cd4fac2c71a56240992b8f46d`。\n- Dedicated standard MPV Release run：**`32885369998` — success**。\n- Artifact：`OnePlayer-0.14.29-build196-add-emby-cached-startup`, ID **`9577471047`**, digest `sha256:f420f2e9f6767ff1739aa0de601e89a6641213b297a3597bfd8ec6831ea6c23c`。\n- IPA SHA-256：**`b2c0e0a7af6aa29ad0f7117b88fadf3eb9a2c45c73bb961c7a63f50a2c763c66`**。\n- Exact source ZIP SHA-256：**`10044e843155e2460cc023b7457acfb5c8cadc0c82def04cf3b4a0fb380d36ef`**。\n- App identity / compatibility：OnePlayer **0.14.29 (196)**; App + main runtime Mach-O MinOS **15.0**。\n- CI：**PASS**。\n- IPA：**PRODUCED**。\n- Real-device Build196：**pending**。')
old_next = '1. Build **OnePlayer 0.14.29 / Build196** using dedicated Xcode 16.4 standard MPV Release CI, preserving MinOS 15.0 and the five-file product scope.\n2. Verify source contract: Edit password row unconditional; edit password does not persist; cached-first auto-start uses existing Home snapshot/image cache; route failure with initial client does not close; no Home/Player/Transport/Cache implementation file changed.\n3. Produce and checksum unsigned IPA/source ZIP, then remove the temporary Build196 workflow from PR #256.\n4. Target-device test Build196:'
new_next = '1. Install the produced **OnePlayer 0.14.29 / Build196** IPA on iPhone 15 Pro Max / iOS 17.0.\n2. Target-device test Build196:'
if old_next in text:
    text = text.replace(old_next, new_next, 1)
write(path, text)
