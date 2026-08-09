from pathlib import Path
import json


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.13.2 UI regression failed: {message}")


server_list = Path("Sources/UI/ServerListView.swift").read_text()
server_root = Path("Sources/UI/EmbyServerRootViewV2.swift").read_text()
managed_home = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
icons = json.loads(Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset/Contents.json").read_text())

# This script validates v0.13.2 source/UI invariants only. It intentionally does not
# inspect GitHub Actions workflow text or built .app representation. Packaging and
# product validation are separate CI responsibilities.
require('PRODUCT_NAME: "OS player"' in project, "built product name must be OS player")
require("PRODUCT_MODULE_NAME: EmbyPlayerLab" in project, "Swift module name must stay stable")
require("ASSETCATALOG_COMPILER_APPICON_NAME: OSPlayerIcon" in project, "OSPlayerIcon must be active")
filenames = [image.get("filename", "") for image in icons.get("images", []) if image.get("filename")]
require(len(filenames) == 18 and all(name.startswith("OSPlayer-v0132-") for name in filenames), "all 18 icon slots must use the v0.13.2 asset key")
require('selectedTab == tab && tab != .search ? systemImage + ".fill" : systemImage' in server_root, "search tab must keep magnifyingglass when selected")
require(".prefix(6)" not in server_root, "legacy home must not truncate media libraries")
require("VStack(spacing: 0) {\n                header\n\n                ScrollViewReader" in server_root, "legacy home header must stay outside the vertical scroll")
require("NavigationView {\n            ScrollView" not in server_list, "first-level server page must not keep the extra navigation top inset")
require("EmbyServerRootViewV3(session: stored)" in server_list, "server entry must use the managed home root")
require("V3MediaManagementView" in managed_home and 'Text("媒体管理")' in managed_home, "media management sheet missing")
require('Text("展示")' in managed_home and 'Text("轮播图")' in managed_home, "media management columns missing")
require("showOnHome" in managed_home and "includeInCarousel" in managed_home, "independent home/carousel switches missing")
require(".onMove" in managed_home and "draft.move(fromOffsets: source, toOffset: destination)" in managed_home, "library drag ordering missing")
require("PageTabViewStyle(indexDisplayMode: .never)" in managed_home, "hero carousel paging missing")
require("Timer.publish(every: 6" in managed_home, "hero carousel auto rotation missing")
require('imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop"' in managed_home, "hero carousel backdrop fallback missing")
require("osplayer.home.library-preferences" in managed_home and "UserDefaults.standard.set" in managed_home, "server/user scoped media preferences persistence missing")
require("var visibleLibraries" in managed_home and "var carouselItems" in managed_home, "managed home library projections missing")
require('case "movies", "tvshows", "mixed", "homevideos": return true' in managed_home, "safe first-run carousel defaults missing")
require(project.count('MARKETING_VERSION: "0.13.2"') == 2 and project.count('CURRENT_PROJECT_VERSION: "68"') == 2, "project version/build mismatch")
require("<string>0.13.2</string>" in info and "<string>68</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.13.2"' in identity, "AppIdentity source version mismatch")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")

print("v0.13.2 UI regressions: OK")
