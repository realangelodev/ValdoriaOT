"""Lists ground items from a Tibia.dat (8.60 format, extended sprites, frame durations) into a JSON file.

Usage: python dat_grounds.py <Tibia.dat> ; writes /tmp/claude-0/datinfo.json (client id -> ground flag and speed).
Used with otb_fix_grounds.py to find items the graphics call ground but items.otb does not."""
import struct,sys,json
d=open(sys.argv[1],'rb').read()
sig,items,outfits,effects,missiles=struct.unpack_from('<IHHHH',d,0); p=12
print('signature %08x items %d outfits %d'%(sig,items,outfits))
SIZES={0:2,8:2,9:2,21:4,24:4,25:2,28:2,29:2,32:2}
info={}
for cid in range(100,items+1):
    flags={}
    while True:
        a=d[p]; p+=1
        if a==0xFF: break
        if a==33:  # market: cat, tradeAs, showAs, name, vocation, level
            p+=6; ln=struct.unpack_from('<H',d,p)[0]; p+=2+ln+4; flags[a]=1; continue
        if a in SIZES:
            v=struct.unpack_from('<H',d,p)[0] if SIZES[a]>=2 else None; p+=SIZES[a]; flags[a]=v; continue
        flags[a]=1
    w,h=d[p],d[p+1]; p+=2
    if w>1 or h>1: p+=1
    layers,px,py,pz,frames=d[p],d[p+1],d[p+2],d[p+3],d[p+4]; p+=5
    if frames>1: p+=1+4+1+frames*8
    p+=4*w*h*layers*px*py*pz*frames
    info[cid]={'ground':0 in flags,'speed':flags.get(0),'border':1 in flags,'bottom':2 in flags,'top':3 in flags,'full':30 in flags}
json.dump(info,open('/tmp/claude-0/datinfo.json','w'))
print('parsed items',len(info),'grounds',sum(v['ground'] for v in info.values()),'end offset',p)
