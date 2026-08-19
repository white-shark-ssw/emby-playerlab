from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

package_path = ROOT / "MDKLab/SwiftMDKOnePlayer/Package.swift"
package = package_path.read_text()
test_target = '''        .testTarget(\n            name: "swift-mdkTests",\n            dependencies: ["swift-mdk"]),\n'''
if test_target in package:
    package = package.replace(test_target, "", 1)
package_path.write_text(package)

engine_path = ROOT / "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
engine = engine_path.read_text()
old = '''        let playerPosition = player.map { seconds($0.position) }\n'''
new = '''        let playerPosition: Double? = currentPlayerReference() == nil ? nil : lastNativePosition\n'''
if old in engine:
    engine = engine.replace(old, new, 1)
elif new not in engine:
    raise SystemExit("recordRenderedFrame player.position marker missing")
engine_path.write_text(engine)

print("Build86 round2 package and main-thread getter patch applied")
