#!/usr/bin/env python3
"""Парсинг торрента v2 в карту модов {name: version}."""
import bencodepy, json, re, sys
from pathlib import Path

TORRENT_PATH = Path("/home/z/my-project/upload/необходимые моды.torrent")
OUT_PATH = Path("/home/z/my-project/scripts/torrent_mods.json")

def _dec(x):
    if isinstance(x, bytes): return x.decode("utf-8", errors="replace")
    if isinstance(x, dict):  return {_dec(k): _dec(v) for k, v in x.items()}
    if isinstance(x, list):  return [_dec(i) for i in x]
    return x

def parse_mod_filename(fn):
    if not fn.endswith(".zip"): return None
    m = re.match(r"^(.+)_(\d+(?:\.\d+)*.*)$", fn[:-4])
    return (m.group(1), m.group(2)) if m else None

def main():
    raw = TORRENT_PATH.read_bytes()
    info = _dec(bencodepy.decode(raw))["info"]
    mods = {}
    for f in info["files"]:
        if f["path"][0] == ".pad": continue
        fn = f["path"][-1]
        p = parse_mod_filename(fn)
        if not p: continue
        name, version = p
        mods[name] = {"name": name, "version": version, "filename": fn,
                      "size_bytes": f["length"],
                      "size_mb": round(f["length"]/1048576, 2)}
    OUT_PATH.write_text(json.dumps(mods, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Распознано модов: {len(mods)}")
    print(f"Сохранено: {OUT_PATH}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
