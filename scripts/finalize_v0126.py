from pathlib import Path


def replace_required(path: str, old: str, new: str, minimum: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"{path}: expected >= {minimum} occurrences of {old!r}, got {count}")
    p.write_text(text.replace(old, new))


replace_required("project.yml", 'MARKETING_VERSION: "0.12.5"', 'MARKETING_VERSION: "0.12.6"', 2)
replace_required("project.yml", 'CURRENT_PROJECT_VERSION: "63"', 'CURRENT_PROJECT_VERSION: "64"', 2)
replace_required("Config/Info.plist", '<string>0.12.5</string>', '<string>0.12.6</string>')
replace_required("Config/Info.plist", '<string>63</string>', '<string>64</string>')
replace_required("Sources/Core/AppIdentity.swift", '0.12.5', '0.12.6', 2)

version_gates = [
    "scripts/check_transport_v3_invariants.py",
    "scripts/check_scheduler_v2_invariants.py",
    "scripts/check_live_lane_startup_invariants.py",
    "scripts/check_v0123_regressions.py",
    "scripts/check_v0124_regressions.py",
]
for path in version_gates:
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

build_path = Path(".github/workflows/build-unsigned-ipa.yml")
build = build_path.read_text()
if "0.12.5" not in build or "build63" not in build:
    raise SystemExit("build workflow v0.12.5 metadata missing")
build = build.replace("0.12.5", "0.12.6").replace("build63", "build64").replace("Build 63", "Build 64")
old_step = '''      - name: Audit v0.12.4 scheduler regressions
        run: python3 scripts/check_v0124_regressions.py
'''
new_step = old_step + '''
      - name: Audit v0.12.6 frontier rescue regressions
        run: python3 scripts/check_v0126_frontier_rescue.py
'''
if old_step not in build:
    raise SystemExit("build workflow insertion point missing")
build = build.replace(old_step, new_step, 1)
build_path.write_text(build)

validate_path = Path(".github/workflows/validate-source.yml")
validate = validate_path.read_text()
if old_step not in validate:
    raise SystemExit("validate workflow insertion point missing")
validate = validate.replace(old_step, new_step, 1)
validate_path.write_text(validate)

check_path = Path("scripts/check_v0126_frontier_rescue.py")
check = check_path.read_text()
check = check.replace('range_map = Path("Sources/Cache/PlaybackRangeMap.swift").read_text()\n', 'range_map = Path("Sources/Cache/PlaybackRangeMap.swift").read_text()\nproject = Path("project.yml").read_text()\ninfo = Path("Config/Info.plist").read_text()\nidentity = Path("Sources/Core/AppIdentity.swift").read_text()\nbuild = Path(".github/workflows/build-unsigned-ipa.yml").read_text()\nvalidate = Path(".github/workflows/validate-source.yml").read_text()\n')
anchor = 'require("physicalHoleCount" in range_map, "physical hole metric missing")\n'
extra = anchor + '''require(project.count('MARKETING_VERSION: "0.12.6"') == 2, "marketing version must be 0.12.6")
require(project.count('CURRENT_PROJECT_VERSION: "64"') == 2, "build number must be 64")
require("<string>0.12.6</string>" in info and "<string>64</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.6"' in identity, "AppIdentity source version mismatch")
require('IPA_NAME="EmbyPlayerLab-0.12.6-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.6")
require('RELEASE_TAG="v0.12.6-build64-dev"' in build, "release tag mismatch")
require("Audit v0.12.6 frontier rescue regressions" in build and "check_v0126_frontier_rescue.py" in build, "build workflow must enforce v0.12.6 regression")
require("Audit v0.12.6 frontier rescue regressions" in validate and "check_v0126_frontier_rescue.py" in validate, "validate workflow must enforce v0.12.6 regression")
'''
if anchor not in check:
    raise SystemExit("v0.12.6 check insertion point missing")
check_path.write_text(check.replace(anchor, extra, 1))

print("v0.12.6 Build 64 metadata finalized")
