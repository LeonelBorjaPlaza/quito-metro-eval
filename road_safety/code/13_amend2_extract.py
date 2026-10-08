"""Pre-period-only extraction from locked Excel inputs; run from road_safety/.

XML is streamed, dates/keys route records before outcome fields are decoded.
Shared strings are resolved only for selected records. The ZIP stream necessarily
passes excluded bytes; no excluded outcome record is materialized or saved.
Outputs are confidential, ignored, local intermediate CSVs, never public tables.
"""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
from datetime import datetime, timedelta
import csv
import hashlib
import json

NS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
BASE = datetime(1899, 12, 30)
START = (datetime(2021, 1, 1) - BASE).days
END = (datetime(2023, 12, 1) - BASE).days
OUT = Path('data/derived/amendment2')


def rows(z, sheet):
    with z.open(sheet) as f:
        for event, el in ET.iterparse(f, events=('end',)):
            if el.tag == NS + 'row':
                yield el
                el.clear()


def token(c):
    if c is None:
        return ('n', '')
    typ = c.get('t', 'n')
    if typ == 'inlineStr':
        return ('text', ''.join(t.text or '' for t in c.iter(NS + 't')))
    v = c.find(NS + 'v')
    return (typ, v.text if v is not None and v.text else '')


def col(c):
    return ''.join(x for x in c.get('r', '') if x.isalpha())


def strings(z, wanted):
    result = {}
    if not wanted:
        return result
    with z.open('xl/sharedStrings.xml') as f:
        i = 0
        for _, el in ET.iterparse(f, events=('end',)):
            if el.tag == NS + 'si':
                if str(i) in wanted:
                    result[str(i)] = ''.join(t.text or '' for t in el.iter(NS + 't'))
                i += 1
                el.clear()
    assert len(result) == len(wanted)
    return result


def decode(t, ss):
    return ss[t[1]] if t[0] == 's' else t[1]


def header(z, sheet):
    r = next(rows(z, sheet))
    ts = {col(c): token(c) for c in r}
    ss = strings(z, {v for t, v in ts.values() if t == 's'})
    return {k: decode(v, ss).strip() for k, v in ts.items()}


def selected(z, sheet, hdr, predicate):
    kept = []
    for r in rows(z, sheet):
        if r.get('r') == '1':
            continue
        if predicate(r):
            kept.append({col(c): token(c) for c in r if col(c) in hdr})
    ss = strings(z, {v for r in kept for t, v in r.values() if t == 's'})
    return [{hdr[c]: decode(r.get(c, ('n', '')), ss).strip() for c in hdr} for r in kept]


def write(name, data, fields):
    with (OUT / name).open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(data)


def main():
    assert Path('RUNBOOK.md').exists()
    OUT.mkdir(parents=True, exist_ok=True)
    raw = Path('data/raw/2026-09-23_amt_siniestros/REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx')
    sha = hashlib.sha256(raw.read_bytes()).hexdigest()
    assert sha == '1bfc56dd11a6c86a50715c536338e0cd62a80ba9d71fd5147636613f12f8ee18'
    with ZipFile(raw) as z:
        sh = 'xl/worksheets/sheet1.xml'
        hdr = header(z, sh)
        dc = next(c for c, name in hdr.items() if name == 'FECHA')
        def pre(r):
            t, v = token(next((c for c in r if col(c) == dc), None))
            return t == 'n' and bool(v) and START <= float(v) < END
        s = selected(z, sh, hdr, pre)
        ids = {r['SINIESTRO'] for r in s}
        assert len(ids) == len(s) and all(START <= float(r['FECHA']) < END for r in s)
        write('crashes_pre.csv', s, list(hdr.values()))
        sh = 'xl/worksheets/sheet2.xml'
        vh = header(z, sh)
        ic = next(c for c, name in vh.items() if name == 'SINIESTRO')
        # Resolve only routing identifiers first, never post-period vehicle types.
        key_tokens = {token(c) for r in rows(z, sh) for c in r if col(c) == ic}
        ks = strings(z, {v for t, v in key_tokens if t == 's'})
        allowed = {t for t in key_tokens if decode(t, ks).strip() in ids}
        v = selected(z, sh, vh, lambda r: token(next((c for c in r if col(c) == ic), None)) in allowed)
        assert all(r['SINIESTRO'] in ids for r in v)
        write('vehicles_pre.csv', v, list(vh.values()))
    rain = Path('../air_quality/data/raw/remmaq/LLU.xlsx')
    with ZipFile(rain) as z:
        hdr = header(z, 'xl/worksheets/sheet1.xml')
        dc = next(iter(hdr))
        def rain_pre(r):
            t, v = token(next((c for c in r if col(c) == dc), None))
            return t == 'n' and bool(v) and START <= round(float(v) * 24) / 24 < END
        rr = selected(z, 'xl/worksheets/sheet1.xml', hdr, rain_pre)
        write('rain_pre.csv', rr, list(hdr.values()))
    meta = {'crash_source_sha256': sha, 'rain_source_sha256': hashlib.sha256(rain.read_bytes()).hexdigest(),
            'start': '2021-01-01', 'end_exclusive': '2023-12-01',
            'date_gate': 'numeric Excel date before outcome decoding',
            'vehicle_gate': 'pre-period crash identifier whitelist before vehicle decoding'}
    (OUT / 'extraction.json').write_text(json.dumps(meta, indent=2) + '\n')
    print('Pre-period crash, vehicle and rainfall extraction completed; confidential rows not printed.')


if __name__ == '__main__':
    main()
