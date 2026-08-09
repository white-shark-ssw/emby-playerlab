from pathlib import Path
import json
import shutil


def main() -> None:
    source_dir = Path("Resources/Assets.xcassets/AppIcon.appiconset")
    target_dir = Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset")
    contents = json.loads((target_dir / "Contents.json").read_text())
    copied = 0

    for image in contents.get("images", []):
        target_name = image.get("filename")
        if not target_name:
            continue
        if not target_name.startswith("OSPlayer-v0132-"):
            raise SystemExit(f"unexpected target icon name: {target_name}")
        suffix = target_name[len("OSPlayer-v0132-"):]
        source = source_dir / ("Icon-" + suffix)
        if not source.exists():
            raise SystemExit(f"missing generated source icon: {source}")
        target = target_dir / target_name
        shutil.copyfile(source, target)
        copied += 1

    if copied != 18:
        raise SystemExit(f"expected 18 app icon files, copied {copied}")
    print(f"OS player v0.13.2 icon assets prepared: {copied}")


if __name__ == "__main__":
    main()
