from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.13.1 UI regression failed: {message}")


server_list = Path("Sources/UI/ServerListView.swift").read_text()
server_root = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
shell = Path("Sources/UI/AppShellView.swift").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
project = Path("project.yml").read_text()
validate = Path(".github/workflows/validate-source.yml").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()

require("EmbyServerRootViewV3(session: stored)" in server_list, "server list must open the current full-height shell")
require(".frame(maxWidth: .infinity, maxHeight: .infinity)" in server_root, "server content must fill all space above the bottom tabs")
require("ScrollViewReader" in server_root and ".refreshable { await model.refresh() }" in server_root, "home must use native iOS 15 scrolling and pull-to-refresh")
require('proxy.scrollTo("v3-home-top", anchor: .top)' in server_root, "home tab scroll-to-top behavior missing")
require("RefreshableScrollView(" not in server_root, "bounded UIKit refresh wrapper must not return to the active shell")
require(".font(.system(size: 40" not in server_root and ".font(.system(size: 44" not in server_root, "oversized fixed page title returned")
require(".font(.system(size: 44" not in server_list and ".font(.system(size: 44" not in shell, "oversized outer-shell title returned")
require("<key>CFBundleDisplayName</key>\n\t<string>OS player</string>" in info, "display name mismatch")
require("<key>CFBundleName</key>\n\t<string>OS player</string>" in info, "bundle name mismatch")
require('static let clientName = "OS player"' in identity, "Emby client identity mismatch")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
for workflow in [validate, build]:
    require("check_v0131_ui_regressions.py" in workflow, "v0.13.1 UI audit missing from workflow")

print("v0.13.1 UI regressions: OK")
