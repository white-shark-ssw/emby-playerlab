from pathlib import Path


def replace_exact(path: str, old: str, new: str, expected: int | None = None) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if expected is not None and count != expected:
        raise SystemExit(f"{path}: expected {expected} occurrences of {old!r}, got {count}")
    if expected is None and count == 0:
        raise SystemExit(f"{path}: missing {old!r}")
    p.write_text(text.replace(old, new))


# Product version. Deployment Target deliberately stays iOS 15.0.
replace_exact("project.yml", 'MARKETING_VERSION: "0.12.5"', 'MARKETING_VERSION: "0.12.6"', 2)
replace_exact("project.yml", 'CURRENT_PROJECT_VERSION: "63"', 'CURRENT_PROJECT_VERSION: "64"', 2)
replace_exact("Config/Info.plist", '<string>0.12.5</string>', '<string>0.12.6</string>')
replace_exact("Config/Info.plist", '<string>63</string>', '<string>64</string>')
replace_exact("Sources/Core/AppIdentity.swift", '0.12.5', '0.12.6', 2)

# Historical behavior gates also assert the current release identity. Keep those assertions
# synchronized without changing their behavioral checks.
for path in [
    "scripts/check_transport_v3_invariants.py",
    "scripts/check_scheduler_v2_invariants.py",
    "scripts/check_live_lane_startup_invariants.py",
    "scripts/check_v0123_regressions.py",
    "scripts/check_v0124_regressions.py",
]:
    p = Path(path)
    text = p.read_text()
    if "0.12.5" not in text:
        raise SystemExit(f"{path}: current version literal missing")
    text = text.replace("0.12.5", "0.12.6")
    text = text.replace('CURRENT_PROJECT_VERSION: "63"', 'CURRENT_PROJECT_VERSION: "64"')
    text = text.replace('<string>63</string>', '<string>64</string>')
    text = text.replace("build63", "build64")
    text = text.replace("Build 63", "Build 64")
    p.write_text(text)

old_audit = '''      - name: Audit v0.12.4 scheduler regressions
        run: python3 scripts/check_v0124_regressions.py
'''
new_audit = old_audit + '''
      - name: Audit v0.12.6 frontier rescue regressions
        run: python3 scripts/check_v0126_frontier_rescue.py
'''

for path in [".github/workflows/validate-source.yml", ".github/workflows/build-unsigned-ipa.yml"]:
    p = Path(path)
    text = p.read_text()
    if "Audit v0.12.6 frontier rescue regressions" not in text:
        if old_audit not in text:
            raise SystemExit(f"{path}: audit insertion point missing")
        text = text.replace(old_audit, new_audit, 1)
    p.write_text(text)

build_path = Path(".github/workflows/build-unsigned-ipa.yml")
build = build_path.read_text()
if "0.12.5" not in build or "build63" not in build:
    raise SystemExit("build workflow v0.12.5 release metadata missing")
build = build.replace("0.12.5", "0.12.6").replace("build63", "build64").replace("Build 63", "Build 64")
build_path.write_text(build)

check_path = Path("scripts/check_v0126_frontier_rescue.py")
check = check_path.read_text()
imports = 'range_map = Path("Sources/Cache/PlaybackRangeMap.swift").read_text()\n'
expanded = imports + 'project = Path("project.yml").read_text()\ninfo = Path("Config/Info.plist").read_text()\nidentity = Path("Sources/Core/AppIdentity.swift").read_text()\nbuild = Path(".github/workflows/build-unsigned-ipa.yml").read_text()\nvalidate = Path(".github/workflows/validate-source.yml").read_text()\n'
if 'project = Path("project.yml").read_text()' not in check:
    if imports not in check:
        raise SystemExit("v0.12.6 check import anchor missing")
    check = check.replace(imports, expanded, 1)

anchor = 'require("physicalHoleCount" in range_map, "physical hole metric missing")\n'
release_checks = anchor + '''require(project.count('MARKETING_VERSION: "0.12.6"') == 2, "marketing version must be 0.12.6")
require(project.count('CURRENT_PROJECT_VERSION: "64"') == 2, "build number must be 64")
require("<string>0.12.6</string>" in info and "<string>64</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.6"' in identity, "AppIdentity source version mismatch")
require('IPA_NAME="EmbyPlayerLab-0.12.6-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.6")
require('RELEASE_TAG="v0.12.6-build64-dev"' in build, "release tag mismatch")
require('RELEASE_IPA="EmbyPlayerLab-v0.12.6-build64-${GITHUB_SHA::7}-unsigned.ipa"' in build, "release IPA mismatch")
require("Audit v0.12.6 frontier rescue regressions" in build and "check_v0126_frontier_rescue.py" in build, "build workflow must enforce v0.12.6 regression")
require("Audit v0.12.6 frontier rescue regressions" in validate and "check_v0126_frontier_rescue.py" in validate, "validate workflow must enforce v0.12.6 regression")
'''
if 'marketing version must be 0.12.6' not in check:
    if anchor not in check:
        raise SystemExit("v0.12.6 check release anchor missing")
    check = check.replace(anchor, release_checks, 1)
check_path.write_text(check)

print("v0.12.6 Build 64 release metadata finalized")
