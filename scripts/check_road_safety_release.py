#!/usr/bin/env python3
"""Check release paths in the index or a commit, never confidential raw data.

Path and ignore checks are necessary but cannot certify semantic confidentiality.
The claims-auditor must review the complete release and linked disclosures.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "road_safety/docs/release_allowlist.json"
FORBIDDEN = (
    "road_safety/output/build/", "road_safety/output/completeness/",
    "road_safety/output/descriptives/", "road_safety/output/spatial/",
    "road_safety/output/power/", "road_safety/output/preperiod/",
    "road_safety/output/p1/", "road_safety/output/exploratory_",
    "road_safety/output/amendment2/", "road_safety/output/amendment3_stage_a/",
    "road_safety/output/amendment4/", "reports/road_safety/2026-09-25_",
    "road_safety/data/derived/", "road_safety/_environment/",
)
RAW_LINKS = {
    "road_safety/data/raw", "road_safety/data/congestion_centro_historico",
    "road_safety/data/metro_validaciones",
}
PROBES = (
    "road_safety/output/descriptives/future_counts.csv",
    "road_safety/output/new_analysis/future_figure.png",
    "road_safety/output/amendment4_grid/future_counts.csv",
    "road_safety/output/amendment4_stage_b/future_counts.csv",
    "road_safety/output/amendment4_stage_b_2022/future_counts.csv",
    "road_safety/reports/future_protected.md",
    "reports/road_safety/future_protected.md",
    "reports/verification/future_road_safety_review.md",
    "road_safety/data/derived/future_panel.csv",
)


def git(*args, check=True):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                          check=check)


def sensitive(path):
    return (path.startswith(("road_safety/output/", "road_safety/reports/",
                             "reports/road_safety/")) or
            (path.startswith("reports/verification/") and
             ("road_safety" in path or "amendment" in path)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--index", action="store_true")
    mode.add_argument("--tree", metavar="REV")
    args = parser.parse_args()
    if args.index:
        paths = git("ls-files", "-z").stdout.decode().split("\0")
        manifest = git("show", ":" + MANIFEST, check=False)
    else:
        paths = git("ls-tree", "-rz", "--name-only", args.tree).stdout.decode().split("\0")
        manifest = git("show", args.tree + ":" + MANIFEST, check=False)
    if manifest.returncode:
        sys.exit("FAIL: stage or commit the reviewed release allowlist first")
    allow = set(json.loads(manifest.stdout)["artifacts"])
    errors = []
    selected_ignore = git("show", (":" if args.index else args.tree + ":") + ".gitignore")
    if selected_ignore.stdout != (ROOT / ".gitignore").read_bytes():
        errors.append("working ignore rules differ from selected index/tree; check-ignore would test another version")
    for path in filter(None, paths):
        if path.startswith(FORBIDDEN):
            errors.append("forbidden historical/private path: " + path)
        elif sensitive(path) and path not in allow:
            errors.append("artifact absent from reviewed allowlist: " + path)
        if path.startswith("road_safety/data/"):
            if path not in RAW_LINKS:
                errors.append("unexpected road-safety data path: " + path)
            else:
                mode_cmd = ("ls-files", "--stage", "--", path) if args.index else (
                    "ls-tree", args.tree, "--", path)
                if not git(*mode_cmd).stdout.startswith(b"120000 "):
                    errors.append("raw data reference must be a symlink: " + path)
    for path in PROBES:
        result = git("check-ignore", "--no-index", "-q", "--", path, check=False)
        if result.returncode != 0:
            errors.append("default-ignore protection missing: " + path)
    # Existing tracked files are not protected merely by adding .gitignore rules.
    # That is why the actual index/tree was checked above.
    if errors:
        sys.exit("FAIL:\n" + "\n".join(errors))
    print("PASS: release path allowlist, forbidden paths, raw symlinks and ignore probes.")
    print("Scope: selected index/tree only; retained history and semantic disclosure require separate review.")


if __name__ == "__main__":
    main()
