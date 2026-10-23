"""Builds Remere's Map Editor data (borders, brushes, palettes) for Valdoria's items.

Source: the materials of opentibiabr/remeres-map-editor, which number items by their client (graphic) id.
Valdoria's items.otb numbers items differently, but records each item's client id, so every item number is
translated through it: their item with client id X becomes our item whose client id is X.

Usage: python rme_convert.py <opentibiabr materials dir> <server items.otb> <output dir>
                             [<opentibiabr items.xml> <server items.xml>   (names pick between look-alikes)
                             [<original RME data/1098 dir>]]                (keeps what only the old data had)
"""
import collections
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET


def read_otb(path):
    """Returns {client id: [server ids]} from an items.otb."""
    d = open(path, 'rb').read()

    def node(i):
        i += 1
        buf, kids = bytearray(), []
        while True:
            c = d[i]
            if c == 0xFD:
                buf.append(d[i + 1]); i += 2
            elif c == 0xFE:
                kid, i = node(i); kids.append(kid)
            elif c == 0xFF:
                return (bytes(buf), kids), i + 1
            else:
                buf.append(c); i += 1

    root, _ = node(4)
    by_client = {}
    for data, _ in root[1]:
        p, sid, cid = 5, None, None
        while p < len(data):
            attr, ln = data[p], struct.unpack_from('<H', data, p + 1)[0]
            v = data[p + 3:p + 3 + ln]; p += 3 + ln
            if attr == 0x10: sid = struct.unpack('<H', v)[0]
            elif attr == 0x11: cid = struct.unpack('<H', v)[0]
        if sid and cid:
            by_client.setdefault(cid, []).append(sid)
    return by_client


def read_otb_groups(path):
    """Returns {server id: item group} (1 = ground) from an items.otb."""
    d = open(path, 'rb').read()
    groups, i, depth, buf = {}, 4, 0, None
    def node(i):
        i += 1
        buf, kids = bytearray(), []
        while True:
            c = d[i]
            if c == 0xFD: buf.append(d[i + 1]); i += 2
            elif c == 0xFE: kid, i = node(i); kids.append(kid)
            elif c == 0xFF: return (bytes(buf), kids), i + 1
            else: buf.append(c); i += 1
    root, _ = node(4)
    for data, _ in root[1]:
        p = 5
        while p < len(data):
            attr, ln = data[p], struct.unpack_from('<H', data, p + 1)[0]
            if attr == 0x10: groups[struct.unpack_from('<H', data, p + 3)[0]] = data[0]
            p += 3 + ln
    return groups


def read_names(path):
    """Returns {item id: lowercase name} from an items.xml."""
    names = {}
    if not path or not os.path.exists(path):
        return names
    for el in ET.parse(path).getroot().findall('item'):
        n = (el.get('name') or '').lower().strip()
        ids = [int(el.get('id'))] if 'id' in el.attrib else range(int(el.get('fromid')), int(el.get('toid')) + 1)
        for i in ids:
            names[i] = n
    return names


def plain(name):
    return re.sub(r'^(the|a|an) ', '', name or '')


def translator(otb, their_names, our_names):
    """Maps their item (client id) to ours. When several of our items share that graphic, take the one
    with the same name, so a "water cask" doesn't become a "cask of beer" that merely looks the same."""
    by_client = read_otb(otb)
    table = {}
    for cid, sids in by_client.items():
        want = plain(their_names.get(cid))
        named = [s for s in sids if want and plain(our_names.get(s)) == want]
        table[cid] = min(named) if named else min(sids)
    return table


def load_tree(path):
    """Parses an XML file, following <include file=...> into one flat list of top-level elements."""
    text = open(path, encoding='utf-8', errors='replace').read()
    text = re.sub(r'<!--.*?-->', '', text, flags=re.S)
    text = re.sub(r'(<border\b[^>]*>)\s*--[^<]*?--', r'\1', text)  # "-- comment --" text inside borders
    text = re.sub(r'&(?!(amp|lt|gt|quot|apos|#\d+);)', '&amp;', text)  # a few names use a bare &
    root = ET.fromstring(text)
    out = []
    for el in root:
        if el.tag == 'include':
            out += load_tree(os.path.join(os.path.dirname(path), el.get('file')))
        else:
            out.append(el)
    return out


def runs(ids):
    """Groups sorted ids into (from, to) runs."""
    ids = sorted(set(ids)); out = []
    for i in ids:
        if out and i == out[-1][1] + 1: out[-1][1] = i
        else: out.append([i, i])
    return out


