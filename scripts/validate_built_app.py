#!/usr/bin/env python3
import argparse
import plistlib
from pathlib import Path


def fail(message: str) -> None:
    text = f"::error::{message}"
    print(text)
    try:
        with Path("build.log").open("a", encoding="utf-8") as handle:
            handle.write(f"\n[BuiltAppValidation] {text}\n")
    except Exception:
        pass
    raise SystemExit(1)


def read_plist(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            return plistlib.load(handle)
    except Exception as exc:
        fail(f"Cannot read plist {path}: {exc}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate package-critical properties of a built iOS .app")
    parser.add_argument("app_path")
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--display-name")
    parser.add_argument("--minimum-os")
    parser.add_argument("--primary-icon")
    parser.add_argument("--alternate-icon")
    args = parser.parse_args()

    app = Path(args.app_path)
    if not app.is_dir(): fail(f"Built app directory does not exist: {app}")
    info_path = app / "Info.plist"
    if not info_path.is_file(): fail(f"Built app is missing Info.plist: {info_path}")
    info = read_plist(info_path)

    expected = {"CFBundleIdentifier": args.bundle_id, "CFBundleShortVersionString": args.version, "CFBundleVersion": args.build}
    print(f"appPath={app}")
    print(f"infoPlist={info_path}")
    for key, value in expected.items():
        actual = str(info.get(key, ""))
        print(f"{key}={actual}")
        if actual != value: fail(f"{key} mismatch: expected {value!r}, got {actual!r}")

    executable = str(info.get("CFBundleExecutable", ""))
    print(f"CFBundleExecutable={executable}")
    if not executable: fail("CFBundleExecutable is empty")
    executable_path = app / executable
    if not executable_path.is_file(): fail(f"CFBundleExecutable does not exist in app bundle: {executable_path}")
    print(f"executableBytes={executable_path.stat().st_size}")

    display_name = str(info.get("CFBundleDisplayName", ""))
    bundle_name = str(info.get("CFBundleName", ""))
    minimum_os = str(info.get("MinimumOSVersion", ""))
    print(f"CFBundleDisplayName={display_name}")
    print(f"CFBundleName={bundle_name}")
    print(f"MinimumOSVersion={minimum_os}")
    print(f"CFBundlePackageType={info.get('CFBundlePackageType', '')}")

    # System-visible identity is strict: this protects Home Screen, Settings and multitasking branding.
    if args.display_name and display_name != args.display_name: fail(f"CFBundleDisplayName mismatch: expected {args.display_name!r}, got {display_name!r}")
    if args.display_name and bundle_name and bundle_name != args.display_name: fail(f"CFBundleName mismatch: expected {args.display_name!r}, got {bundle_name!r}")
    if args.minimum_os and minimum_os != args.minimum_os:
        print(f"::warning::MinimumOSVersion differs from requested value: expected {args.minimum_os!r}, got {minimum_os!r}. check_min_os.sh owns this validation; packaging validation continues.")
    if not bundle_name: print("::warning::Built Info.plist has no CFBundleName; executable and display identity are otherwise validated.")

    primary_icon = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    icon_name = primary_icon.get("CFBundleIconName", "")
    icon_files = primary_icon.get("CFBundleIconFiles", [])
    alternate_icons = info.get("CFBundleIcons", {}).get("CFBundleAlternateIcons", {})
    assets_car = app / "Assets.car"
    loose_icons = sorted(p.name for p in app.glob("*Icon*.png"))
    print(f"iconName={icon_name}")
    print(f"iconFiles={icon_files}")
    print(f"alternateIcons={sorted(alternate_icons.keys()) if isinstance(alternate_icons, dict) else alternate_icons}")
    print(f"Assets.car={'yes' if assets_car.is_file() else 'no'}")
    print(f"looseIconPNGs={len(loose_icons)}")

    # Xcode's asset compiler owns the final CFBundleIcons structure; validate its generated output.
    if args.primary_icon and icon_name != args.primary_icon: fail(f"Primary app icon mismatch: expected {args.primary_icon!r}, got {icon_name!r}")
    if args.alternate_icon and (not isinstance(alternate_icons, dict) or args.alternate_icon not in alternate_icons):
        fail(f"Alternate app icon {args.alternate_icon!r} is missing from built CFBundleAlternateIcons")
    if not assets_car.is_file() and not loose_icons: fail("No Assets.car or loose icon PNGs were found in the built app")

    print("Built app package-critical validation: OK")


if __name__ == "__main__":
    main()
