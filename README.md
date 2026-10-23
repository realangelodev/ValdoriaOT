# Valdoria OTS

A complete Open Tibia server for **client 10.98**:

- **The Forgotten Server 1.4.2**: the official TFS release for 10.98. The datapack, config and C++ source are in [`server/`](server).
- **MariaDB** for accounts, characters, houses and guilds.
- **MyAAC 1.9.5**: the website where players create accounts and characters, with highscores, who's online and an admin panel.

It runs on Windows with the official TFS Windows build. [XAMPP](https://www.apachefriends.org) supplies the database and web server programs, and `start.bat` starts and stops them for you, so you never have to open XAMPP. When you're ready to host for real, the same server folder moves to an Ubuntu machine. See [Moving to an Ubuntu server](#moving-to-an-ubuntu-server).

## Run it on Windows

### What you need

- **Windows 10 or 11, 64-bit.**
- **[XAMPP](https://www.apachefriends.org)**, the PHP **8.2** version, installed in `C:\xampp` (the default).
- **This repo**: [download the ZIP](https://github.com/realangelodev/valdoria-ots/archive/refs/heads/main.zip) and unzip it, or `git clone` it.
- **A Tibia 10.98 client.** See [Connecting with a client](#connecting-with-a-client).

### Set it up (once)

Double-click **`setup.bat`** in this folder. The first time, Notepad opens `.env`. Set your admin account name, password (8–29 characters, with a letter and a number), email and Game Master character name, then save and close Notepad.

`setup.bat` then does the rest:

- Installs the Microsoft Visual C++ runtime if your PC doesn't have it.
- Downloads the official TFS 1.4.2 Windows build (`theforgottenserver-x64.exe` and its DLLs) from GitHub, checks it against a known checksum, and puts it in `server\`.
- Starts XAMPP's MySQL, creates the `forgottenserver` database and user, and loads the game tables.
- Starts XAMPP's Apache, installs MyAAC into `C:\xampp\htdocs`, and runs its installer with your `.env` details.
- Applies the custom **Valdoria website design** (from `website/valdoria/`) and replaces MyAAC's sample news with a welcome post.
- Stops MySQL and Apache again when it's done. XAMPP's own start page is moved to `C:\xampp\htdocs-xampp-original`.

It's safe to run again: each step skips itself once it's done. If XAMPP is somewhere else, run `setup.bat -XamppPath D:\xampp`. If you gave MySQL's root user a password, add `-RootPassword yourpassword`.

### Every time you play

Double-click **`start.bat`**. It starts the database and the website in the background, then the game server in its window. When the window says **`>> Valdoria Server Online!`**, log in with your client. Players sign up at **http://localhost**.

To stop, press **Ctrl+C** in the server window. The server saves every player first, then `start.bat` shuts the website and database down too.

If you close the window instead, the server still saves, but MySQL and Apache keep running in the background. That's harmless: the next `start.bat` reuses them.

| Script | What it does |
| --- | --- |
| `setup.bat` | One-time setup, described above |
| `start.bat` | Starts the database, website and game server; stops them all when the server stops |
| `backup.bat` | Saves the whole database to `backups\valdoria_<date>.sql`, whether or not the server is running |

After you edit `server\config.lua` or anything in `server\data`, stop the server and run `start.bat` again. Many changes can also be reloaded in-game with `/reload`.

## Updating

The project lives on GitHub at https://github.com/realangelodev/ValdoriaOT. To get the latest version, double-click **`update.bat`**: it downloads the changes and runs `setup.bat` to apply them. It needs [Git for Windows](https://git-scm.com/download/win) (the default install options are fine).

The first time, it links your existing folder to GitHub and replaces the project files with the latest ones. Your `.env`, the server program, logs and backups are kept. After that, your own edits (for example to `server\config.lua`) are kept too; if one clashes with an update, Git stops and tells you which file, and you can keep yours or take the new one.

## Connecting with a client

The game client isn't included: it belongs to CipSoft and isn't open source. You need the **10.98** client, the same version this server speaks.

**Login details:** host `127.0.0.1` (or your public IP for friends), port **7171**, plus the account name and password you made on the website.

The regular Tibia client is locked to CipSoft's servers, so use one of these:

- **An IP changer** for 10.98 that also replaces the RSA key. Most OT IP changers do. Point it at `127.0.0.1`, port `7171`.
- **[OTClientV8](https://github.com/OTCv8/otclientv8)** (recommended):
  1. Copy [`client/otclientv8/init.lua`](client/otclientv8/init.lua) over the `init.lua` in your OTClientV8 folder. It adds *Valdoria* (`127.0.0.1:7171`, version 1098) to the server list and turns off OTClientV8's own online services.
  2. Put the 10.98 `Tibia.dat` and `Tibia.spr` from your client in `data\things\1098\` inside the OTClientV8 folder.
  3. Start `otclient_gl.exe` (or `otclient_dx.exe`), pick **Valdoria**, and log in.
- **[OTClient](https://github.com/edubart/otclient)** (the original): put the same two files in `data/things/1098/`, choose client version **1098** on the login screen, and use the details above.

This server uses the standard Open Tibia RSA key (`server/key.pem`), which is the one those tools expect.

### Offering the client on the website

The **Download our client** button on the website's Downloads page serves `C:\xampp\htdocs\files\Valdoria-Client.zip`. `setup.bat` makes that zip for you from your client folder: `otclientv8-master` on your Desktop, or whatever folder you put in `CLIENT_FOLDER` in `.env`. Set the client up first (the `init.lua` and the `.dat`/`.spr` files above), then run `setup.bat`. After changing the client, delete the zip and run `setup.bat` again to repack it.

## Playing with friends

By default the server only accepts connections from your own PC. To let friends in:

1. **Find your public IP**, for example at https://whatismyipaddress.com.
2. **Edit `server\config.lua`** and change `ip = "127.0.0.1"` to your public IP (or a DNS name), e.g. `ip = "203.0.113.25"`.
3. **Point the website at your public address** so its links work for friends. Edit `C:\xampp\htdocs\config.local.php` and change `site_url` to `http://<your public IP>`.
4. **Forward TCP ports 7171, 7172 and 80** on your router to your PC's local IP (find it with `ipconfig`). Your router's admin page usually calls this *Port Forwarding* or *Virtual Server*.
5. **Allow the ports through Windows Firewall.** Windows usually asks the first time the server and Apache start; click *Allow*. If it didn't, run this in an administrator PowerShell:

   ```powershell
   New-NetFirewallRule -DisplayName "Valdoria OTS" -Direction Inbound -Protocol TCP -LocalPort 7171,7172,80 -Action Allow
   ```

6. Restart the server: close its window and run `start.bat` again.

Friends then connect to your public IP on port 7171 and sign up at `http://<your public IP>`.

> **Playing on the same PC after this change:** the server now tells every client to connect to your public IP. Some routers don't support connecting to your own public IP from inside your network. If your own login hangs at "Connecting to the game world", set `ip` back to `127.0.0.1` while you play alone, or use a free dynamic-DNS name that resolves locally.

## Moving to an Ubuntu server

Build and test on your PC, then move the finished server to an Ubuntu machine. Nearly everything carries over unchanged:

| What | On Windows | On Ubuntu |
| --- | --- | --- |
| Datapack, map, scripts, `config.lua`, `key.pem` | `server\` | Copy the folder as-is. These files are the same on every OS. |
| Game server program | `theforgottenserver-x64.exe` + DLLs | Doesn't move. Build `tfs` from `server/src` on the Ubuntu machine (a few minutes), or use the official `tfs-v1.4.2-ubuntu-gcc.tar.gz` from the same release. |
| Database (accounts, characters, houses) | XAMPP's MySQL | Export with `backup.bat`, then import the `.sql` into MariaDB on Ubuntu. |
| Website | `C:\xampp\htdocs` | Copy the folder to Apache's web root, and update `server_path` and `site_url` in `config.local.php`. |

The only setting that changes is `ip` in `config.lua`, which becomes the Ubuntu machine's public IP. Don't copy the `.exe` or `.dll` files; they're Windows-only.

On Ubuntu 22.04, building the server takes these packages:

```sh
sudo apt install build-essential cmake libluajit-5.1-dev libmysqlclient-dev libpugixml-dev \
  libcrypto++-dev libfmt-dev libboost-system-dev libboost-iostreams-dev libboost-filesystem-dev \
  libboost-date-time-dev
cd server && sed -i 's/ -Werror//' CMakeLists.txt && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release .. && make -j"$(nproc)" && mv tfs ..
```

The `sed` line keeps newer compiler warnings from stopping the build; the 1.4.2 source predates them. This exact build was tested on Ubuntu 22.04 with this repo.

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

Everything in [`server/`](server) is the live server. Edit it, then restart the server (close the window and run `start.bat`).

- **Rates, PvP type, premium:** `server/config.lua` (`rateExp`, `experienceStages`, `rateLoot`, `rateSkill`, `worldType`, `freePremium`…). Free premium is **on**, so everyone gets premium features.
- **Monsters, NPCs, spells, items, quests:** `server/data/`
- **The map:** `server/data/world/forgotten.otbm`, the small test map that ships with TFS, with a town, temple and a few hunting spots. Edit it, or replace it with your own, using [Remere's Map Editor](https://github.com/hjnilsson/rme) (it needs the 10.98 client files). If you rename the map, update `mapName` in `config.lua`.
- **C++ source:** `server/src/`. You only need it to change the engine itself, and for building the server on Ubuntu later. `server/vc17/` has the Visual Studio project TFS ships with, if you ever want to compile your own `.exe`.
- **Website design:** the template lives in `website/valdoria/`: `template.php` (layout), `style.css` (look) and `menus.php` (default menu links). Edit it there and run `setup.bat` again to copy it into XAMPP. To edit the live copy directly, it's in `C:\xampp\htdocs\templates\valdoria\`.
- **News, menus, pages and settings:** log in at **http://localhost/admin** with your admin account.

## Backups and resetting

- **Back up:** run `backup.bat`.
- **Restore a backup:** stop the game server, then from a Command Prompt in this folder:

  ```bat
  C:\xampp\mysql\bin\mysql.exe -h 127.0.0.1 -uforgottenserver -pvaldoria forgottenserver < backups\valdoria_2026-10-21_12-00.sql
  ```

- **Wipe everything and start over:** drop the `forgottenserver` database in phpMyAdmin (http://localhost/phpmyadmin), delete `C:\xampp\htdocs\install\install.lock`, and run `setup.bat`. Back up first.

## How it fits together

```
setup.bat · start.bat    one-time setup, then start the server
backup.bat               database backup
windows/setup.ps1        what setup.bat runs: VC++ runtime, TFS Windows build, database, MyAAC
windows/start.ps1        what start.bat runs: MySQL and Apache in the background, then the server
windows/backup.ps1       what backup.bat runs
windows/common.ps1       shared helpers for starting and stopping XAMPP's MySQL and Apache
.env                     your admin login, website address and time zone (created from .env.example)
client/otclientv8/       init.lua that adds Valdoria to OTClientV8's server list
website/valdoria/      the custom website design (a MyAAC template)
server/                  The Forgotten Server 1.4.2: source, datapack, config.lua, schema.sql, key.pem
tools/login-test.py      logs in like a 10.98 client to check the server works end to end
```

`config.lua` connects to the database at `127.0.0.1`. The database password sits in `config.lua` and `windows/common.ps1`. That's fine while MySQL isn't reachable from the internet (don't forward port 3306), but if you change it, change it in both.

To check everything works without a game client:

```bat
python tools\login-test.py hollowadmin ChangeMe123
```

It logs in, lists your characters, and steps into the game world with the first one, the same way the 10.98 client does. It needs `openssl` on your PATH (Git for Windows includes it).

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `start.bat` says a DLL is missing (`VCRUNTIME140_1.dll`, `MSVCP140.dll`) | Install the [Visual C++ runtime (x64)](https://aka.ms/vs/17/release/vc_redist.x64.exe), or run `setup.bat` again. |
| `start.bat` says MySQL did not start | Another program is using port 3306, often another MySQL install. Stop it, or look in `C:\xampp\mysql\data\mysql_error.log`. |
| `start.bat` says Apache did not start (port 80 in use) | Another program (often IIS or Skype) has port 80. Stop it, or change Apache's port in `C:\xampp\apache\conf\httpd.conf` (`Listen 8080`) and use `setup.bat -WebUrl http://127.0.0.1:8080` and `start.bat -WebUrl http://127.0.0.1:8080`. |
| "Account name or password is not correct" | Use the **account name**, not the email or character name. |
| "Only clients with protocol 10.98 allowed!" | Your client isn't 10.98. |
| Login works but the game hangs at "Connecting" | The `ip` in `config.lua` isn't reachable from where you are. See [Playing with friends](#playing-with-friends). |
| The admin account wasn't created | `setup.bat` shows the installer's error. The password needs 8–29 characters with a letter and a number. Fix `.env` and run the setup again (see *Wipe everything* above). |

## Credits and licenses

- [The Forgotten Server](https://github.com/otland/forgottenserver) by the OTLand community, GPL-2.0. The source and datapack in `server/` are TFS 1.4.2.
- [MyAAC](https://github.com/slawkens/myaac) by slawkens, GPL-3.0. It's downloaded by `setup.bat`.
- The Windows build of TFS comes from the [official 1.4.2 release](https://github.com/otland/forgottenserver/releases/tag/v1.4.2) and is downloaded by `setup.bat`, not stored in this repo.
- Everything else in this repo is GPL-2.0, the same as TFS. See [LICENSE](LICENSE).

Tibia is a trademark of CipSoft GmbH. This project isn't affiliated with CipSoft and doesn't include any of its client files.
