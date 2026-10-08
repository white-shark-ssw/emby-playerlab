import hashlib, json, plistlib, re, struct, subprocess, zipfile
from pathlib import Path
artifact = Path("Build303-artifact.zip")
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(artifact) == "2f6813ee13a5f015ab1543f63a4f97d68a8f567570792c44436842b4526e2a94"
out = Path("verified303"); out.mkdir(exist_ok=True)
with zipfile.ZipFile(artifact) as z:
    assert z.testzip() is None
    assert all(not Path(p).is_absolute() and ".." not in Path(p).parts for p in z.namelist())
    z.extractall(out)
ipa = out / "OnePlayer-0.15.36-build303-poster-sections-unsigned.ipa"
source = out / "OnePlayer-0.15.36-build303-poster-sections-source.zip"
for p in [ipa, source]:
    assert digest(p) == Path(str(p) + ".sha256").read_text().split()[0]
assert digest(ipa) == "b3ebb081dcbe1e20de02565faaa6e5f4d67891922c6f0d55248bf7cd959842de"
assert digest(source) == "bacf2ac724a1fd2b3971d54a51d670c4662a056a8f0f2227a4ed41f0dddd5dd2"
product = "0b5ce25bcec0a4d0240891913ad17114b02cf10e"
baseline = "dced392bbf2e3960539890121cf7d6e9d8f80e86"
gitfile = lambda commit, path: subprocess.check_output(["git", "cat-file", "blob", commit + ":" + path])
allowed = {"Sources/Core/AppIdentity.swift", "Sources/UI/EmbyHomeCoreV3.swift", "Sources/UI/EmbyPosterSections.swift", "Sources/UI/EmbySearchExperienceV3.swift", "Sources/UI/EmbyServerBrowseV3.swift"}
with zipfile.ZipFile(source) as z:
    assert z.testzip() is None
    assert z.comment.decode() == product
    verified_source_files = 0
    for path in z.namelist():
        if path.endswith("/"): continue
        assert z.read(path) == gitfile(product, path), path
        verified_source_files += 1
        if path.startswith("Sources/") and path not in allowed:
            assert z.read(path) == gitfile(baseline, path), path
    assert 'static let sourceVersion = "0.15.36"' in z.read("Sources/Core/AppIdentity.swift").decode()
    motion = z.read("Tests/PosterWallRegression/MotionUITests.swift").decode()
old = gitfile("1fdca1f8f2765bd1660330945e167dedecf5e418", "Tests/PosterWallRegression/MotionUITests.swift").decode()
marker = "    private func fields("
assert old.split(marker,1)[1] == motion.split(marker,1)[1]
retained = (out/"retained-build303-ui.log").read_bytes()
assert retained == gitfile("30c558e7984c682f22e92e13a3d6104ea27b7579", "ci/retained-build303-ui.log")
names = re.findall(r"    func (test\w+)\(", old.split(marker,1)[1])
assert len(names) == 10
for name in names:
    assert f"Test Case '-[PosterMotionUITests.PosterMotionUITests {name}]' passed" in retained.decode(), name
for name,count in [("fixed-native-tests.log",18),("detail-loading-tests.log",10),("poster-native-tests.log",53),("poster-motion-ui-tests.log",3)]:
    assert f"Executed {count} tests, with 0 failures" in (out/name).read_text()
for name in ["testNativeSectionPullRefreshUsesTaskCompletionWithExistingContent","testNativeSectionRowsDeepReturnAndProductTopCommand","testProductionFavoritesPreviewPersonAndMoreDestinations"]:
    assert f"Test Case '-[PosterMotionUITests.PosterMotionUITests {name}]' passed" in (out/"poster-motion-ui-tests.log").read_text()
assert "** BUILD SUCCEEDED **" in (out/"build.log").read_text()
assert "FAIL" not in (out/"min-os-report.log").read_text()
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None
    plist_path = next(p for p in z.namelist() if p.count("/") == 2 and p.endswith(".app/Info.plist"))
    info = plistlib.loads(z.read(plist_path))
    for key,value in {"CFBundleIdentifier":"com.embyplayerlab.app","CFBundleShortVersionString":"0.15.36","CFBundleVersion":"303","MinimumOSVersion":"15.0","CADisableMinimumFrameDurationOnPhone":True}.items():
        assert info[key] == value,(key,info[key])
    binary = z.read(plist_path.rsplit("/",1)[0] + "/" + info["CFBundleExecutable"])
    assert struct.unpack_from("<I",binary)[0] == 0xfeedfacf
    assert struct.unpack_from("<I",binary,4)[0] == 0x0100000c
    count = struct.unpack_from("<I",binary,16)[0]; offset = 32; minos = None
    for _ in range(count):
        command,size = struct.unpack_from("<II",binary,offset)
        if command == 0x32:
            platform,minos = struct.unpack_from("<II",binary,offset+8); assert platform == 2
        elif command == 0x25: minos = struct.unpack_from("<I",binary,offset+8)[0]
        offset += size
    assert minos == 15 << 16
report = {"verified":True,"artifact_id":11540607336,"artifact_bytes":artifact.stat().st_size,"artifact_sha256":digest(artifact),"ipa_name":ipa.name,"ipa_bytes":ipa.stat().st_size,"ipa_sha256":digest(ipa),"source_sha":product,"source_zip_sha256":digest(source),"git_archive_files_verified":verified_source_files,"version":"0.15.36","build":303,"bundle":"com.embyplayerlab.app","info_minos":"15.0","arm64_minos":"15.0.0","fresh_tests":84,"retained_ui_tests":10,"verification_location":"independent Linux Actions artifact-verification job","local_file_delivery":"pending"}
Path("build303-verification.json").write_text(json.dumps(report,indent=2)+"\n")
print("BUILD303_INDEPENDENT_ARTIFACT_VERIFIED")
print(json.dumps(report,indent=2))
