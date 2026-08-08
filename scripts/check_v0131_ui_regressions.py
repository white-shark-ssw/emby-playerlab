from pathlib import Path
import json


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.13.1 UI regression failed: {message}")


server_list = Path("Sources/UI/ServerListView.swift").read_text()
server_root = Path("Sources/UI/EmbyServerRootViewV2.swift").read_text()
shell = Path("Sources/UI/AppShellView.swift").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
project = Path("project.yml").read_text()
validate = Path(".github/workflows/validate-source.yml").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()
icons = json.loads(Path("Resources/Assets.xcassets/AppIcon.appiconset/Contents.json").read_text())

require("EmbyServerRootViewV2(session: stored)" in server_list, "server list must open the full-height v0.13.1 shell")
require(".frame(maxWidth: .infinity, maxHeight: .infinity)" in server_root, "server content must fill all space above the bottom tabs")
require("ScrollViewReader" in server_root and ".refreshable { await model.refresh() }" in server_root, "home must use native iOS 15 scrolling and pull-to-refresh")
require('proxy.scrollTo("v2-home-top", anchor: .top)' in server_root, "home tab scroll-to-top behavior missing")
require("RefreshableScrollView(" not in server_root, "bounded UIKit refresh wrapper must not return to the active shell")
require(".font(.system(size: 40" not in server_root and ".font(.system(size: 44" not in server_root, "oversized fixed page title returned")
require(".font(.system(size: 44" not in server_list and ".font(.system(size: 44" not in shell, "oversized outer-shell title returned")
require("<key>CFBundleDisplayName</key>\n\t<string>OS player</string>" in info, "display name mismatch")
require("<key>CFBundleName</key>\n\t<string>OS player</string>" in info, "bundle name mismatch")
require('static let clientName = "OS player"' in identity, "Emby client identity mismatch")
require(project.count('MARKETING_VERSION: "0.13.1"') == 2, "marketing version mismatch")
require(project.count('CURRENT_PROJECT_VERSION: "67"') == 2, "build number mismatch")
require("<string>0.13.1</string>" in info and "<string>67</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.13.1"' in identity, "AppIdentity source version mismatch")
filenames = [image.get("filename", "") for image in icons.get("images", []) if image.get("filename")]
require(len(filenames) == 18 and all(name.startswith("OSIcon-v0131-") for name in filenames), "all icon slots must use fresh v0.13.1 filenames")
require(Path("scripts/version_os_player_icons.py").exists(), "versioned icon preparation script missing")
for workflow in [validate, build]:
    require("check_v0131_ui_regressions.py" in workflow, "v0.13.1 UI audit missing from workflow")
    require("version_os_player_icons.py" in workflow, "fresh icon preparation missing from workflow")
require('IPA_NAME="EmbyPlayerLab-0.13.1-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename mismatch")
require('RELEASE_TAG="v0.13.1-build67-dev"' in build, "release tag mismatch")
require('RELEASE_IPA="OS-player-v0.13.1-build67-${GITHUB_SHA::7}-unsigned.ipa"' in build, "release IPA mismatch")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")

print("v0.13.1 UI regressions: OK")
