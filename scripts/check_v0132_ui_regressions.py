from pathlib import Path
import json


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.13.2 UI regression failed: {message}")


server_list = Path("Sources/UI/ServerListView.swift").read_text()
server_root = Path("Sources/UI/EmbyServerRootViewV2.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
icons = json.loads(Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset/Contents.json").read_text())
validate = Path(".github/workflows/validate-source.yml").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()

require('PRODUCT_NAME: "OS player"' in project, "built product name must be OS player")
require("PRODUCT_MODULE_NAME: EmbyPlayerLab" in project, "Swift module name must stay stable")
require("ASSETCATALOG_COMPILER_APPICON_NAME: OSPlayerIcon" in project, "OSPlayerIcon must be active")
filenames = [image.get("filename", "") for image in icons.get("images", []) if image.get("filename")]
require(len(filenames) == 18 and all(name.startswith("OSPlayer-v0132-") for name in filenames), "all 18 icon slots must use the new asset key")
require('selectedTab == tab && tab != .search ? systemImage + ".fill" : systemImage' in server_root, "search tab must keep magnifyingglass when selected")
require(".prefix(6)" not in server_root, "home must not truncate media libraries")
require("VStack(spacing: 0) {\n                header\n\n                ScrollViewReader" in server_root, "home header must be outside the vertical scroll")
require("NavigationView {\n            ScrollView" not in server_list, "first-level server page must not keep the extra navigation top inset")
require(project.count('MARKETING_VERSION: "0.13.2"') == 2 and project.count('CURRENT_PROJECT_VERSION: "68"') == 2, "project version/build mismatch")
require("<string>0.13.2</string>" in info and "<string>68</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.13.2"' in identity, "AppIdentity source version mismatch")
for workflow in [validate, build]:
    require("check_v0132_ui_regressions.py" in workflow, "v0.13.2 UI audit missing from workflow")
    require("version_os_player_icons.py" in workflow, "fresh icon preparation missing from workflow")
require('IPA_NAME="EmbyPlayerLab-0.13.2-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename mismatch")
require('RELEASE_TAG="v0.13.2-build68-dev"' in build, "release tag mismatch")
require('RELEASE_IPA="OS-player-v0.13.2-build68-${GITHUB_SHA::7}-unsigned.ipa"' in build, "release IPA mismatch")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")

print("v0.13.2 UI regressions: OK")
