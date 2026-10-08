"""Extract public 2022 BRT route geometry offline from the supplied OSM PBF.
GDAL's multiline-layer reader returned no features; decode only the OSM schema
needed for relations, ways and node coordinates. No crash workbook is opened.
Run from road_safety/. Extracted way geometry stays ignored locally; source
relation metadata is a public audit output.
"""
import json, struct, zlib, hashlib
from pathlib import Path

PBF = Path('data/raw/2026-10-05_osm_ecuador_geofabrik/ecuador-220101.osm.pbf')
OUT = Path('output/amendment4'); OUT.mkdir(parents=True, exist_ok=True)
DERIVED = Path('data/derived/amendment4'); DERIVED.mkdir(parents=True, exist_ok=True)

def varint(b, i):
    value = shift = 0
    while True:
        q = b[i]; i += 1; value |= (q & 127) << shift
        if q < 128: return value, i
        shift += 7

def fields(b):
    i = 0
    while i < len(b):
        k, i = varint(b, i); wire = k & 7; k >>= 3
        if wire == 0: x, i = varint(b, i)
        elif wire == 2:
            n, i = varint(b, i); x = b[i:i+n]; i += n
        elif wire == 1: x = b[i:i+8]; i += 8
        elif wire == 5: x = b[i:i+4]; i += 4
        else: raise ValueError(f'Unsupported protobuf wire {wire}')
        yield k, x

def packed(b):
    i = 0
    while i < len(b):
        x, i = varint(b, i); yield x

def zig(x): return (x >> 1) ^ -(x & 1)

def delta(b):
    total = 0
    for x in packed(b):
        total += zig(x); yield total

def blocks():
    with PBF.open('rb') as h:
        while True:
            n = h.read(4)
            if not n: break
            head = dict(fields(h.read(struct.unpack('>I', n)[0])))
            blob = dict(fields(h.read(head[3])))
            if head[1] == b'OSMData':
                yield list(fields(blob.get(1) or zlib.decompress(blob[3])))

relations = {}
for pb in blocks():
    st = [x.decode('utf8') for k,x in fields(dict(pb)[1]) if k == 1]
    for k,g in pb:
        if k != 2: continue
        for typ,r in fields(g):
            if typ != 4: continue
            a = dict(fields(r)); tags = dict(zip((st[x] for x in packed(a.get(2,b''))), (st[x] for x in packed(a.get(3,b'')))))
            if tags.get('type') not in ('route','route_master'): continue
            members = list(zip(delta(a.get(9,b'')), packed(a.get(10,b'')), (st[x] for x in packed(a.get(8,b'')))))
            relations[a[1]] = (tags,members)
refs = {'C1','C4','C6','E1','E1R','E3','E4','E6'}
seeds = {i for i,(t,m) in relations.items() if t.get('network') == 'Metrobus-Q' and t.get('ref') in refs}
selected = set(); todo = list(seeds)
while todo:
    i = todo.pop()
    if i in selected: continue
    assert i in relations, f'Missing child relation {i}'
    selected.add(i); tags,members = relations[i]
    todo.extend(mid for mid,kind,role in members if kind == 2)
way_ids = {mid for i in selected for mid,kind,role in relations[i][1] if kind == 1 and not role.startswith('platform')}
assert selected and way_ids
ways = {}
for pb in blocks():
    for k,g in pb:
        if k != 2: continue
        for typ,w in fields(g):
            if typ != 3: continue
            a = dict(fields(w))
            if a[1] in way_ids: ways[a[1]] = list(delta(a[8]))
assert way_ids <= ways.keys(), f'Missing ways: {way_ids - ways.keys()}'
needed = {n for w in ways.values() for n in w}; nodes = {}
for pb in blocks():
    meta = dict(pb); gran = meta.get(17,100)
    def signed64(x): return x - (1 << 64) if x >= (1 << 63) else x
    lat0 = signed64(meta.get(19,0)); lon0 = signed64(meta.get(20,0))
    def coord(lat,lon): return [(lon0 + gran * lon)*1e-9, (lat0 + gran * lat)*1e-9]
    for k,g in pb:
        if k != 2: continue
        for typ,n in fields(g):
            if typ == 2:
                a = dict(fields(n))
                for i,lat,lon in zip(delta(a[1]),delta(a[8]),delta(a[9])):
                    if i in needed: nodes[i] = coord(lat,lon)
            elif typ == 1:
                a = dict(fields(n)); i = zig(a[1])
                if i in needed: nodes[i] = coord(zig(a[8]),zig(a[9]))
assert needed <= nodes.keys(), 'Missing geometry nodes'
features = [{'type':'Feature','properties':{'osm_way_id':i,'source':'OSM 2022-01-01, Geofabrik'},'geometry':{'type':'LineString','coordinates':[nodes[n] for n in ways[i]]}} for i in sorted(ways)]
assert all(-79 < q[0] < -78 and -.6 < q[1] < .3 for f in features for q in f['geometry']['coordinates'])
(DERIVED/'brt_2022.geojson').write_text(json.dumps({'type':'FeatureCollection','features':features})+'\n')
public = [{'osm_id':i,**relations[i][0]} for i in sorted(selected)]
(OUT/'brt_2022_relations.json').write_text(json.dumps(public,ensure_ascii=False,indent=2)+'\n')
sha = hashlib.sha256(PBF.read_bytes()).hexdigest()
assert sha == 'ebd20f7063490591e4155004305a40bc02888d8fa7a7ff5f5474a20bbff9d535'
(OUT/'brt_2022_source.json').write_text(json.dumps({'input':str(PBF),'sha256':sha,'relation_rule':'Metrobus-Q C1/C4/C6/E1/E1R/E3/E4/E6, route masters and all child routes; omit platform ways','complete_members':True},indent=2)+'\n')
print('Public pre-opening BRT geometry complete; no crash data read.')
