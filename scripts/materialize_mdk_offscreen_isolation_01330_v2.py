from pathlib import Path
import runpy

runpy.run_path("scripts/materialize_mdk_offscreen_isolation_01330.py", run_name="__main__")
renderer = Path("MDKLab/SwiftMDKOnePlayer/Sources/swift-mdk/MetalLayerRenderer.swift")
text = renderer.read_text()
text = text.replace("        api.layer = nil\n", "        // Keep api.layer zero-initialized: MDK renders only into currentRenderTarget's offscreen texture.\n")
renderer.write_text(text)
engine = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
engine_text = engine.read_text().replace("renderWatchdogTimer?.invalidate()", "renderWatchdogTimer?.cancel()")
engine.write_text(engine_text)
print("Build97 v2 compile fixes applied: zero-initialized MDK layer and DispatchSource watchdog cancellation")
