"""Marks items as ground in server/data/items/items.otb (group 1, plus the walking speed from the graphics).

Reads the server ids to fix from /tmp/claude-0/should_ground.json and speeds from dat_grounds.py output.
It first checks that it can rewrite the unchanged file byte for byte."""
import json,struct,sys
src='server/data/items/items.otb'
d=open(src,'rb').read()
def node(i):
    i+=1; buf=bytearray(); kids=[]
    while True:
        c=d[i]
        if c==0xFD: buf.append(d[i+1]); i+=2
        elif c==0xFE: k,i=node(i); kids.append(k)
        elif c==0xFF: return [bytes(buf),kids],i+1
        else: buf.append(c); i+=1
root,end=node(4)
assert end==len(d)
def esc(b):
    out=bytearray()
    for x in b:
        if x in (0xFD,0xFE,0xFF): out.append(0xFD)
        out.append(x)
    return out
def ser(n):
    out=bytearray([0xFE])+esc(n[0])
    for k in n[1]: out+=ser(k)
    return out+bytes([0xFF])
same=d[:4]+ser(root)
print('round trip identical:',same==d)
if same!=d: sys.exit(1)
fix=set(json.load(open('/tmp/claude-0/should_ground.json')))
info={int(k):v for k,v in json.load(open('/tmp/claude-0/datinfo.json')).items()}
changed=0
for n in root[1]:
    data=n[0]; p=5; attrs=[]
    while p<len(data):
        a=data[p]; ln=struct.unpack_from('<H',data,p+1)[0]; attrs.append((a,data[p+3:p+3+ln])); p+=3+ln
    sid=dict(attrs).get(0x10); sid=struct.unpack('<H',sid)[0] if sid else None
    if sid in fix:
        cid=struct.unpack('<H',dict(attrs)[0x11])[0]
        speed=info[cid]['speed'] or 0
        new=bytearray([1])+data[1:5]   # group 1 = ground, same flags
        for a,v in attrs:
            new+=bytes([a])+struct.pack('<H',len(v))+v
            if a==0x11 and not any(x==0x14 for x,_ in attrs):   # speed right after the client id, like other grounds
                new+=bytes([0x14])+struct.pack('<H',2)+struct.pack('<H',speed)
        n[0]=bytes(new); changed+=1
open(src,'wb').write(d[:4]+ser(root))
print('marked as ground:',changed)