def main(src, otb, dst, their_items=None, our_items=None, classic=None):
    tr = translator(otb, read_names(their_items), read_names(our_items))
    t = lambda v: tr.get(int(v))
    stats = collections.Counter()

    borders = load_tree(os.path.join(src, 'borders.xml'))
    brushes = load_tree(os.path.join(src, 'brushs.xml'))
    tilesets = load_tree(os.path.join(src, 'tilesets.xml'))

    def fix_items(el):
        """Translates item numbers in el's subtree; drops elements whose item doesn't exist here."""
        for parent in list(el.iter()):
            for child in list(parent):
                tag = child.tag
                if tag == 'ite':
                    parent.remove(child); continue
                if tag in ('item', 'carpet', 'door', 'match_item', 'replace_item', 'borderitem') or (tag == 'item' and 'fromid' in child.attrib):
                    key = 'item' if tag == 'borderitem' else 'id'
                    if 'fromid' in child.attrib:
                        hi = child.get('toid') or child.get('toid1') or child.get('fromid')
                        got = [t(i) for i in range(int(child.get('fromid')), int(hi) + 1)]
                        got = [g for g in got if g]
                        idx = list(parent).index(child); parent.remove(child)
                        for a, b in runs(got):
                            new = ET.Element(tag, {k: v for k, v in child.attrib.items() if k not in ('fromid', 'toid', 'toid1')})
                            if a == b: new.set('id', str(a))
                            else: new.set('fromid', str(a)); new.set('toid', str(b))
                            parent.insert(idx, new); idx += 1
                        stats['ranges'] += 1
                        continue
                    if key in child.attrib:
                        v = t(child.get(key))
                        if not v:
                            parent.remove(child); stats['dropped items'] += 1; continue
                        child.set(key, str(v))
                    if tag == 'replace_item' and 'with' in child.attrib:
                        w = t(child.get('with'))
                        if not w: parent.remove(child); continue
                        child.set('with', str(w))
        if el.tag == 'brush' and el.get('server_lookid'):
            v = t(el.get('server_lookid'))
            if v: el.set('server_lookid', str(v))
            else: del el.attrib['server_lookid']
        if el.tag == 'border' and el.get('ground_equivalent'):
            v = t(el.get('ground_equivalent'))
            if v: el.set('ground_equivalent', str(v))
            else: del el.attrib['ground_equivalent']

    # Borders: keep the ones that still have at least one piece.
    kept_borders = []
    for b in borders:
        if b.tag != 'border': continue
        fix_items(b)
        if b.find('borderitem') is not None: kept_borders.append(b)
    border_ids = {b.get('id') for b in kept_borders}

    # Brushes: keep the ones that still have something to place.
    kept_brushes = []
    for b in brushes:
        if b.tag != 'brush': continue
        fix_items(b)
        for parent in list(b.iter()):
            for child in list(parent):
                if child.tag in ('border', 'match_border', 'replace_border', 'optional') and child.get('id') and child.get('id') not in border_ids:
                    parent.remove(child)
            for child in list(parent):  # composites and walls that lost all their items
                if child.tag in ('tile',) and not list(child): parent.remove(child)
                if child.tag in ('composite', 'alternate') and not list(child.iter('item')) and not list(child.iter('carpet')): parent.remove(child)
        placeable = list(b.iter('item')) + list(b.iter('carpet')) + list(b.iter('door'))
        if placeable or b.get('type') is None:
            kept_brushes.append(b)
    names = {b.get('name') for b in kept_brushes}
    for b in kept_brushes:  # friends and other references to brushes that are gone
        for parent in list(b.iter()):
            for child in list(parent):
                if child.tag == 'friend' and child.get('name') not in names: parent.remove(child)
                if child.tag in ('border', 'match_border') and child.get('to') and child.get('to') not in ('none', 'all') and child.get('to') not in names:
                    parent.remove(child)

    # Tilesets: translate items, drop brushes that are gone, drop empty sections.
    kept_tilesets = []
    for ts in tilesets:
        if ts.tag != 'tileset': continue
        fix_items(ts)
        for section in list(ts):
            for child in list(section):
                if child.tag == 'brush' and child.get('name') not in names: section.remove(child)
            if not list(section): ts.remove(section)
        if list(ts): kept_tilesets.append(ts)

    # Duplicate brush names confuse RME: number the later ones.
    seen = collections.Counter()
    for b in kept_brushes:
        n = b.get('name'); seen[n] += 1
        if seen[n] > 1: b.set('name', '%s (%d)' % (n, seen[n]))
    names = {b.get('name') for b in kept_brushes}

    # Keep what only the original 10.98 data had: its brushes (with their borders, renumbered so they
    # can't clash) and its loose items. These already use our item numbers.
    classic_brushes, classic_items = [], set()
    if classic and os.path.isdir(classic):
        old_borders = {b.get('id'): b for b in load_tree(os.path.join(classic, 'borders.xml')) if b.tag == 'border'}
        old_brushes = []
        for f in ('grounds.xml', 'walls.xml', 'doodads.xml'):
            old_brushes += [b for b in load_tree(os.path.join(classic, f)) if b.tag == 'brush']
        offset = 1000 + max(int(b.get('id')) for b in kept_borders)
        used = set()
        for b in old_brushes:
            if b.get('name') in names: continue
            for e in b.iter():
                if e.tag in ('border', 'match_border', 'optional') and e.get('id') in old_borders:
                    used.add(e.get('id')); e.set('id', str(int(e.get('id')) + offset))
            classic_brushes.append(b); names.add(b.get('name'))
        for bid in sorted(used, key=int):
            nb = old_borders[bid]; nb.set('id', str(int(bid) + offset)); kept_borders.append(nb)
        kept_brushes += classic_brushes
        for f in os.listdir(classic):
            if f.endswith('.xml') and f not in ('items.xml', 'creatures.xml', 'clients.xml'):
                t = open(os.path.join(classic, f), encoding='utf-8', errors='replace').read()
                classic_items.update(int(m) for m in re.findall(r'\b(?:id|item|server_lookid)="(\d+)"', t))
                for a, b2 in re.findall(r'fromid="(\d+)"\s+toid="(\d+)"', t):
                    classic_items.update(range(int(a), int(b2) + 1))
        stats['classic brushes kept'] = len(classic_brushes)

    # Everything else gets a palette too, so every item can be placed.
    groups, item_names = read_otb_groups(otb), read_names(our_items)
    placed = set()
    for tree in (kept_borders, kept_brushes, kept_tilesets):
        for root in tree:
            for e in root.iter():
                for k in ('id', 'item', 'server_lookid'):
                    if e.tag in ('border', 'match_border', 'replace_border', 'optional', 'metaitem') and k == 'id': continue
                    if (e.get(k) or '').isdigit(): placed.add(int(e.get(k)))
                if e.get('fromid'): placed.update(range(int(e.get('fromid')), int(e.get('toid')) + 1))

    def tileset(name, sections):
        ts = ET.Element('tileset', {'name': name})
        for tag, children in sections:
            if not children: continue
            sec = ET.SubElement(ts, tag)
            sec.extend(children)
        return ts

    def item_elements(ids):
        out = []
        for a, b2 in runs(ids):
            out.append(ET.Element('item', {'id': str(a)} if a == b2 else {'fromid': str(a), 'toid': str(b2)}))
        return out

    if classic_brushes:
        terrain = [ET.Element('brush', {'name': b.get('name')}) for b in classic_brushes if b.get('type') in ('ground', 'wall', 'carpet', 'table')]
        doodads = [ET.Element('brush', {'name': b.get('name')}) for b in classic_brushes if b.get('type') not in ('ground', 'wall', 'carpet', 'table')]
        loose = sorted(i for i in classic_items if i in groups and i not in placed and not 80 <= i <= 89)
        placed.update(loose)
        kept_tilesets.append(tileset('Classic 10.98', [('terrain', terrain), ('doodad', doodads), ('raw', item_elements(loose))]))
    rest = sorted(i for i in groups if i not in placed)
    new_grounds = [i for i in rest if groups[i] == 1]
    kept_tilesets.append(tileset('Grounds without borders', [('raw', item_elements(new_grounds))]))
    others = [i for i in rest if groups[i] != 1]
    for k in range(0, len(others), 2500):
        chunk = others[k:k + 2500]
        kept_tilesets.append(tileset('More items %d-%d' % (chunk[0], chunk[-1]), [('raw', item_elements(chunk))]))
    stats['grounds without borders'] = len(new_grounds)
    stats['items in More items palettes'] = len(others)

    os.makedirs(dst, exist_ok=True)

    def write(name, elements, note):
        root = ET.Element('materials')
        root.text = '\n\t'
        for e in elements: root.append(e)
        ET.indent(root, '\t')
        body = ET.tostring(root, encoding='unicode')
        with open(os.path.join(dst, name), 'w', encoding='utf-8') as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!-- ' + note + ' Generated by tools/rme_convert.py. -->\n' + body + '\n')

    note = 'From opentibiabr/remeres-map-editor, renumbered for Valdoria\'s items.otb.'
    write('borders.xml', kept_borders, note)
    write('brushes.xml', kept_brushes, note)
    write('tilesets.xml', kept_tilesets, note)
    with open(os.path.join(dst, 'materials.xml'), 'w', encoding='utf-8') as f:
        f.write('<materials>\n\t<!-- Items that only exist in the editor -->\n'
                + ''.join('\t<metaitem id="%d"/>\n' % i for i in range(80, 90))
                + '\t<include file="borders.xml"/>\n\t<include file="brushes.xml"/>\n\t<include file="tilesets.xml"/>\n</materials>\n')
    print('borders %d/%d, brushes %d/%d, tilesets %d/%d' % (len(kept_borders), len([b for b in borders if b.tag == 'border']),
          len(kept_brushes), len([b for b in brushes if b.tag == 'brush']), len(kept_tilesets), len([t for t in tilesets if t.tag == 'tileset'])))
    print(dict(stats))


if __name__ == '__main__':
    main(*sys.argv[1:7])
