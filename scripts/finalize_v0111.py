from pathlib import Path


def replace_all(path: str, old: str, new: str, expected: int | None = None) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if expected is not None and count != expected:
        raise SystemExit(f"{path}: expected {expected} occurrences of {old!r}, got {count}")
    if count == 0:
        if new in text:
            return
        raise SystemExit(f"{path}: target not found: {old!r}")
    p.write_text(text.replace(old, new))

replace_all("Sources/Core/AppIdentity.swift", 'sourceVersion = "0.11.0"', 'sourceVersion = "0.11.1"', 1)
replace_all("Sources/Core/AppIdentity.swift", '?? "0.11.0"', '?? "0.11.1"', 1)
replace_all("Config/Info.plist", '<string>0.11.0</string>', '<string>0.11.1</string>', 1)
replace_all("Config/Info.plist", '<string>54</string>', '<string>55</string>', 1)
replace_all("project.yml", 'MARKETING_VERSION: "0.11.0"', 'MARKETING_VERSION: "0.11.1"', 2)
replace_all("project.yml", 'CURRENT_PROJECT_VERSION: "54"', 'CURRENT_PROJECT_VERSION: "55"', 2)
replace_all(".github/workflows/build-unsigned-ipa.yml", 'IPA_NAME="EmbyPlayerLab-0.11.0-${GITHUB_SHA::7}-unsigned.ipa"', 'IPA_NAME="EmbyPlayerLab-0.11.1-${GITHUB_SHA::7}-unsigned.ipa"', 1)

for workflow in [".github/workflows/validate-source.yml", ".github/workflows/build-unsigned-ipa.yml"]:
    p = Path(workflow)
    text = p.read_text()
    marker = '''      - name: Audit Transport v3 invariants\n        run: python3 scripts/check_transport_v3_invariants.py\n'''
    addition = marker + '''\n      - name: Audit seek stall invariants\n        run: python3 scripts/check_seek_stall_invariants.py\n'''
    if "Audit seek stall invariants" not in text:
        if marker not in text:
            raise SystemExit(f"{workflow}: Transport v3 audit marker missing")
        text = text.replace(marker, addition, 1)
        p.write_text(text)

p = Path("scripts/check_transport_v3_invariants.py")
text = p.read_text()
text = text.replace('MARKETING_VERSION: "0.11.0"', 'MARKETING_VERSION: "0.11.1"')
text = text.replace('project marketing version must be 0.11.0', 'project marketing version must be 0.11.1')
text = text.replace('CURRENT_PROJECT_VERSION: "54"', 'CURRENT_PROJECT_VERSION: "55"')
text = text.replace('project build number must be 54', 'project build number must be 55')
text = text.replace('<string>0.11.0</string>', '<string>0.11.1</string>')
text = text.replace('<string>54</string>', '<string>55</string>')
text = text.replace('sourceVersion = "0.11.0"', 'sourceVersion = "0.11.1"')
text = text.replace('IPA_NAME="EmbyPlayerLab-0.11.0-${GITHUB_SHA::7}-unsigned.ipa"', 'IPA_NAME="EmbyPlayerLab-0.11.1-${GITHUB_SHA::7}-unsigned.ipa"')
text = text.replace('unsigned IPA filename must identify v0.11.0', 'unsigned IPA filename must identify v0.11.1')
if 'Audit seek stall invariants' not in text:
    insert = '''require("Audit Transport v3 invariants" in build_workflow and "check_transport_v3_invariants.py" in build_workflow, "unsigned IPA build must enforce Transport v3 invariants")\n'''
    replacement = insert + '''require("Audit seek stall invariants" in validate_workflow and "check_seek_stall_invariants.py" in validate_workflow, "Validate Source must enforce seek stall invariants")\nrequire("Audit seek stall invariants" in build_workflow and "check_seek_stall_invariants.py" in build_workflow, "unsigned IPA build must enforce seek stall invariants")\n'''
    if insert not in text:
        raise SystemExit("v3 invariant workflow insertion marker missing")
    text = text.replace(insert, replacement, 1)
p.write_text(text)

print("v0.11.1 finalization applied")
