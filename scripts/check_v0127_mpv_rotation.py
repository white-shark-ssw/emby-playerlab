from pathlib import Path
import re

surface = Path("Sources/UI/MPVPlayerSurface.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
validate = Path(".github/workflows/validate-source.yml").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.7 MPV rotation regression failed: {message}")


require("struct MPVPlayerSurface: UIViewRepresentable" in surface, "stable UIViewRepresentable host must remain")
require("UIViewControllerRepresentable" not in surface, "rotation fix must not reintroduce controller lifecycle churn")
require("displayLayer.delegate" not in surface, "rotation fix must not reintroduce CAMetalLayer delegate coupling")
require(surface.count("displayLayer.drawableSize = expectedDrawable") == 1, "drawableSize may only be repaired by the targeted orientation-sync path")
require("expectedOrientation != 0, drawableOrientation != 0, expectedOrientation != drawableOrientation" in surface, "drawable repair must require opposite host/drawable orientation")
require("repair=orientation-sync" in surface, "orientation repair diagnostics missing")
require("bounds.width * scale" in surface and "bounds.height * scale" in surface, "expected drawable must derive from actual host bounds and native scale")


def axis(width: float, height: float) -> int:
    if width <= 1 or height <= 1:
        return 0
    if width > height:
        return 1
    if height > width:
        return -1
    return 0


expected_landscape = (932 * 3, 430 * 3)
stale_portrait = (1290, 2796)
correct_landscape = (2796, 1290)
require(axis(*expected_landscape) != axis(*stale_portrait), "observed stale portrait drawable must be detected after landscape rotation")
require(axis(*expected_landscape) == axis(*correct_landscape), "correct landscape drawable must not be treated as mismatched")
expected_portrait = (430 * 3, 932 * 3)
stale_landscape = (2796, 1290)
require(axis(*expected_portrait) != axis(*stale_landscape), "reverse rotation must detect stale landscape drawable")

versions = re.findall(r'MARKETING_VERSION: "([^"]+)"', project)
builds = re.findall(r'CURRENT_PROJECT_VERSION: "([^"]+)"', project)
require(len(versions) == 2 and len(set(versions)) == 1, "marketing version must match in both project settings scopes")
require(len(builds) == 2 and len(set(builds)) == 1, "build number must match in both project settings scopes")
version = versions[0]
build_number = builds[0]
require(f"<string>{version}</string>" in info and f"<string>{build_number}</string>" in info, "Info.plist version/build mismatch")
require(f'sourceVersion = "{version}"' in identity, "AppIdentity source version mismatch")
require("Audit v0.12.7 MPV rotation regressions" in validate and "check_v0127_mpv_rotation.py" in validate, "Validate Source must enforce v0.12.7 rotation regression")
require("Audit v0.12.7 MPV rotation regressions" in build and "check_v0127_mpv_rotation.py" in build, "unsigned IPA workflow must enforce v0.12.7 rotation regression")
require(f'IPA_NAME="EmbyPlayerLab-{version}-${{GITHUB_SHA::7}}-unsigned.ipa"' in build, "IPA filename must identify the current version")
require(f'RELEASE_TAG="v{version}-build{build_number}-dev"' in build, "release tag mismatch")
require(f'OS-player-v{version}-build{build_number}-${{GITHUB_SHA::7}}-unsigned.ipa' in build, "release IPA mismatch")

print("v0.12.7 MPV rotation regressions: OK")
