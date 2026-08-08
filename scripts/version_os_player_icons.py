from pathlib import Path
import json
import shutil


def main() -> None:
    icon_dir = Path("Resources/Assets.xcassets/AppIcon.appiconset")
    contents = json.loads((icon_dir / "Contents.json").read_text())
    prefix = "OSIcon-v0131-"
    copied = 0

    for image in contents.get("images", []):
        target_name = image.get("filename")
        if not target_name:
            continue
        if not target_name.startswith(prefix):
            raise SystemExit(f"unexpected versioned icon name: {target_name}")
        source_name = "Icon-" + target_name[len(prefix):]
        source = icon_dir / source_name
        target = icon_dir / target_name
        if not source.exists():
            raise SystemExit(f"missing generated source icon: {source}")
        shutil.copyfile(source, target)
        copied += 1

    if copied != 18:
        raise SystemExit(f"expected 18 app icon files, copied {copied}")
    print(f"OS player versioned icon assets prepared: {copied}")


if __name__ == "__main__":
    main()
