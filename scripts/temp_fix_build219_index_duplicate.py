from pathlib import Path
p = Path('docs/project/BUILD_TEST_INDEX.md')
s = p.read_text()
row = '| **Build216 / 0.14.49** | Detail episode-range inertia interruption | **Target-device accepted; stable and merged.** Range-pill taps synchronously stop active native episode-row deceleration at the current offset before the accepted Build191 range-first selection and existing 0.32 s target scroll. Tested source `dc00cac9f35ee4a3b950e4bb030bb324baf90b18`; run/job `33064051545 / 98489652724`; artifact `9643031850`; IPA SHA-256 `e3054a53398e1df48134fecd8c30671e10ecaa8a93df5483936adcf10e055075`; MinOS 15.0 verified. User accepted on iPhone 15 Pro Max / iOS 17.0 on 2026-08-27; PR #261 merged at `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`. Build182/Build191/Build195/Build178 and P0 playback/transport remain untouched. |\n'
if s.count(row) != 2:
    raise SystemExit(f'expected duplicate Build216 row x2, got {s.count(row)}')
first = s.index(row)
second = s.index(row, first + len(row))
s = s[:second] + s[second + len(row):]
p.write_text(s)
print('Build216 duplicate removal: PASS')
