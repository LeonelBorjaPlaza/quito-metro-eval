#!/usr/bin/env python3
"""Phase 3 of the consolidation: copy raw, derived, output and delivery files to the data store.

Reads reports/migration/03_data_map.csv (written by 03_classify_data.py). For every row whose
class is raw, derived, output or delivery, copies source -> new_location with shutil.copy2
(content and modification time), skips a destination that already holds the same sha256,
and re-hashes every copy against the sha256 in the map. Sources are only read.

Also copies the two new deliveries from NEW_DATA into their dated folders.
Prints a summary and exits non-zero on any mismatch.
"""
import csv
import hashlib
import os
import shutil
import sys

NEW_DATA = os.environ["NEW_DATA"]
DATA_STORE = os.environ["DATA_STORE"]
MAP = "reports/migration/03_data_map.csv"

DELIVERIES = {
    f"{DATA_STORE}/air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill": [
        "DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx",
        "Solicitud de revisión del paper de calidad del aire PLMQ.msg",
    ],
    f"{DATA_STORE}/road_safety/raw/2026-09-23_amt_siniestros": [
        "REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx",
        "RE Solicitud de datos de siniestros de tránsito del DMQ para la evaluación de impacto del Metro de Quito.msg",
    ],
}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 22), b""):
            h.update(chunk)
    return h.hexdigest()


def copy_verified(src, dst, expected):
    if os.path.exists(dst) and sha256(dst) == expected:
        return "present"
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    got = sha256(dst)
    if got != expected:
        raise RuntimeError(f"sha256 mismatch after copy: {dst}")
    return "copied"


def main():
    done = {}
    bad = []
    seen = set()
    for folder, names in DELIVERIES.items():
        for n in names:
            src = os.path.join(NEW_DATA, n)
            dst = os.path.join(folder, n)
            try:
                st = copy_verified(src, dst, sha256(src))
                done[("delivery-newdata", st)] = done.get(("delivery-newdata", st), 0) + 1
                seen.add(dst)
            except Exception as e:  # noqa: BLE001
                bad.append(str(e))
    for r in csv.DictReader(open(MAP, encoding="utf-8")):
        if r["class"] not in ("raw", "derived", "output", "delivery"):
            continue
        dst = r["new_location"]
        if dst in seen:  # byte-identical to a NEW_DATA file already stored
            done[(r["class"], "identical-to-newdata")] = done.get((r["class"], "identical-to-newdata"), 0) + 1
            continue
        src = os.path.join(r["source"], r["source_path"])
        try:
            st = copy_verified(src, dst, r["sha256"])
            done[(r["class"], st)] = done.get((r["class"], st), 0) + 1
        except Exception as e:  # noqa: BLE001
            bad.append(f"{r['source_path']}: {e}")
    for k, v in sorted(done.items()):
        print(f"{k[0]:18s} {k[1]:22s} {v:6d}")
    if bad:
        print("FAILURES:")
        print("\n".join(bad))
        sys.exit(1)
    print("all copies verified by sha256")


if __name__ == "__main__":
    main()
