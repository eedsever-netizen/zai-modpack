#!/usr/bin/env python3
"""Пометить Omniterra как исключённый в JSON-данных."""
import json
from pathlib import Path

ROOT = Path("/home/z/my-project")
TORRENT_MODS = ROOT / "scripts" / "torrent_mods.json"
REPORT = ROOT / "portal_data" / "download_report.json"
REASON = ("Исключён из сборки: мод представляет собой объединение рудных "
          "наборов Bob's, Angel's и Omnimatter, но фактически работает "
          "нестабильно. Зависимости Omniterra проверены — на пакет не влияет.")

mods = json.loads(TORRENT_MODS.read_text(encoding="utf-8"))
if "Omniterra" in mods:
    mods["Omniterra"]["status"] = "excluded"
    mods["Omniterra"]["excluded_reason"] = REASON
    TORRENT_MODS.write_text(json.dumps(mods, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    print("torrent_mods.json: Omniterra помечен status=excluded")

if REPORT.exists():
    rep = json.loads(REPORT.read_text(encoding="utf-8"))
    for r in rep.get("results", []):
        if r.get("name") == "Omniterra":
            r["status"] = "excluded_by_decision"; r["detail"] = REASON; break
    rep["not_found_on_portal"] = sum(1 for r in rep["results"] if r.get("status") == "not_found_on_portal")
    rep["excluded_by_decision"] = sum(1 for r in rep["results"] if r.get("status") == "excluded_by_decision")
    rep["decision_notes"] = [{"mod": "Omniterra", "version": "0.2.0",
                              "decision": "exclude", "reason": REASON, "date": "2026-11-07"}]
    REPORT.write_text(json.dumps(rep, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"download_report.json: Omniterra → excluded_by_decision")
