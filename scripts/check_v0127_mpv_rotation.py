from pathlib import Path

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

# Device-log regression from v0.12.6: UIKit completed rotation to 932x430 while
# MoltenVK still exposed the previous portrait 1290x2796 drawable. The repair must
# detect that orientation mismatch, while a correctly oriented drawable is untouched.
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

require(project.count('MARKETING_VERSION: "0.12.7"') == 2, "marketing version must be 0.12.7")
require(project.count('CURRENT_PROJECT_VERSION: "65"') == 2, "build number must be 65")
require("<string>0.12.7</string>" in info and "<string>65</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.7"' in identity, "AppIdentity source version mismatch")
require("Audit v0.12.7 MPV rotation regressions" in validate and "check_v0127_mpv_rotation.py" in validate, "Validate Source must enforce v0.12.7 rotation regression")
require("Audit v0.12.7 MPV rotation regressions" in build and "check_v0127_mpv_rotation.py" in build, "unsigned IPA workflow must enforce v0.12.7 rotation regression")
require('IPA_NAME="EmbyPlayerLab-0.12.7-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.7")
require('RELEASE_TAG="v0.12.7-build65-dev"' in build, "release tag mismatch")
require('RELEASE_IPA="EmbyPlayerLab-v0.12.7-build65-${GITHUB_SHA::7}-unsigned.ipa"' in build, "release IPA mismatch")

print("v0.12.7 MPV rotation regressions: OK")
