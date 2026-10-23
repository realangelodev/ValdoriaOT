# Map editor data

`1098/` holds borders, brushes (grounds, walls, doodads) and palettes for Remere's Map Editor, covering
all of Valdoria's items up to 15.x:

- the opentibiabr brushes and borders, renumbered for our items;
- the original 10.98 brushes those lack, in a **Classic 10.98** palette;
- **Grounds without borders**: grounds nobody has made a brush for yet (mostly new ones); place them by hand;
- **More items ...** palettes with every other item that isn't in a themed palette. `setup.bat` copies them, together with the server's `items.otb` and
`items.xml`, into `RME\data\1098` (the first time it keeps the original folder as `RME\data\1098-original`).

They are generated from the opentibiabr Remere's Map Editor materials by `tools/rme_convert.py`, which
renumbers every item through the server's `items.otb`:

    python tools/rme_convert.py <remeres-map-editor>/data/materials server/data/items/items.otb tools/rme/1098 \
        <remeres-map-editor>/data/items/items.xml server/data/items/items.xml <rme>/data/1098

In RME, untick **Preferences > Client Version > Check file signatures**: the client's Tibia.dat/.spr were
recompiled, so they no longer match the original 10.98 signatures.
