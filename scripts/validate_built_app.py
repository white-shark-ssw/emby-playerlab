#!/usr/bin/env python3
import argparse
import plistlib
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"::error::{message}")


def read_plist(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            return plistlib.load(handle)
    except Exception as exc:
        fail(f"Cannot read plist {path}: {exc}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate only package-critical properties of a built iOS .app")
    parser.add_argument("app_path")
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()

    app = Path(args.app_path)
    if not app.is_dir():
        fail(f"Built app directory does not exist: {app}")

    info_path = app / "Info.plist"
    if not info_path.is_file():
        fail(f"Built app is missing Info.plist: {info_path}")

    info = read_plist(info_path)
    expected = {
        "CFBundleIdentifier": args.bundle_id,
        "CFBundleShortVersionString": args.version,
        "CFBundleVersion": args.build,
    }

    print(f"appPath={app}")
    print(f"infoPlist={info_path}")
    for key, value in expected.items():
        actual = str(info.get(key, ""))
        print(f"{key}={actual}")
        if actual != value:
            fail(f"{key} mismatch: expected {value!r}, got {actual!r}")

    executable = str(info.get("CFBundleExecutable", ""))
    print(f"CFBundleExecutable={executable}")
    if not executable:
        fail("CFBundleExecutable is empty")

    executable_path = app / executable
    if not executable_path.is_file():
        fail(f"CFBundleExecutable does not exist in app bundle: {executable_path}")
    print(f"executableBytes={executable_path.stat().st_size}")

    # The following fields are useful diagnostics but are not IPA packaging gates.
    # Source branding/icon configuration is checked before the build, and minimum-OS
    # compatibility is audited by check_min_os.sh in the next workflow step.
    print(f"CFBundleDisplayName={info.get('CFBundleDisplayName', '')}")
    print(f"CFBundleName={info.get('CFBundleName', '')}")
    print(f"MinimumOSVersion={info.get('MinimumOSVersion', '')}")
    print(f"CFBundlePackageType={info.get('CFBundlePackageType', '')}")

    primary_icon = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    icon_name = primary_icon.get("CFBundleIconName", "")
    icon_files = primary_icon.get("CFBundleIconFiles", [])
    assets_car = app / "Assets.car"
    loose_icons = sorted(p.name for p in app.glob("*Icon*.png"))
    print(f"iconName={icon_name}")
    print(f"iconFiles={icon_files}")
    print(f"Assets.car={'yes' if assets_car.is_file() else 'no'}")
    print(f"looseIconPNGs={len(loose_icons)}")

    if not info.get("CFBundleDisplayName"):
        print("::warning::Built Info.plist has no CFBundleDisplayName; bundle identity remains valid for packaging.")
    if not info.get("CFBundleName"):
        print("::warning::Built Info.plist has no CFBundleName; executable and bundle identity are validated separately.")
    if not icon_name and not icon_files:
        print("::warning::Built Info.plist has no primary icon metadata. Source asset configuration is validated before build.")
    if not assets_car.is_file() and not loose_icons:
        print("::warning::No Assets.car or loose icon PNGs were found at app root. This is diagnostic only.")

    print("Built app package-critical validation: OK")


if __name__ == "__main__":
    main()
