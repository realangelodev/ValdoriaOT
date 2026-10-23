# Valdoria: handoff notes

Read this first if you are picking up this project. It covers what exists, how the owner works with it,
what was learned the hard way, and what is still open. The user-facing guide is `README.md`.

## The project

Valdoria is a private Open Tibia server for the owner (GitHub: realangelodev), currently played and
tested locally on their own Windows PC. A move to an Ubuntu machine is planned for later (see README).

| Part | What it is |
|---|---|
| Server | The Forgotten Server **1.4.2**, protocol **10.98**, the official Windows build (`theforgottenserver-x64.exe`, downloaded by setup, not in git). Source is vendored in `server/` for the later Linux build. |
| Database | MariaDB 10.4.32 from **XAMPP** (`C:\xampp`). DB `forgottenserver`, user `forgottenserver` / password `valdoria` (also in `server/config.lua` and `windows/common.ps1`). |
| Website | **MyAAC 1.9.5** in `C:\xampp\htdocs`, served by XAMPP's Apache, with our own template `website/valdoria/`. |
| Client | **OTClientV8** (Windows build) in `client/`, adapted for Valdoria. |
| Map editor | Remere's Map Editor in `RME\` on the owner's PC (not in git). Its data comes from `tools/rme/1098/`. |
| Items | Items up to Tibia 15.x from the pack <https://github.com/Levi999x/15.x-with-8.60>. |

- Repository: <https://github.com/realangelodev/ValdoriaOT> (branch `main`).
- On the owner's PC: `C:\Users\angel\Desktop\valdoria-ots` (a git clone; Windows 11, Danish locale).
- The owner's website account is `angelo7713`; their character is **Kazz** in the Owner group (id 7 in `groups.xml`; setup moves group-6 "GOD " characters there and drops the prefix). XAMPP's MySQL root
  user has no password.

## How the owner works with it (all double-click .bat files in the project folder)

- **`update.bat`**: `git pull --rebase --autostash` from GitHub, then runs `setup.bat`. This is how every
  change reaches the PC: push to `main`, then tell the owner to run `update.bat`. Never send zips any more.
- **`setup.bat`** (`windows/setup.ps1`, safe to rerun): VC++ runtime; downloads the TFS Windows build;
  starts MySQL; repairs MySQL's system tables (`mysqlcheck --repair --databases mysql`); rebuilds the
  `forgottenserver` DB user from scratch; imports `schema.sql` if needed; installs/updates MyAAC and our
  template; sets highscores/online caches to 1 minute; replaces MyAAC's sample news and the
  Downloads/Commands/Rules pages (`website/pages/install-pages.php`, only if still the samples); copies
  Tibia.dat/.spr into `client\data\things\1098` from `Desktop\otclientv8-master` if missing; packs the
  website's client download; copies `tools/rme/1098` + the server's items.otb/xml into `RME\data\1098`
  (first time backs up `1098-original`); stops what it started.
- **`start.bat`** (`windows/start.ps1`): starts MySQL and Apache hidden, runs the game server in the window.
  **Stop with Ctrl+C** (saves players, then stops web and DB). Closing the window also saves.
