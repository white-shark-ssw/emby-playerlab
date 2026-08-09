from pathlib import Path
import json

VERSION = "0.13.2"
BUILD = "68"


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, got {count}")
    return text.replace(old, new, 1)


# Active Emby shell: fix selected search icon, show every media library, keep header outside vertical scroll.
root_path = Path("Sources/UI/EmbyServerRootViewV2.swift")
root = root_path.read_text()
root = replace_once(root, 'Image(systemName: selectedTab == tab ? systemImage + ".fill" : systemImage)', 'Image(systemName: selectedTab == tab && tab != .search ? systemImage + ".fill" : systemImage)', "search tab icon")
root = replace_once(root, '''        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        Color.clear.frame(height: 1).id("v2-home-top")
                        header
''', '''        NavigationView {
            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            Color.clear.frame(height: 1).id("v2-home-top")
''', "home header opening")
root = replace_once(root, '''                .onChange(of: scrollToTopToken) { _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("v2-home-top", anchor: .top) }
                }
            }
            .navigationBarHidden(true)
''', '''                    .onChange(of: scrollToTopToken) { _ in
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("v2-home-top", anchor: .top) }
                    }
                }
            }
            .navigationBarHidden(true)
''', "home header closing")
root = root.replace("ForEach(model.libraries.prefix(6))", "ForEach(model.libraries)")
root = root.replace("for library in views.prefix(6) {", "for library in views {")
require(".prefix(6)" not in root, "home must not truncate libraries")
root = replace_once(root, '''        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func sectionTitle''', '''        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private func sectionTitle''', "home header spacing")
root_path.write_text(root)


# First-level server page: remove unused outer NavigationView which adds top inset.
server_path = Path("Sources/UI/ServerListView.swift")
server = server_path.read_text()
server = replace_once(server, '''    var body: some View {
        NavigationView {
            ScrollView {
''', '''    var body: some View {
        ScrollView {
''', "server nav opening")
server = replace_once(server, '''            .fullScreenCover(item: $selectedSession, onDismiss: { sessionStore.leaveServer() }) { stored in
                EmbyServerRootViewV2(session: stored)
                    .environmentObject(sessionStore)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
''', '''        .fullScreenCover(item: $selectedSession, onDismiss: { sessionStore.leaveServer() }) { stored in
            EmbyServerRootViewV2(session: stored)
                .environmentObject(sessionStore)
        }
    }
''', "server nav closing")
server = server.replace("VStack(alignment: .leading, spacing: 18)", "VStack(alignment: .leading, spacing: 14)", 1)
server = server.replace(".padding(.top, 8)", ".padding(.top, 0)", 1)
server_path.write_text(server)


# System identity: product itself must be OS player, not only the Info.plist labels.
project_path = Path("project.yml")
project = project_path.read_text()
project = project.replace('MARKETING_VERSION: "0.13.1"', 'MARKETING_VERSION: "0.13.2"')
project = project.replace('CURRENT_PROJECT_VERSION: "67"', 'CURRENT_PROJECT_VERSION: "68"')
project = replace_once(project, "        PRODUCT_NAME: EmbyPlayerLab\n", '        PRODUCT_NAME: "OS player"\n        PRODUCT_MODULE_NAME: EmbyPlayerLab\n', "product name")
project = replace_once(project, "        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon\n", "        ASSETCATALOG_COMPILER_APPICON_NAME: OSPlayerIcon\n", "icon asset set")
project_path.write_text(project)

info_path = Path("Config/Info.plist")
info = info_path.read_text().replace("<string>0.13.1</string>", "<string>0.13.2</string>").replace("<string>67</string>", "<string>68</string>")
require("<key>CFBundleDisplayName</key>\n\t<string>OS player</string>" in info, "display name must stay OS player")
require("<key>CFBundleName</key>\n\t<string>OS player</string>" in info, "bundle name must stay OS player")
info_path.write_text(info)

identity_path = Path("Sources/Core/AppIdentity.swift")
identity = identity_path.read_text().replace('sourceVersion = "0.13.1"', 'sourceVersion = "0.13.2"').replace('?? "0.13.1"', '?? "0.13.2"')
identity_path.write_text(identity)


