from pathlib import Path
import re

# TECHNICAL_DECISIONS: Add Emby already owns D014; detail becomes D015.
path = Path('docs/project/TECHNICAL_DECISIONS.md')
text = path.read_text()
old = '## D014 — Detail episode browsing separates selection from playback and keeps one selected-episode owner'
new = '## D015 — Detail episode browsing separates selection from playback and keeps one selected-episode owner'
if text.count(old) != 1:
    raise SystemExit(f'detail D014 match count={text.count(old)}')
if '## D015 —' in text:
    raise SystemExit('D015 already occupied')
text = text.replace(old, new, 1)
path.write_text(text)

# BUILD_TEST_INDEX: Build192 is still pending; it now sits on top of accepted Build191, not Build184.
path = Path('docs/project/BUILD_TEST_INDEX.md')
text = path.read_text()
lines = text.splitlines()
indices = [i for i, line in enumerate(lines) if line.startswith('| **Build192 / 0.14.25** |')]
if len(indices) != 1:
    raise SystemExit(f'Build192 index row count={len(indices)}')
i = indices[0]
if 'does not replace Build184' not in lines[i]:
    raise SystemExit('Build192 stale-baseline phrase changed unexpectedly')
lines[i] = lines[i].replace('does not replace Build184', 'does not replace Build191')
text = '\n'.join(lines) + ('\n' if text.endswith('\n') else '')
path.write_text(text)

# PROJECT_STATE: preserve Build192 evidence, only update its baseline reference after Build191 acceptance.
path = Path('docs/project/PROJECT_STATE.md')
text = path.read_text()
pattern = re.compile(r'(?m)^Build192 / OnePlayer 0\.14\.25 is.*?(?=\n\n|\Z)', re.S)
matches = list(pattern.finditer(text))
if len(matches) != 1:
    raise SystemExit(f'PROJECT_STATE Build192 paragraph count={len(matches)}')
paragraph = matches[0].group(0)
if 'accepted baseline remains Build184' not in paragraph:
    raise SystemExit('PROJECT_STATE Build192 stale-baseline phrase changed unexpectedly')
paragraph = paragraph.replace('accepted baseline remains Build184', 'accepted baseline is Build191; Build192 must resync with Build191 before final integration')
m = matches[0]
text = text[:m.start()] + paragraph + text[m.end():]
path.write_text(text)
