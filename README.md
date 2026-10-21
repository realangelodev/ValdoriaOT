# Hollowmere OTS

A complete Open Tibia server for **client 10.98**, ready to run on Windows with one double-click:

- **The Forgotten Server 1.4.2**: the official TFS release for 10.98, built from the source in [`server/`](server).
- **MariaDB 10.11** for accounts, characters, houses and guilds.
- **MyAAC 1.9.5**: the website where players create accounts and characters, with highscores, who's online and an admin panel. It installs itself on the first start.

Everything runs in Docker, so you don't have to install a compiler, MySQL, PHP or Apache.

## What you need

- **Windows 10 or 11** with **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** installed and running.
- **[Git](https://git-scm.com/download/win)** to download this repo (or use *Code → Download ZIP* on GitHub).
- **A Tibia 10.98 client** and a way to point it at your server. See [Connecting with a client](#connecting-with-a-client).

## Start the server

```bat
git clone https://github.com/realangelodev/hollowmere-ots.git
cd hollowmere-ots
start.bat
```

On the first run, `start.bat` creates a `.env` file and opens it in Notepad. Set your admin account name, password, email and Game Master character name, then save and close Notepad.

The first start compiles the server, which takes a few minutes. Run `logs.bat` and wait for:

```
server-1  | >> Hollowmere Server Online!
web-1     | [myaac-install] Done. The website is ready at http://localhost
```

Then open **http://localhost**. Log in with the admin account from `.env`, or create a normal account under *Account → Create Account*.

| Script | What it does |
| --- | --- |
| `start.bat` | Builds (first time) and starts the server, database and website |
| `stop.bat` | Stops everything. Accounts and characters are kept. |
| `logs.bat` | Shows the live server and website output |
| `restart-server.bat` | Restarts only the game server, after you edit `config.lua` or `server\data` |
| `backup.bat` | Saves the whole database to `backups\hollowmere_<date>.sql` |

## Connecting with a client

The game client isn't included: it belongs to CipSoft and isn't open source. You need the **10.98** client, the same version this server speaks.

**Login details:** host `127.0.0.1` (or your public IP for friends), port **7171**, plus the account name and password you made on the website.

The regular Tibia client is locked to CipSoft's servers, so use one of these:

- **An IP changer** for 10.98 that also replaces the RSA key. Most OT IP changers do. Point it at `127.0.0.1`, port `7171`.
- **[OTClient](https://github.com/edubart/otclient)** (open source): put the 10.98 `Tibia.dat` and `Tibia.spr` in `data/things/1098/`, choose client version **1098** on the login screen, and use the details above.

This server uses the standard Open Tibia RSA key (`server/key.pem`), which is the one those tools expect.

## Playing with friends

By default the server only accepts connections from your own PC. To let friends in:

1. **Find your public IP**, for example at https://whatismyipaddress.com.
2. **Edit `server\config.lua`** and change `ip = "127.0.0.1"` to your public IP (or a DNS name), e.g. `ip = "203.0.113.25"`.
3. **Edit `.env`** and set `SITE_URL=http://<your public IP>` so the website's links point at the right address.
4. **Forward TCP ports 7171, 7172 and 80** on your router to your PC's local IP (find it with `ipconfig`). Your router's admin page usually calls this *Port Forwarding* or *Virtual Server*.
5. **Allow the ports through Windows Firewall** if Docker Desktop didn't already. Run this in an administrator PowerShell:

   ```powershell
   New-NetFirewallRule -DisplayName "Hollowmere OTS" -Direction Inbound -Protocol TCP -LocalPort 7171,7172,80 -Action Allow
   ```

6. Run `stop.bat`, then `start.bat`.

Friends then connect to your public IP on port 7171 and sign up at `http://<your public IP>`.

> **Playing on the same PC after this change:** the server now tells every client to connect to your public IP. Some routers don't support connecting to your own public IP from inside your network. If your own login hangs at "Connecting to the game world", set `ip` back to `127.0.0.1` while you play alone, or use a free dynamic-DNS name that resolves locally.

## Game Master commands

Your admin character (from `.env`) is a **God**. Say these in the game chat:

| Command | Does |
| --- | --- |
| `/i crystal coin, 100` | Create items, by name or ID |
| `/m dragon` | Summon a monster in front of you |
| `/s Name` | Place an NPC |
| `/goto Name` · `/c Name` | Go to a player, or bring them to you |
| `/t` · `/town Name` | Teleport to your temple, or to a town by name or ID |
| `/a 5` · `/up` · `/down` | Move 5 tiles ahead, or a floor up or down |
| `/ghost` · `/hide` | Turn invisible |
| `/B message` | Broadcast to everyone online |
| `/kick Name` · `/ban Name` · `/unban Name` | Moderation |
| `/addskill Name, level` · `/addskill Name, sword, 5` | Give a player a level, or 5 sword fighting levels (also club, axe, dist, shield, magic) |
| `/reload monsters` | Reload scripts without restarting (actions, monsters, npcs, spells, talkactions, config…) |
| `/closeserver` · `/openserver` | Lock the server for maintenance |

Players have commands too: `!online`, `!serverinfo`, `!uptime`, `!buyhouse`, `!leavehouse` and more. The full list is in `server/data/talkactions/talkactions.xml`.

## Customizing

Everything in [`server/`](server) is the live server. Edit it, then run `restart-server.bat`.

- **Rates, PvP type, premium:** `server/config.lua` (`rateExp`, `experienceStages`, `rateLoot`, `rateSkill`, `worldType`, `freePremium`…). Free premium is **on**, so everyone gets premium features.
- **Monsters, NPCs, spells, items, quests:** `server/data/`
- **The map:** `server/data/world/forgotten.otbm`, the small test map that ships with TFS, with a town, temple and a few hunting spots. Edit it, or replace it with your own, using [Remere's Map Editor](https://github.com/hjnilsson/rme) (it needs the 10.98 client files). If you rename the map, update `mapName` in `config.lua`.
- **C++ source:** `server/src/`. A rebuild picks up changes: `docker compose up -d --build server`.
- **Website:** log in at **http://localhost/admin** with your admin account to change the theme, news, pages, plugins and settings.

## Backups and resetting

- **Back up:** run `backup.bat`.
- **Restore a backup:** with the server running, from a Command Prompt in this folder:

  ```bat
  docker compose exec -T db mariadb -uforgottenserver -phollowmere forgottenserver < backups\hollowmere_2026-10-21_12-00.sql
  ```

- **Wipe everything and start over:** `docker compose down -v` deletes the database **and** the website settings. Back up first. The next `start.bat` sets everything up fresh.

## How it fits together

```
docker-compose.yml       the three services and their settings
.env                     your admin login, website address and time zone (created from .env.example)
server/                  The Forgotten Server 1.4.2: source, datapack, config.lua, schema.sql, key.pem
  Dockerfile             compiles TFS on Ubuntu 22.04 and runs it as a regular user
  entrypoint.sh          waits for the database and creates the tables on the first start
web/                     MyAAC website
  Dockerfile             Apache and PHP 8.3 on Ubuntu 24.04, plus the MyAAC 1.9.5 release (checksum-verified)
  install-myaac.sh       runs MyAAC's own installer on the first start, using your .env details
tools/login-test.py      logs in like a 10.98 client to check the server works end to end
*.bat                    Windows shortcuts for starting, stopping, logs, restarts and backups
```

The database is only reachable from inside Docker, which is why its password can sit in `config.lua` and `docker-compose.yml`. If you ever expose port 3306, change the password in both files first.

To check everything works without a game client:

```bat
python tools\login-test.py hollowadmin ChangeMe123
```

It logs in, lists your characters, and steps into the game world with the first one, the same way the 10.98 client does. It needs `openssl` on your PATH (Git for Windows includes it).

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `start.bat` says Docker isn't running | Open Docker Desktop and wait for *Engine running*. |
| The website doesn't open; port 80 is in use | Set `WEB_PORT=8080` in `.env`, restart, and visit http://localhost:8080 |
| "Account name or password is not correct" | Use the **account name**, not the email or character name. |
| "Only clients with protocol 10.98 allowed!" | Your client isn't 10.98. |
| Login works but the game hangs at "Connecting" | The `ip` in `config.lua` isn't reachable from where you are. See [Playing with friends](#playing-with-friends). |
| The admin account wasn't created | Run `logs.bat` and look for `[myaac-install]` lines. Fix `.env` (the password needs 8–29 characters with a letter and a number), then `docker compose down -v` and `start.bat`. |

## Credits and licenses

- [The Forgotten Server](https://github.com/otland/forgottenserver) by the OTLand community, GPL-2.0. The source and datapack in `server/` are TFS 1.4.2.
- [MyAAC](https://github.com/slawkens/myaac) by slawkens, GPL-3.0. It's downloaded when the website image is built.
- Everything else in this repo is GPL-2.0, the same as TFS. See [LICENSE](LICENSE).

Tibia is a trademark of CipSoft GmbH. This project isn't affiliated with CipSoft and doesn't include any of its client files.