# New physical AppIcon set name so iOS/TrollStore cannot keep using the prior AppIcon cache key.
source_contents = json.loads(Path("Resources/Assets.xcassets/AppIcon.appiconset/Contents.json").read_text())
new_dir = Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset")
new_dir.mkdir(parents=True, exist_ok=True)
new_images = []
for image in source_contents.get("images", []):
    filename = image.get("filename")
    if not filename:
        continue
    suffix = filename
    if suffix.startswith("OSIcon-v0131-"):
        suffix = suffix[len("OSIcon-v0131-"):]
    elif suffix.startswith("Icon-"):
        suffix = suffix[len("Icon-"):]
    new_image = dict(image)
    new_image["filename"] = "OSPlayer-v0132-" + suffix
    new_images.append(new_image)
require(len(new_images) == 18, f"expected 18 icon definitions, got {len(new_images)}")
(new_dir / "Contents.json").write_text(json.dumps({"images": new_images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

version_script = '''from pathlib import Path\nimport json\nimport shutil\n\n\ndef main() -> None:\n    source_dir = Path("Resources/Assets.xcassets/AppIcon.appiconset")\n    target_dir = Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset")\n    contents = json.loads((target_dir / "Contents.json").read_text())\n    copied = 0\n    for image in contents.get("images", []):\n        target_name = image.get("filename")\n        if not target_name:\n            continue\n        if not target_name.startswith("OSPlayer-v0132-"):\n            raise SystemExit(f"unexpected target icon name: {target_name}")\n        suffix = target_name[len("OSPlayer-v0132-"):]\n        source = source_dir / ("Icon-" + suffix)\n        if not source.exists():\n            raise SystemExit(f"missing generated source icon: {source}")\n        target = target_dir / target_name\n        shutil.copyfile(source, target)\n        copied += 1\n    if copied != 18:\n        raise SystemExit(f"expected 18 app icon files, copied {copied}")\n    print(f"OS player v0.13.2 icon assets prepared: {copied}")\n\n\nif __name__ == "__main__":\n    main()\n'''
Path("scripts/version_os_player_icons.py").write_text(version_script)


# Keep v0.13.1 checks structural and add current-version regression checks.
v131 = '''from pathlib import Path\n\n\ndef require(condition: bool, message: str) -> None:\n    if not condition:\n        raise SystemExit(f"v0.13.1 UI regression failed: {message}")\n\nserver_list = Path("Sources/UI/ServerListView.swift").read_text()\nserver_root = Path("Sources/UI/EmbyServerRootViewV2.swift").read_text()\nshell = Path("Sources/UI/AppShellView.swift").read_text()\ninfo = Path("Config/Info.plist").read_text()\nidentity = Path("Sources/Core/AppIdentity.swift").read_text()\nproject = Path("project.yml").read_text()\nvalidate = Path(".github/workflows/validate-source.yml").read_text()\nbuild = Path(".github/workflows/build-unsigned-ipa.yml").read_text()\n\nrequire("EmbyServerRootViewV2(session: stored)" in server_list, "server list must open the full-height v0.13.1 shell")\nrequire(".frame(maxWidth: .infinity, maxHeight: .infinity)" in server_root, "server content must fill all space above bottom tabs")\nrequire("ScrollViewReader" in server_root and ".refreshable { await model.refresh() }" in server_root, "home must use native iOS 15 scroll/refresh")\nrequire('proxy.scrollTo("v2-home-top", anchor: .top)' in server_root, "home scroll-to-top missing")\nrequire("RefreshableScrollView(" not in server_root, "old bounded UIKit wrapper must not return")\nrequire(".font(.system(size: 40" not in server_root and ".font(.system(size: 44" not in server_root, "oversized fixed title returned")\nrequire(".font(.system(size: 44" not in server_list and ".font(.system(size: 44" not in shell, "oversized outer title returned")\nrequire("<key>CFBundleDisplayName</key>\\n\\t<string>OS player</string>" in info, "display name mismatch")\nrequire("<key>CFBundleName</key>\\n\\t<string>OS player</string>" in info, "bundle name mismatch")\nrequire('static let clientName = "OS player"' in identity, "client identity mismatch")\nrequire('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")\nfor workflow in [validate, build]:\n    require("check_v0131_ui_regressions.py" in workflow, "v0.13.1 UI audit missing")\nprint("v0.13.1 UI regressions: OK")\n'''
Path("scripts/check_v0131_ui_regressions.py").write_text(v131)

v132 = '''from pathlib import Path\nimport json\n\n\ndef require(condition: bool, message: str) -> None:\n    if not condition:\n        raise SystemExit(f"v0.13.2 UI regression failed: {message}")\n\nserver_list = Path("Sources/UI/ServerListView.swift").read_text()\nserver_root = Path("Sources/UI/EmbyServerRootViewV2.swift").read_text()\nproject = Path("project.yml").read_text()\ninfo = Path("Config/Info.plist").read_text()\nidentity = Path("Sources/Core/AppIdentity.swift").read_text()\nicons = json.loads(Path("Resources/Assets.xcassets/OSPlayerIcon.appiconset/Contents.json").read_text())\nvalidate = Path(".github/workflows/validate-source.yml").read_text()\nbuild = Path(".github/workflows/build-unsigned-ipa.yml").read_text()\n\nrequire('PRODUCT_NAME: "OS player"' in project, "built product name must be OS player")\nrequire("PRODUCT_MODULE_NAME: EmbyPlayerLab" in project, "Swift module name must stay stable")\nrequire("ASSETCATALOG_COMPILER_APPICON_NAME: OSPlayerIcon" in project, "OSPlayerIcon must be active")\nfilenames = [image.get("filename", "") for image in icons.get("images", []) if image.get("filename")]\nrequire(len(filenames) == 18 and all(name.startswith("OSPlayer-v0132-") for name in filenames), "all 18 icon slots must use the new asset key")\nrequire('selectedTab == tab && tab != .search ? systemImage + ".fill" : systemImage' in server_root, "search tab must keep magnifyingglass")\nrequire(".prefix(6)" not in server_root, "home must not truncate media libraries")\nrequire("VStack(spacing: 0) {\\n                header\\n                ScrollViewReader" in server_root, "home header must be outside vertical scroll")\nrequire("NavigationView {\\n            ScrollView" not in server_list, "server page must not keep extra navigation inset")\nrequire(project.count('MARKETING_VERSION: "0.13.2"') == 2 and project.count('CURRENT_PROJECT_VERSION: "68"') == 2, "project version/build mismatch")\nrequire("<string>0.13.2</string>" in info and "<string>68</string>" in info, "Info.plist version/build mismatch")\nrequire('sourceVersion = "0.13.2"' in identity, "AppIdentity version mismatch")\nfor workflow in [validate, build]:\n    require("check_v0132_ui_regressions.py" in workflow, "v0.13.2 UI audit missing")\n    require("version_os_player_icons.py" in workflow, "new icon copy stage missing")\nrequire('IPA_NAME="EmbyPlayerLab-0.13.2-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename mismatch")\nrequire('RELEASE_TAG="v0.13.2-build68-dev"' in build, "release tag mismatch")\nrequire('RELEASE_IPA="OS-player-v0.13.2-build68-${GITHUB_SHA::7}-unsigned.ipa"' in build, "release IPA mismatch")\nrequire('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")\nprint("v0.13.2 UI regressions: OK")\n'''
Path("scripts/check_v0132_ui_regressions.py").write_text(v132)


# Workflows: add current audit and bump release/build metadata.
for workflow_path in [Path(".github/workflows/build-unsigned-ipa.yml"), Path(".github/workflows/validate-source.yml")]:
    wf = workflow_path.read_text()
    anchor = "      - name: Audit v0.13.1 UI regressions\n        run: python3 scripts/check_v0131_ui_regressions.py\n"
    if "Audit v0.13.2 UI regressions" not in wf:
        require(anchor in wf, f"missing audit anchor in {workflow_path}")
        wf = wf.replace(anchor, anchor + "\n      - name: Audit v0.13.2 UI regressions\n        run: python3 scripts/check_v0132_ui_regressions.py\n", 1)
    wf = wf.replace("0.13.1", "0.13.2").replace("build67", "build68").replace("Build 67", "Build 68").replace('"build":67', '"build":68')
    workflow_path.write_text(wf)

require('PRODUCT_NAME: "OS player"' in project_path.read_text(), "product name patch failed")
require(".prefix(6)" not in root_path.read_text(), "library patch failed")
print("v0.13.2 UI fixes applied")
