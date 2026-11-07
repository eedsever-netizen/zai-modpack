#!/usr/bin/env python3
"""Скачивание модов Factorio с официального портала.

API: GET /api/mods/{name} (без auth)
Download: GET /download/{mod}/{hash}?username=...&token=...
Auth: env FACTORIO_USER, FACTORIO_TOKEN
"""
import hashlib, json, os, sys, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path
from typing import Any

ROOT = Path("/home/z/my-project")
TORRENT_MODS = ROOT / "scripts" / "torrent_mods.json"
MODS_DIR = ROOT / "download" / "mods"
PORTAL_DATA = ROOT / "portal_data"
REPORT_PATH = PORTAL_DATA / "download_report.json"
API_BASE = "https://mods.factorio.com/api/mods"
DL_BASE = "https://mods.factorio.com"
API_TIMEOUT = 30
DL_TIMEOUT = 600

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

def _find_release(api_resp, version):
    for r in (api_resp.get("releases") or []):
        if r.get("version") == version: return r
    return None

def main():
    MODS_DIR.mkdir(parents=True, exist_ok=True); PORTAL_DATA.mkdir(parents=True, exist_ok=True)
    mods = json.loads(TORRENT_MODS.read_text(encoding="utf-8"))
    auth = _auth()
    print(f"Загружено модов из torrent_mods.json: {len(mods)}")
    results, ok, skipped, failed, not_found = [], 0, 0, 0, 0
    items = sorted(mods.values(), key=lambda x: x["name"].lower())
    for idx, mod in enumerate(items, 1):
        name, version, filename = mod["name"], mod["version"], mod["filename"]
        dest = MODS_DIR / filename
        prefix = f"[{idx}/{len(items)}] {name}_{version}"
        result = {"name": name, "version": version, "filename": filename,
                  "expected_size_bytes": mod["size_bytes"], "status": None,
                  "detail": None, "sha1": None, "portal_sha1": None, "actual_size_bytes": None}
        if dest.exists() and dest.stat().st_size == mod["size_bytes"]:
            result["status"] = "skipped_exists"
            result["sha1"] = _sha1_file(dest)
            result["detail"] = f"размер совпал ({dest.stat().st_size} байт)"
            skipped += 1; print(f"{prefix} — skip"); results.append(result); continue
        try:
            api_resp = json.loads(_http_get(f"{API_BASE}/{urllib.parse.quote(name)}", API_TIMEOUT, f"api {name}"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                result["status"] = "not_found_on_portal"; result["detail"] = "API 404"
                not_found += 1; print(f"{prefix} — 404"); results.append(result); continue
            result["status"] = "api_error"; result["detail"] = f"HTTP {e.code}"
            failed += 1; print(f"{prefix} — API err {e.code}"); results.append(result); continue
        except Exception as e:
            result["status"] = "api_error"; result["detail"] = f"{type(e).__name__}: {e}"
            failed += 1; print(f"{prefix} — API err"); results.append(result); continue
        release = _find_release(api_resp, version)
        if release is None:
            rels = api_resp.get("releases") or []
            latest = rels[0].get("version") if rels else "?"
            result["status"] = "version_mismatch"
            result["detail"] = f"запрошена {version}, latest={latest}"
            failed += 1; print(f"{prefix} — версия не найдена (latest={latest})")
            results.append(result); continue
        portal_sha1 = release.get("sha1"); result["portal_sha1"] = portal_sha1
        try:
            body = _http_get(f"{DL_BASE}{release['download_url']}?{auth}", DL_TIMEOUT, f"dl {name}")
        except Exception as e:
            result["status"] = "download_error"; result["detail"] = f"{type(e).__name__}: {e}"
            failed += 1; print(f"{prefix} — dl err: {e}"); results.append(result); continue
        dest.write_bytes(body)
        actual_sha1 = _sha1_file(dest); actual_size = dest.stat().st_size
        result["sha1"] = actual_sha1; result["actual_size_bytes"] = actual_size
        if portal_sha1 and actual_sha1.lower() != portal_sha1.lower():
            result["status"] = "sha1_mismatch"
            result["detail"] = f"portal={portal_sha1}, actual={actual_sha1}"
            failed += 1; print(f"{prefix} — SHA1 mismatch!"); results.append(result); continue
        if actual_size != mod["size_bytes"]:
            result["status"] = "ok_size_note"
            result["detail"] = f"sha1 ok; {actual_size} vs торрент {mod['size_bytes']}"
            ok += 1; print(f"{prefix} — OK (size note)")
        else:
            result["status"] = "ok"; result["detail"] = "sha1 и размер совпали"
            ok += 1; print(f"{prefix} — OK ({actual_size} байт)")
        results.append(result)
    report = {"total_requested": len(items), "ok": ok, "skipped_exists": skipped,
              "failed": failed, "not_found_on_portal": not_found, "results": results}
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n=== ИТОГ: ok={ok} skip={skipped} 404={not_found} failed={failed} ===")
    return 0 if failed == 0 and not_found == 0 else 2

if __name__ == "__main__":
    sys.exit(main())
