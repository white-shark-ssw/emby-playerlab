#!/usr/bin/env python3
from pathlib import Path
import json
import shutil
import subprocess

SOURCES = {
    "OnePlayerIcon": Path("scripts/assets/OnePlayerDefault.jpg"),
    "OnePlayerAltIcon": Path("scripts/assets/OnePlayerAlternate.jpg"),
}

PIXELS = {
    "20@2x": 40, "20@3x": 60, "29@2x": 58, "29@3x": 87,
    "40@2x": 80, "40@3x": 120, "60@2x": 120, "60@3x": 180,
    "20-ipad@1x": 20, "20-ipad@2x": 40, "29-ipad@1x": 29, "29-ipad@2x": 58,
    "40-ipad@1x": 40, "40-ipad@2x": 80, "76@1x": 76, "76@2x": 152,
    "83.5@2x": 167, "1024": 1024,
}

ICON_SETS = {
    "OnePlayerIcon": "OnePlayer",
    "OnePlayerAltIcon": "OnePlayerAlt",
}

PREVIEWS = {
    "OnePlayerDefaultPreview.imageset/OnePlayerDefaultPreview.png": SOURCES["OnePlayerIcon"],
    "OnePlayerAlternatePreview.imageset/OnePlayerAlternatePreview.png": SOURCES["OnePlayerAltIcon"],
}


def resize(source: Path, target: Path, pixels: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["/usr/bin/sips", "-s", "format", "png", "-z", str(pixels), str(pixels), str(source), "--out", str(target)], check=True, stdout=subprocess.DEVNULL)
    if not target.is_file() or target.stat().st_size == 0:
        raise SystemExit(f"failed to generate {target}")


def main() -> None:
    # The old OSPlayerIcon set references build-generated files that are intentionally
    # not tracked. Remove that legacy set for OnePlayer builds so actool only sees
    # complete icon sets. Historical diagnostic workflows still prepare it separately.
    shutil.rmtree(Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset"), ignore_errors=True)

    for icon_name, source in SOURCES.items():
        if not source.is_file():
            raise SystemExit(f"missing OnePlayer icon source: {source}")
        icon_dir = Path(f"Resources/Assets.xcassets/{icon_name}.appiconset")
        contents_path = icon_dir / "Contents.json"
        if not contents_path.is_file():
            raise SystemExit(f"missing {icon_name} Contents.json")
        contents = json.loads(contents_path.read_text())
        expected = {image["filename"] for image in contents.get("images", []) if image.get("filename")}
        if len(expected) != 18:
            raise SystemExit(f"{icon_name} must define 18 icon slots, got {len(expected)}")
        generated = set()
        prefix = ICON_SETS[icon_name]
        for suffix, pixels in PIXELS.items():
            filename = f"{prefix}-{suffix}.png"
            if filename not in expected:
                raise SystemExit(f"{icon_name} Contents.json does not reference {filename}")
            resize(source, icon_dir / filename, pixels)
            generated.add(filename)
        if generated != expected:
            raise SystemExit(f"{icon_name} generated filenames do not match Contents.json")
        print(f"{icon_name} generated: {len(generated)}")

    for relative_path, source in PREVIEWS.items():
        resize(source, Path("Resources/Assets.xcassets") / relative_path, 256)
    print("OnePlayer settings icon previews generated: 2")


if __name__ == "__main__":
    main()
