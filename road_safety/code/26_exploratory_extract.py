"""Exploratory pre+P1 extraction only, explicitly authorized 2026-10-06.
Date/key filtering precedes outcome decoding. Nothing September 2024 onward
is materialized. Raw ZIP/shared-string streams necessarily traverse bytes.
"""
import importlib.util
from datetime import datetime
from pathlib import Path
spec=importlib.util.spec_from_file_location("fenced",Path(__file__).with_name("13_amend2_extract.py"))
fenced=importlib.util.module_from_spec(spec);spec.loader.exec_module(fenced)
fenced.END=(datetime(2024,9,1)-fenced.BASE).days
fenced.OUT=Path("data/derived/exploratory_20261006")
fenced.main()
import json
p=fenced.OUT/"extraction.json";m=json.loads(p.read_text())
m.update(end_exclusive="2024-09-01",purpose="EXPLORATORY ONLY; amendment unapproved",vehicle_gate="selected pre/P1 crash-ID whitelist before outcome decoding")
p.write_text(json.dumps(m,indent=2)+"\n")
