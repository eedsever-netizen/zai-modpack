#!/usr/bin/env python3
"""Скачивание 8 зависимостей модпака (не входят в торрент).

flib, informatron, gizmod, aai-containers, aai-signal-transmission,
alien-biomes, alien-biomes-graphics, robot_attrition.
"""
import hashlib, json, os, sys, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path
from typing import Any

ROOT = Path("/home/z/my-project")
MODS_DIR = ROOT / "download" / "mods"
PORTAL_DATA = ROOT / "portal_data"
REPORT_PATH = PORTAL_DATA / "deps_report.json"
API_BASE = "https://mods.factorio.com/api/mods"
DL_BASE = "https://mods.factorio.com"
TARGET_FV = "2.1"

DEPS = ["flib", "informatron", "gizmod", "aai-containers",
        "aai-signal-transmission", "alien-biomes",
        "alien-biomes-graphics", "robot_attrition"]

def _auth():
    u = os.environ.get("FACTORIO_USER"); t = os.environ.get("FACTORIO_TOKEN")
    if not u or not t: raise SystemExit("[ERR] нужны FACTORIO_USER и FACTORIO_TOKEN")
    return urllib.parse.urlencode({"username": u, "token": t})

def _http_get(url, timeout, tag):
    last = None
    for a in range(1, 4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "zai-modpack-builder/1.0", "Accept": "*/*"})
            with urllib.request.urlopen(req, timeout=timeout) as r: return r.read()
        except urllib.error.HTTPError as e:
            last = e
            if e.code == 404: raise
            if a < 3: time.sleep(5*a)
        except Exception as e:
            last = e
            if a < 3: time.sleep(5*a)
    raise last

def _sha1_file(p):
    h = hashlib.sha1()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1<<20), b""): h.update(chunk)
    return h.hexdigest()

def _pick_release(releases):
    if not releases: return None
    for r in releases:
        if (r.get("info_json") or {}).get("factorio_version") == TARGET_FV: return r
    for r in releases:
        if (r.get("info_json") or {}).get("factorio_version", "").startswith("2."): return r
    return releases[0]

def main():
    MODS_DIR.mkdir(parents=True, exist_ok=True); PORTAL_DATA.mkdir(parents=True, exist_ok=True)
    auth = _auth()
    results, ok, failed, not_found = [], 0, 0, 0
    for name in DEPS:
        result = {"name": name, "status": None, "detail": None,
                  "version": None, "filename": None, "sha1": None, "size_bytes": None}
        try:
            data = json.loads(_http_get(f"{API_BASE}/{urllib.parse.quote(name)}", 30, f"api {name}"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                result["status"] = "not_found_on_portal"; result["detail"] = "API 404"
                not_found += 1; print(f"[DEP] {name} — 404"); results.append(result); continue
            result["status"] = "api_error"; result["detail"] = f"HTTP {e.code}"
            failed += 1; print(f"[DEP] {name} — API err"); results.append(result); continue
        release = _pick_release(data.get("releases", []))
        if release is None:
            result["status"] = "no_releases"; failed += 1
            print(f"[DEP] {name} — нет releases"); results.append(result); continue
        version = release.get("version")
        filename = release.get("file_name") or f"{name}_{version}.zip"
        sha1_expected = release.get("sha1")
        fv = (release.get("info_json") or {}).get("factorio_version", "?")
        result["version"] = version; result["filename"] = filename; result["factorio_version"] = fv
        dest = MODS_DIR / filename
        if dest.exists():
            existing = _sha1_file(dest)
            if sha1_expected and existing.lower() == sha1_expected.lower():
                result["status"] = "skipped_exists"; result["sha1"] = existing
                ok += 1; print(f"[DEP] {name} v{version} (fv={fv}) — skip")
                results.append(result); continue
            dest.unlink()
        try:
            body = _http_get(f"{DL_BASE}{release['download_url']}?{auth}", 300, f"dl {name}")
        except Exception as e:
            result["status"] = "download_error"; result["detail"] = f"{type(e).__name__}: {e}"
            failed += 1; print(f"[DEP] {name} — dl err: {e}"); results.append(result); continue
        dest.write_bytes(body)
        actual = _sha1_file(dest); sz = dest.stat().st_size
        result["sha1"] = actual; result["size_bytes"] = sz
        if sha1_expected and actual.lower() != sha1_expected.lower():
            result["status"] = "sha1_mismatch"; failed += 1; print(f"[DEP] {name} — SHA1 mismatch")
        else:
            result["status"] = "ok"; ok += 1; print(f"[DEP] {name} v{version} (fv={fv}) — OK ({sz} байт)")
        results.append(result)
    report = {"total_requested": len(DEPS), "ok": ok, "failed": failed,
              "not_found": not_found, "results": results}
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n=== DEPS ИТОГ: ok={ok} failed={failed} not_found={not_found} ===")
    return 0 if failed == 0 and not_found == 0 else 2

if __name__ == "__main__":
    sys.exit(main())
