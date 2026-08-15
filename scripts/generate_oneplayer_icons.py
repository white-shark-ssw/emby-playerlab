#!/usr/bin/env python3
from pathlib import Path
import base64
import json
import shutil
import subprocess
import tempfile

SOURCE_PARTS = {
    "OnePlayerIcon": "OnePlayerDefault384.b64.*",
    "OnePlayerAltIcon": "OnePlayerAlternate384.b64.*",
}

PIXELS = {
    "20@2x": 40, "20@3x": 60, "29@2x": 58, "29@3x": 87,
    "40@2x": 80, "40@3x": 120, "60@2x": 120, "60@3x": 180,
    "20-ipad@1x": 20, "20-ipad@2x": 40, "29-ipad@1x": 29, "29-ipad@2x": 58,
    "40-ipad@1x": 40, "40-ipad@2x": 80, "76@1x": 76, "76@2x": 152,
    "83.5@2x": 167, "1024": 1024,
}

ICON_PREFIXES = {"OnePlayerIcon": "OnePlayer", "OnePlayerAltIcon": "OnePlayerAlt"}


def resize(source: Path, target: Path, pixels: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["/usr/bin/sips", "-s", "format", "png", "-z", str(pixels), str(pixels), str(source), "--out", str(target)], check=True, stdout=subprocess.DEVNULL)
    if not target.is_file() or target.stat().st_size == 0:
        raise SystemExit(f"failed to generate {target}")


def decoded_source(pattern: str, target: Path) -> Path:
    parts = sorted(Path("scripts/assets").glob(pattern))
    if len(parts) != 2:
        raise SystemExit(f"expected exactly 2 OnePlayer icon source parts for {pattern}, got {len(parts)}")
    payload = "".join(part.read_text().strip() for part in parts)
    try:
        decoded = base64.b64decode(payload, validate=True)
    except Exception as exc:
        raise SystemExit(f"invalid OnePlayer icon source base64 for {pattern}: {exc}")
    target.write_bytes(decoded)
    if target.stat().st_size == 0:
        raise SystemExit(f"decoded icon source is empty: {pattern}")
    return target


def main() -> None:
    # The legacy OSPlayerIcon set references CI-generated files. OnePlayer builds use
    # the new complete primary + alternate icon sets instead.
    shutil.rmtree(Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset"), ignore_errors=True)

    with tempfile.TemporaryDirectory() as temp_dir:
        temp = Path(temp_dir)
        sources = {
            "OnePlayerIcon": decoded_source(SOURCE_PARTS["OnePlayerIcon"], temp / "oneplayer-default.jpg"),
            "OnePlayerAltIcon": decoded_source(SOURCE_PARTS["OnePlayerAltIcon"], temp / "oneplayer-alternate.jpg"),
        }

        for icon_name, source in sources.items():
            icon_dir = Path(f"Resources/Assets.xcassets/{icon_name}.appiconset")
            contents_path = icon_dir / "Contents.json"
            if not contents_path.is_file():
                raise SystemExit(f"missing {icon_name} Contents.json")
            contents = json.loads(contents_path.read_text())
            expected = {image["filename"] for image in contents.get("images", []) if image.get("filename")}
            if len(expected) != 18:
                raise SystemExit(f"{icon_name} must define 18 icon slots, got {len(expected)}")
            generated = set()
            prefix = ICON_PREFIXES[icon_name]
            for suffix, pixels in PIXELS.items():
                filename = f"{prefix}-{suffix}.png"
                if filename not in expected:
                    raise SystemExit(f"{icon_name} Contents.json does not reference {filename}")
                resize(source, icon_dir / filename, pixels)
                generated.add(filename)
            if generated != expected:
                raise SystemExit(f"{icon_name} generated filenames do not match Contents.json")
            print(f"{icon_name} generated: {len(generated)}")

        resize(sources["OnePlayerIcon"], Path("Resources/Assets.xcassets/OnePlayerDefaultPreview.imageset/OnePlayerDefaultPreview.png"), 256)
        resize(sources["OnePlayerAltIcon"], Path("Resources/Assets.xcassets/OnePlayerAlternatePreview.imageset/OnePlayerAlternatePreview.png"), 256)
        print("OnePlayer settings icon previews generated: 2")


if __name__ == "__main__":
    main()
