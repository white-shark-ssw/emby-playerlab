from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
replace_once(engine_path, 'message: "MDK native prepare timeout"', 'message: "MDK native isolation prepare timeout"')
replace_once(engine_path, 'message: "MDK native first frame timeout"', 'message: "MDK native isolation first frame timeout"')

engine = Path(engine_path).read_text()
assert 'MDK native isolation prepare timeout' in engine
assert 'MDK native isolation first frame timeout' in engine
print("Build103 MDK watchdog failures routed to existing isolation fallback")
