"""Checks tools/rme/1098 against the rules Remere's Map Editor applies while loading (the ones behind its
"Errors while loading brush" messages): "to" brushes defined before use, ground brushes only take ground
items, an item belongs to one brush only, ground equivalents are grounds of the same brush, every border,
friend and palette brush exists. Run from the project folder: python tools/rme_check.py"""
# Applies RME's load-time rules to tools/rme/1098 (in RME's load order: borders, brushes, tilesets).
import sys,collections,xml.etree.ElementTree as ET
sys.path.insert(0,'tools'); import rme_convert as rc
D='tools/rme/1098/'
g=rc.read_otb_groups('server/data/items/items.otb')
bt=ET.parse(D+'borders.xml').getroot(); br=ET.parse(D+'brushes.xml').getroot(); ts=ET.parse(D+'tilesets.xml').getroot()
err=collections.Counter(); ex=collections.defaultdict(list)
def e(k,v):
    err[k]+=1
    if len(ex[k])<5: ex[k].append(v)
bids=set()
for b in bt:
    bids.add(b.get('id'))
    ge=b.get('ground_equivalent')
    if ge and g.get(int(ge))!=1: e('ground equivalent not ground',b.get('id'))
    for it in b.iter('borderitem'):
        if int(it.get('item')) not in g: e('border item unknown',it.get('item'))
seen=set(); owner={}
for b in br:
    n=b.get('name')
    bare=len(list(b))==0
    if not bare:
        for x in b.iter():
            if x.tag in ('border','match_border') and x.get('to') and x.get('to') not in ('none','all') and x.get('to') not in seen and x.get('to')!=n:
                e('"to" brush not defined yet',(n,x.get('to')))
            if x.tag in ('border','match_border','optional') and x.get('id') and x.get('id') not in bids: e('border id missing',(n,x.get('id')))
            if x is not b and x.get('ground_equivalent'):
                ge=int(x.get('ground_equivalent'))
                if g.get(ge)!=1: e('inline ground equivalent not ground',(n,ge))
                elif owner.get(ge,n)!=n: e('inline ground equivalent owned by another brush',(n,ge,owner.get(ge)))
            if x.tag in ('item','carpet','door') and x.get('id'):
                i=int(x.get('id'))
                if i not in g: e('item unknown',(n,i))
                if b.get('type')=='ground' and x.tag=='item' and g.get(i)!=1: e('not ground item',(n,i))
                if owner.setdefault(i,n)!=n: e('item in two brushes',(n,i,owner[i]))
    seen.add(n)
allnames=seen
for b in br:
    for f in b.iter('friend'):
        if f.get('name') not in allnames: e('friend missing',(b.get('name'),f.get('name')))
defined=[b.get('name') for b in br if len(list(b))]
for n,c in collections.Counter(defined).items():
    if c>1: e('defined twice',n)
for t in ts:
    for x in t.iter('brush'):
        if x.get('name') not in allnames: e('palette brush missing',(t.get('name'),x.get('name')))
print('RME rule violations:',dict(err) or 'none')
for k,v in ex.items(): print(' ',k,v)