- **`backup.bat`**: mysqldump to `backups\`.
- Play: `client\otclient_gl.exe` (or `otclient_dx.exe`). Website: <http://localhost>.
- `.env` (from `.env.example`): ADMIN_* (used once at first install), SITE_URL, TZ, CLIENT_FOLDER,
  DISCORD_URL.

## What has been built

### Website (MyAAC template `website/valdoria/`)
- Design the owner signed off on: warm dark background, gold and ember accents (**no blue/navy** on the
  site), Cinzel headings, Alegreya Sans body text. The name "Valdoria" is in **Uncial Antiqua** with a
  **carved gold** look made by inline SVG filters (`carve-lg/md/sm` in `template.php`), not a gradient.
- Top bar: crest + name, tabs (News, Account, Community, Library), each with a **dropdown** of pages with
  icons (styled after a reference screenshot the owner sent). The class is `mainnav-drop`, because MyAAC's
  admin toolbar styles `.dropdown` and broke the menu for admins.
- Front page hero: castle on a crag against a sunset, crest, "Your adventure awaits", status pill.
- Sidebar: account box (initial, name, My account / New character / Log out) or login form; Server box
  (Online/Offline label + big players-online number); Top players (our own SQL in `template.php`, because
  MyAAC's `getTopPlayers` hides everything on account 1, which is the owner's account).
- Footer: links row, Discord button (`DISCORD_URL` in `.env`, written to `discord.url` by setup), small
  copyright line.
- Own Twig templates: highscores, online, serverinfo (no IP/port), team, characters (profile),
  characters.form (search bar), guilds.list, account.management, account.characters.create,
  tables.headline (MyAAC's boxed sections), news, news.tickers.
- Owner rules for all text: **never show the server IP or port**, never say "old-school", never mention
  "OTClient" (say "download our client").

### Client (`client/`)
- OTClientV8 (MIT licence), Windows files only. `init.lua`: `APP_NAME = "valdoria"`, all OTCv8 online
  services off, `Servers = { Valdoria = "127.0.0.1:7171:1098" }`, `ALLOW_CUSTOM_SERVERS = false`.
- Login screen: only account name, password, remember password, Login (token field removed, server/IP/
  version pickers hidden; window height reduced by exactly the token block).
- `mods/valdoria_titles/`: shows **[OWNER]** in blue (`#4fa8ff`) above "Kazz" and "Angelo" with
  `creature:setTitle(text, "verdana-11px-rounded", color)`. Confirmed working in game.
- `client/data/things/1098/Tibia.dat/.spr` are **not in git** (CipSoft files, `.gitignore`d). The owner
  compiled the pack's files to 10.98 with Object Builder and placed them there.

### Items up to 15.x (server)
- `server/data/items/items.otb` is the pack's (52,277 items). Its version label was changed from 8.60
  (3.20) to 10.98 (3.57), because TFS 1.4.2 refuses an older label; contents unchanged. It keeps our old
  item numbers: 25,526 of our 26,282 items map to the same client id; the only difference used on the map
  is item 598 (lava, different lava graphic).
- `items.xml`: our original entries for all existing items, plus the pack's entries for new items
  (26382-44715). The pack's own versions of old items were not used (it changes e.g. ramps).
- 129 new items (server ids 55334+, no names) are grounds in Tibia.dat but were plain items in the
  pack's items.otb, so RME didn't see them as grounds; they are now group 1 with their dat speed
  (`tools/dat_grounds.py`, `tools/otb_fix_grounds.py`). Border/on-top flags were checked against the dat:
  all correct. items.otb now has 3,424 grounds.
- 139 item names became ambiguous (e.g. "tower shield"), which made TFS drop whole loot lists; those loot
  entries in 173 monster files now use item ids. Four unknown shootTypes were mapped to known ones.
- Verified: the real server starts under Wine with the new files, map and all monsters load, no warnings.

### Outfits and mounts
- `server/data/XML/outfits.xml`: our outfits plus the pack's 166 new ones (83 female, 83 male), appended.
  The outfit window shows at most 255 per player, so there is still room.
- `server/data/XML/mounts.xml`: our 102 mounts plus 153 of the pack's, renumbered to ids 103-255, because
  TFS 1.4.2 keeps mount ids in one byte. No ids are left; the pack's "Radiant Nimbus" and "Broken Moon"
  did not fit. Adding more would need source changes (Mount id type, PSTRG_MOUNTS_RANGE_SIZE) and a
  rebuilt server.
- Verified: the server starts under Wine with both files, no warnings.

### Map editor data (`tools/`)
- `tools/rme_convert.py` translates the opentibiabr Remere's Map Editor materials (client-id based)
  to our item numbers through items.otb, choosing the same-named item when several share a graphic, and
  keeps what only the original 10.98 data had. Output in `tools/rme/1098/` (see `tools/rme/README.md`).
- Checked by script: all 3,295 grounds and all 52,277 items are placeable; no dangling references; nothing
  from the original 10.98 data lost. **~1,194 new grounds have no border definitions anywhere** (palette
  "Grounds without borders"); borders for them would have to be written by hand.
- Items no brush covers are in **Unsorted: ...** palettes by kind (walls and architecture 4,024, borders
  2,518, overhead 634, decorations 1,849, floor decorations 9,442, items 2,927, containers 1,042), taken
  from Tibia.dat flags (`tools/rme/dat_flags.json`). ~18,000 of them have no name; Canary's items.xml
  names only ~6,600 (many "reserved sprite"). Real wall/ground brushes for them would have to be written.
