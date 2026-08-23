from pathlib import Path

path = Path("Sources/UI/PlayerPiPSessionCoordinator.swift")
text = path.read_text()
replacements = {
    'String(format: \\"%.3f\\",': 'String(format: "%.3f",',
    '?? \\"unknown\\"': '?? "unknown"',
    '? \\"none\\" : \\"engine-or-surface\\"': '? "none" : "engine-or-surface"',
}
for old, new in replacements.items():
    text = text.replace(old, new)
remaining = [line for line in text.splitlines() if '\\"' in line and ('String(format:' in line or '?? ' in line or 'engine-or-surface' in line)]
if remaining:
    raise SystemExit("Build159 coordinator escaped-quote compile issue remains:\n" + "\n".join(remaining))
path.write_text(text)
print("Build159 coordinator compile strings fixed")
