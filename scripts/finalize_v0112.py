from pathlib import Path


def replace_all(path: str, old: str, new: str, expected: int | None = None) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if expected is not None and count != expected:
        if count == 0 and new in text:
            return
        raise SystemExit(f"{path}: expected {expected} occurrences of {old!r}, got {count}")
    if count == 0:
        if new in text:
            return
        raise SystemExit(f"{path}: target not found: {old!r}")
    p.write_text(text.replace(old, new))


replace_all("Sources/Core/AppIdentity.swift", 'sourceVersion = "0.11.1"', 'sourceVersion = "0.11.2"', 1)
replace_all("Sources/Core/AppIdentity.swift", '?? "0.11.1"', '?? "0.11.2"', 1)
replace_all("Config/Info.plist", '<string>0.11.1</string>', '<string>0.11.2</string>', 1)
replace_all("Config/Info.plist", '<string>55</string>', '<string>56</string>', 1)
replace_all("project.yml", 'MARKETING_VERSION: "0.11.1"', 'MARKETING_VERSION: "0.11.2"', 2)
replace_all("project.yml", 'CURRENT_PROJECT_VERSION: "55"', 'CURRENT_PROJECT_VERSION: "56"', 2)
replace_all(".github/workflows/build-unsigned-ipa.yml", 'IPA_NAME="EmbyPlayerLab-0.11.1-${GITHUB_SHA::7}-unsigned.ipa"', 'IPA_NAME="EmbyPlayerLab-0.11.2-${GITHUB_SHA::7}-unsigned.ipa"', 1)

for workflow in [".github/workflows/validate-source.yml", ".github/workflows/build-unsigned-ipa.yml"]:
    p = Path(workflow)
    text = p.read_text()
    marker = '''      - name: Audit seek stall invariants\n        run: python3 scripts/check_seek_stall_invariants.py\n'''
    addition = marker + '''\n      - name: Audit transport stability invariants\n        run: python3 scripts/check_transport_stability_invariants.py\n'''
    if "Audit transport stability invariants" not in text:
        if marker not in text:
            raise SystemExit(f"{workflow}: seek invariant marker missing")
        p.write_text(text.replace(marker, addition, 1))

p = Path("scripts/check_transport_v3_invariants.py")
text = p.read_text()
text = text.replace('require("cancelSlot(0, reason: \\"real-seek-demand\\")" in unified, "true user seek must still be able to retarget slot 0")', 'require("cancelSlot(0, reason: \\"real-seek-demand\\")" not in unified, "ordinary user seeks must preserve the warmed sequential slot")')
text = text.replace('MARKETING_VERSION: "0.11.1"', 'MARKETING_VERSION: "0.11.2"')
text = text.replace('project marketing version must be 0.11.1', 'project marketing version must be 0.11.2')
text = text.replace('CURRENT_PROJECT_VERSION: "55"', 'CURRENT_PROJECT_VERSION: "56"')
text = text.replace('project build number must be 55', 'project build number must be 56')
text = text.replace('<string>0.11.1</string>', '<string>0.11.2</string>')
text = text.replace('<string>55</string>', '<string>56</string>')
text = text.replace('sourceVersion = "0.11.1"', 'sourceVersion = "0.11.2"')
text = text.replace('IPA_NAME="EmbyPlayerLab-0.11.1-${GITHUB_SHA::7}-unsigned.ipa"', 'IPA_NAME="EmbyPlayerLab-0.11.2-${GITHUB_SHA::7}-unsigned.ipa"')
text = text.replace('unsigned IPA filename must identify v0.11.1', 'unsigned IPA filename must identify v0.11.2')
if 'Audit transport stability invariants' not in text:
    marker = 'require("Audit seek stall invariants" in build_workflow and "check_seek_stall_invariants.py" in build_workflow, "unsigned IPA build must enforce seek stall invariants")\n'
    addition = marker + 'require("Audit transport stability invariants" in validate_workflow and "check_transport_stability_invariants.py" in validate_workflow, "Validate Source must enforce transport stability invariants")\nrequire("Audit transport stability invariants" in build_workflow and "check_transport_stability_invariants.py" in build_workflow, "unsigned IPA build must enforce transport stability invariants")\n'
    if marker not in text:
        raise SystemExit("v3 invariant workflow marker missing")
    text = text.replace(marker, addition, 1)
p.write_text(text)

print("v0.11.2 finalization applied")