- The owner has a folder `C:\Users\angel\Desktop\15.10.2daede` (a 15.10 Tibia.dat/.spr or client?);
  not looked at yet: ask for a `dir /s` listing first.
- In RME: Preferences > Client Version > set client path to `client\data\things\1098`, **untick "Check
  file signatures"**.

### Map editor status (latest)
- RME load errors from the owner's screenshots (missing "to" brushes, non-ground items in ground brushes,
  items in two brushes, inline ground equivalents, empty carpet slots) are fixed; `tools/rme_check.py`
  applies RME's loading rules and reports none.
- `dat-grounds.bat` lists the grounds in the client's Tibia.dat. The owner's compiled 10.98 file has the
  same 3,329 "Is ground" / 2,954 "Full ground" graphics as the pack. 3,327 have a server ground item; the
  2 without (client 21477, an alternate lava picture, and 25755, "reserved sprite") were deliberately NOT
  added at the owner's request.
- The ornamented palette matches the opentibiabr source completely; new 15.x floors nobody has sorted sit
  in "Grounds without borders". Automap colours can't separate ornamented from nature grounds. The owner
  chose to leave the palettes as they are.

## Lessons learned (avoid repeating these)
- **MySQL on the owner's PC got badly damaged once**: a junk `multi-master.info`, a stuck mysqld holding
  port 3306, then corrupt Aria system tables (`global_priv`). It was fixed by restoring XAMPP's clean
  `C:\xampp\mysql\backup\mysql` into `data\mysql` and deleting `aria_log*`. Root cause was likely that an
  edit had accidentally deleted `Stop-Database` from `windows/common.ps1` (now restored and waiting until
  mysqld exits). Start-Database now also closes anything on port 3306, deletes replication files and
  starts with `--skip-slave-start`. Don't copy rows out of a damaged Aria table: it hangs.
- Windows PowerShell 5.1: scripts must be **ASCII only**; native stderr + `ErrorActionPreference=Stop`
  is fatal, so functions running MySQL tools set `Continue` locally. `.ps1`/`.bat` are CRLF via
  `.gitattributes`. After editing a script with Python, parse-check it with pwsh.
- When editing big scripts with string slicing, check nothing else was removed (that is how
  `Stop-Database` and the zip path variables got lost).

## How to work with the owner
- They want **local** solutions for now; don't build things for other players unless asked (a player
  launcher/updater was built and rejected).
- **Search first, then act** when the question is about how something is done in OT tooling.
- Show options as images when it's about looks; they decide quickly. Keep messages short and say exactly
  which .bat to run. Push to GitHub, then tell them to run `update.bat`.
- Test before saying something works, and say plainly what could not be tested here.

## Testing setup used so far (cloud session)
- A fake XAMPP (`htdocs` served by PHP's built-in server, MariaDB in Docker) to run `setup.ps1` with pwsh,
  render the website with Playwright, and run the TFS x64 exe under Wine.
- The OTClientV8 exes are 32-bit and could not run under that Wine, so client changes are untested there.
- otland.net is blocked from the cloud environment; GitHub and web search work.

## Open items / next steps
1. **Confirm the latest update on the PC**: owner runs `update.bat`, `start.bat`, logs in with the new
   Tibia.dat/.spr; try `/i 30000` (new item ids are 26382-44715). Check the client shows no errors.
2. ~~Confirm [OWNER] title~~ and ~~rename the GOD character~~: both done.
3. **Outfits and mounts** were added; the owner should check them in game (the GOD character can use any
   outfit; players need `unlocked="yes"` or to be given them).
4. **Discord link**: owner hasn't given an invite; `DISCORD_URL` in `.env` is empty (button goes to
   discord.com).
5. **Map editor**: owner should open RME after updating and report load warnings. Borders for the new
   grounds don't exist; add them one by one if they ask.
7. **Website client download** (`C:\xampp\htdocs\files\Valdoria-Client.zip`) was packed from an older
   client; delete it and rerun setup to repack (it now includes the ~430 MB Tibia.spr).
8. **Playing with friends** and **moving to Ubuntu**: documented in README, not done yet. For friends,
   `ip` in `server/config.lua` and the address in `client/init.lua` must become the public address.
9. The website's character outfit images come from outfit-images.ots.me (external); fine on the PC.
