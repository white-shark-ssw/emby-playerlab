from pathlib import Path


def replace_all(path: str, old: str, new: str, expected: int | None = None) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count == 0 and new in text:
        return
    if expected is not None and count != expected:
        raise SystemExit(f"{path}: expected {expected} x {old!r}, got {count}")
    if count == 0:
        raise SystemExit(f"{path}: target missing {old!r}")
    p.write_text(text.replace(old, new))


replace_all("Sources/Core/AppIdentity.swift", 'sourceVersion = "0.11.3"', 'sourceVersion = "0.12.0"', 1)
replace_all("Sources/Core/AppIdentity.swift", '?? "0.11.3"', '?? "0.12.0"', 1)
replace_all("Config/Info.plist", '<string>0.11.3</string>', '<string>0.12.0</string>', 1)
replace_all("Config/Info.plist", '<string>57</string>', '<string>58</string>', 1)
replace_all("project.yml", 'MARKETING_VERSION: "0.11.3"', 'MARKETING_VERSION: "0.12.0"', 2)
replace_all("project.yml", 'CURRENT_PROJECT_VERSION: "57"', 'CURRENT_PROJECT_VERSION: "58"', 2)
replace_all(".github/workflows/build-unsigned-ipa.yml", 'IPA_NAME="EmbyPlayerLab-0.11.3-${GITHUB_SHA::7}-unsigned.ipa"', 'IPA_NAME="EmbyPlayerLab-0.12.0-${GITHUB_SHA::7}-unsigned.ipa"', 1)

for workflow in [".github/workflows/validate-source.yml", ".github/workflows/build-unsigned-ipa.yml"]:
    p = Path(workflow)
    text = p.read_text()
    if "Audit Scheduler v2 invariants" not in text:
        marker = '''      - name: Audit transport stability invariants\n        run: python3 scripts/check_transport_stability_invariants.py\n'''
        addition = marker + '''\n      - name: Audit Scheduler v2 invariants\n        run: python3 scripts/check_scheduler_v2_invariants.py\n'''
        if marker not in text:
            raise SystemExit(f"{workflow}: transport stability marker missing")
        text = text.replace(marker, addition, 1)
        p.write_text(text)

p = Path("scripts/check_transport_v3_invariants.py")
text = p.read_text()
text = text.replace('MARKETING_VERSION: "0.11.3"', 'MARKETING_VERSION: "0.12.0"')
text = text.replace('project marketing version must be 0.11.3', 'project marketing version must be 0.12.0')
text = text.replace('CURRENT_PROJECT_VERSION: "57"', 'CURRENT_PROJECT_VERSION: "58"')
text = text.replace('project build number must be 57', 'project build number must be 58')
text = text.replace('<string>0.11.3</string>', '<string>0.12.0</string>')
text = text.replace('<string>57</string>', '<string>58</string>')
text = text.replace('sourceVersion = "0.11.3"', 'sourceVersion = "0.12.0"')
text = text.replace('IPA_NAME="EmbyPlayerLab-0.11.3-${GITHUB_SHA::7}-unsigned.ipa"', 'IPA_NAME="EmbyPlayerLab-0.12.0-${GITHUB_SHA::7}-unsigned.ipa"')
text = text.replace('unsigned IPA filename must identify v0.11.3', 'unsigned IPA filename must identify v0.12.0')
if '".github/workflows/apply-v0120-scheduler-v2.yml"' not in text:
    marker = '    "scripts/apply_v0113_startup_lane_health.py",\n'
    addition = marker + '    ".github/workflows/apply-v0120-scheduler-v2.yml",\n    "scripts/apply_v0120_scheduler_v2.py",\n    "scripts/refine_v0120_scheduler_v2.py",\n    "scripts/cleanup_v0120_scheduler_v2.py",\n    "scripts/finalize_v0120.py",\n'
    if marker not in text:
        raise SystemExit("v3 invariant temporary-file marker missing")
    text = text.replace(marker, addition, 1)
p.write_text(text)

print("v0.12.0 finalization applied")
