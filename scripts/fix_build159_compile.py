from pathlib import Path
import subprocess

coordinator_path = Path("Sources/UI/PlayerPiPSessionCoordinator.swift")
text = coordinator_path.read_text()
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
coordinator_path.write_text(text)

surface_path = Path("Sources/UI/MPVPlayerSurface.swift")
surface = surface_path.read_text()
surface = surface.replace('String(format: \\"%.2f\\", scale)', 'String(format: "%.2f", scale)')
remaining_surface = [line for line in surface.splitlines() if 'String(format: \\"' in line]
if remaining_surface:
    raise SystemExit("Build159 surface escaped-quote compile issue remains:\n" + "\n".join(remaining_surface))
surface_path.write_text(surface)
subprocess.run(["git", "add", "Sources/UI/MPVPlayerSurface.swift"], check=True)
print("Build159 Swift interpolation compile strings fixed")
