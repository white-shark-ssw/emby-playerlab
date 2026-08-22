from pathlib import Path

source_path = Path("scripts/materialize_mdk_prepare_guard_01326.py")
source = source_path.read_text()
source = source.replace("r'''", "'''")
exec(compile(source, str(source_path), "exec"))
