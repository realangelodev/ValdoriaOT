<#
.SYNOPSIS
  Sets up Valdoria on Windows: the official TFS 1.4.2 Windows build,
  a database in XAMPP's MariaDB, and the MyAAC website in XAMPP's Apache.

.DESCRIPTION
  Run it through setup.bat in the repo folder. It is safe to run again; every step checks
  what is already done and skips it.

  1. Checks for the Microsoft Visual C++ runtime the server needs, and installs it if missing.
  2. Downloads the official TFS 1.4.2 Windows build and puts the .exe and its DLLs in server\.
  3. Creates the "forgottenserver" database and user in XAMPP's MariaDB and loads schema.sql.
  4. Installs MyAAC into XAMPP's htdocs and runs its installer with your .env details.
  5. Applies the Valdoria website design and replaces MyAAC's sample news with a welcome post.

.PARAMETER XamppPath
  Where XAMPP is installed. Defaults to C:\xampp.

.PARAMETER RootPassword
  The MariaDB root password, if you gave XAMPP's root user one. XAMPP leaves it empty by default.

.PARAMETER WebUrl
  Where XAMPP's Apache answers on this PC. Change it if Apache uses another port, e.g. http://127.0.0.1:8080
#>
param(
  [string]$XamppPath = 'C:\xampp',
  [string]$RootPassword = '',
  [string]$WebUrl = 'http://127.0.0.1'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # the progress bar makes downloads very slow in Windows PowerShell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Root = Split-Path -Parent $PSScriptRoot
$Server = Join-Path $Root 'server'
$OnWindows = $env:OS -eq 'Windows_NT'
. (Join-Path $PSScriptRoot 'common.ps1')

$Tfs = @{
  Url    = 'https://github.com/otland/forgottenserver/releases/download/v1.4.2/tfs-v1.4.2-windows-vcpkg.zip'
  Sha256 = 'E44507EA2E99C270A40D5DFA5E8AF8D41AF72D36112394AAA465BB244BE4F923'
  Folder = 'forgottenserver-1.4.2'
}
$MyAac = @{
  Url    = 'https://github.com/slawkens/myaac/releases/download/v1.9.5/myaac-1.9.5.zip'
  Sha256 = '6154AECD52359A788E8681027B7B58FECA7AB2521442760D1E41925104DBA1E7'
  Folder = 'myaac-1.9.5'
}

function Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }
function Info($text) { Write-Host "   $text" }
function Fail($text) { Write-Host ''; Write-Host "!! $text" -ForegroundColor Red; exit 1 }

function Get-Verified($spec, $name) {
  $zip = Join-Path ([IO.Path]::GetTempPath()) $name
  Info "Downloading $($spec.Url)"
  Invoke-WebRequest -Uri $spec.Url -OutFile $zip -UseBasicParsing
  $hash = (Get-FileHash -Path $zip -Algorithm SHA256).Hash
  if ($hash -ne $spec.Sha256) {
    Remove-Item $zip -Force
    Fail "The download of $name doesn't match the expected checksum, so it was deleted. Try again later."
  }
  $out = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetFileNameWithoutExtension($name) + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
  Expand-Archive -Path $zip -DestinationPath $out -Force
  Remove-Item $zip -Force
  return (Join-Path $out $spec.Folder)
}

# Reads KEY=VALUE lines from .env, creating it from .env.example the first time.
function Read-Settings {
  $envFile = Join-Path $Root '.env'
  if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $Root '.env.example') $envFile
    Info 'Created .env with the default admin login. Notepad will open so you can change it;'
    Info 'save and close Notepad to continue.'
    if ($OnWindows) { Start-Process notepad.exe -ArgumentList "`"$envFile`"" -Wait }
  }
  $settings = @{}
  foreach ($line in Get-Content $envFile) {
    if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { $settings[$Matches[1]] = $Matches[2] }
  }
  foreach ($key in 'ADMIN_ACCOUNT', 'ADMIN_PASSWORD', 'ADMIN_EMAIL', 'ADMIN_CHARACTER') {
    if (-not $settings[$key]) { Fail "$key is empty in .env. Fill it in and run setup.bat again." }
  }
  if (-not $settings['SITE_URL']) { $settings['SITE_URL'] = 'http://localhost' }
  if (-not $settings['TZ']) { $settings['TZ'] = 'UTC' }
  return $settings
}

$RootAuth = @('-h', '127.0.0.1', '-u', 'root')
if ($RootPassword) { $RootAuth += "-p$RootPassword" }

function Invoke-Sql([string[]]$auth, [string]$sql, [string]$database = '') {
  $ErrorActionPreference = 'Continue' # see the note in common.ps1; failures are caught by the exit code below
  $sqlArgs = $auth + @('-N', '-B')
  if ($database) { $sqlArgs += $database }
  $sqlArgs += @('-e', $sql)
  $output = & $MysqlExe @sqlArgs 2>&1
  if ($LASTEXITCODE -ne 0) { throw (($output | ForEach-Object { "$_" }) -join "`n") }
  return $output
}

Write-Host 'Valdoria setup for Windows' -ForegroundColor Green
$settings = Read-Settings

# ---- 1. Visual C++ runtime -------------------------------------------------------------------
Step 'Checking the Microsoft Visual C++ runtime'
if ($OnWindows) {
  $sys = Join-Path $env:WINDIR 'System32'
  if ((Test-Path (Join-Path $sys 'vcruntime140_1.dll')) -and (Test-Path (Join-Path $sys 'msvcp140.dll'))) {
    Info 'Already installed.'
  } else {
    $vc = Join-Path ([IO.Path]::GetTempPath()) 'vc_redist.x64.exe'
    Info 'Not found. Downloading it from Microsoft and starting the installer...'
    Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile $vc -UseBasicParsing
    Start-Process -FilePath $vc -ArgumentList '/install', '/passive', '/norestart' -Wait
    Remove-Item $vc -Force
    Info 'Installed.'
  }
} else {
  Info 'Skipped (not running on Windows).'
}

# ---- 2. The game server ----------------------------------------------------------------------
Step 'Getting The Forgotten Server 1.4.2 for Windows'
$exe = Join-Path $Server 'theforgottenserver-x64.exe'
if (Test-Path $exe) {
  Info 'Already in the server folder.'
} else {
  $tfsDir = Get-Verified $Tfs 'tfs-v1.4.2-windows.zip'
  Copy-Item (Join-Path $tfsDir '*.exe') $Server
  Copy-Item (Join-Path $tfsDir '*.dll') $Server
  Remove-Item (Split-Path $tfsDir -Parent) -Recurse -Force
  Info 'Copied theforgottenserver-x64.exe and its DLLs into the server folder.'
}

# ---- 3. The database -------------------------------------------------------------------------
Step 'Setting up the database in XAMPP'
if (-not (Test-Path $MysqlExe)) {
  Fail "XAMPP isn't installed at $XamppPath. Install it from https://www.apachefriends.org (the PHP 8.2 version), then run setup.bat again. If XAMPP is somewhere else, run: setup.bat -XamppPath D:\xampp"
}
# Last resort when MySQL's own tables are too damaged to start or repair: put back the clean copy that
# XAMPP ships in mysql\backup\mysql (the same fix that worked by hand before). The damaged copy is moved
# to mysql\mysql-damaged-<date>, not deleted. Only MySQL's own tables (users, settings) are replaced;
# the game's database is a separate folder and is not touched. Setup recreates the game's user below.
function Restore-SystemTables {
  $dataDir = Join-Path $XamppPath 'mysql\data'
  $backup = Join-Path $XamppPath 'mysql\backup\mysql'
  if (-not (Test-Path $backup)) { Fail "MySQL's own tables are damaged and XAMPP's clean copy ($backup) is missing. Reinstall XAMPP's MySQL." }
  Info "Putting back XAMPP's clean copy of MySQL's own tables..."
  Get-MysqlProcess | Stop-Process -Force -ErrorAction SilentlyContinue
  if (-not (Wait-Until { -not (Get-MysqlProcess) } 30)) { Fail 'Could not close MySQL. Close the XAMPP Control Panel and any MySQL window, then run setup.bat again.' }
  $kept = Join-Path $XamppPath ('mysql\mysql-damaged-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  Move-Item (Join-Path $dataDir 'mysql') $kept
  Copy-Item $backup (Join-Path $dataDir 'mysql') -Recurse
  # Aria's log still describes the damaged tables; MySQL makes a fresh one.
  Get-ChildItem -Path $dataDir -File | Where-Object { $_.Name -like 'aria_log*' } | Remove-Item -Force
  try { Start-Database | Out-Null } catch { Fail $_.Exception.Message }
  Info "Done. The damaged copy is in $kept (safe to delete)."
}

try { $startedDb = Start-Database }
catch {
  # MySQL that won't start at all is usually its own damaged tables; anything else (port taken) stops here.
  if ($_.Exception.Message -notmatch 'MySQL did not start') { Fail $_.Exception.Message }
  Info 'MySQL would not start. Its own tables are probably damaged.'
  Restore-SystemTables
  $startedDb = $true
}
Info 'MySQL is running.'
try { Invoke-Sql $RootAuth 'SELECT 1' | Out-Null }
catch { Fail 'MySQL refused the root login. If you gave XAMPP''s root user a password, run: setup.bat -RootPassword yourpassword' }

# A MySQL crash (for example the PC restarting while MySQL runs in the background) can damage MySQL's
# own user tables: "Index for table 'global_priv' is corrupt". mysqlcheck --repair does not fix that
# (it even reports the table as OK), so check each of MySQL's Aria tables properly, and if one is
# damaged, stop MySQL, repair it with aria_chk (MariaDB's own offline repair tool) and start it again.
function Get-DamagedSystemTables {
  $tables = Invoke-Sql $RootAuth "SELECT table_name FROM information_schema.tables WHERE table_schema = 'mysql' AND engine = 'Aria'"
  $damaged = @()
  foreach ($table in $tables) {
    $table = "$table".Trim()
    if (-not $table) { continue }
    try { $result = Invoke-Sql $RootAuth "CHECK TABLE mysql.``$table`` EXTENDED" | Out-String }
    catch { $result = 'error' }
    if ($result -match '\terror\t|corrupt|crashed') { $damaged += $table }
  }
  return $damaged
}
$damaged = @(Get-DamagedSystemTables)
if ($damaged.Count -gt 0) {
  Info "MySQL's own tables are damaged ($($damaged -join ', ')). Repairing them..."
  $ariaChk = Join-Path $MysqlBin 'aria_chk.exe'
  if (-not (Test-Path $ariaChk)) { Fail "Can't find $ariaChk to repair MySQL's tables." }
  $ErrorActionPreference = 'Continue' # see the note in common.ps1
  # aria_chk only works while MySQL is closed. A damaged user table can make MySQL ignore the shutdown
  # request, so if it is still open after a short wait, close it by force (the tables get repaired anyway).
  & $MysqlAdmin @RootAuth shutdown 2>&1 | Out-Null
  if (-not (Wait-Until { -not (Get-MysqlProcess) } 20)) {
    Info 'MySQL did not close by itself. Closing it...'
    Get-MysqlProcess | Stop-Process -Force -ErrorAction SilentlyContinue
    if (-not (Wait-Until { -not (Get-MysqlProcess) } 30)) { Fail 'Could not close MySQL. Close the XAMPP Control Panel and any MySQL window, then run setup.bat again.' }
  }
  $dataDir = Join-Path $XamppPath 'mysql\data'
  foreach ($table in $damaged) {
    $tablePath = Join-Path $dataDir "mysql\$table"
    $out = & $ariaChk -r --datadir="$dataDir" $tablePath 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      # -o is aria_chk's slower, more careful repair, for damage that -r gives up on.
      $out = & $ariaChk -o --datadir="$dataDir" $tablePath 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { Info "aria_chk could not repair ${table}:"; Info $out.Trim() }
    }
    # After a forced close MySQL can refuse a repaired table as "from another system and must be
    # zerofilled". Zerofilling marks it as belonging to this MySQL again.
    & $ariaChk --zerofill --datadir="$dataDir" $tablePath 2>&1 | Out-Null
  }
  $ErrorActionPreference = 'Stop'
  $restarted = $true
  try { Start-Database | Out-Null } catch { $restarted = $false }
  if (-not $restarted -or @(Get-DamagedSystemTables).Count -gt 0) {
    Info 'The repair was not enough.'
    Restore-SystemTables
    $still = @(Get-DamagedSystemTables)
    if ($still.Count -gt 0) { Fail "MySQL's tables $($still -join ', ') are still damaged after putting back XAMPP's clean copy." }
  }
  $startedDb = $true
  Info 'Repaired.'
}

# The game's database user is rebuilt from scratch every time. Removing it straight from MySQL's
# tables (not with DROP USER) also clears half-deleted leftovers, which a MySQL crash can leave behind
# and which make CREATE USER and ALTER USER fail with error 1396.
Invoke-Sql $RootAuth @"
CREATE DATABASE IF NOT EXISTS ``$DbName`` CHARACTER SET utf8mb4;
DELETE FROM mysql.global_priv WHERE User = '$DbUser';
DELETE FROM mysql.db WHERE User = '$DbUser';
DELETE FROM mysql.tables_priv WHERE User = '$DbUser';
DELETE FROM mysql.columns_priv WHERE User = '$DbUser';
DELETE FROM mysql.procs_priv WHERE User = '$DbUser';
DELETE FROM mysql.proxies_priv WHERE User = '$DbUser';
FLUSH PRIVILEGES;
CREATE USER '$DbUser'@'localhost' IDENTIFIED BY '$DbPass';
CREATE USER '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPass';
GRANT ALL PRIVILEGES ON ``$DbName``.* TO '$DbUser'@'localhost';
GRANT ALL PRIVILEGES ON ``$DbName``.* TO '$DbUser'@'127.0.0.1';
GRANT SHUTDOWN ON *.* TO '$DbUser'@'localhost';
GRANT SHUTDOWN ON *.* TO '$DbUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@ | Out-Null
Info "Database '$DbName' and user '$DbUser' are ready."

$hasTables = Invoke-Sql $UserAuth "SHOW TABLES LIKE 'players'" $DbName
if ($hasTables) {
  Info 'The game tables already exist.'
} else {
  $schema = (Join-Path $Server 'schema.sql') -replace '\\', '/'
  Invoke-Sql $UserAuth "source $schema" $DbName | Out-Null
  Info 'Created the game tables from schema.sql.'
}

# ---- 4. The website --------------------------------------------------------------------------
Step 'Installing the MyAAC website into XAMPP'
$htdocs = Join-Path $XamppPath 'htdocs'
$lock = Join-Path $htdocs 'install\install.lock'
if (Test-Path $lock) {
  Info 'MyAAC is already installed.'
} else {
  if (-not (Test-Path (Join-Path $htdocs 'system\init.php'))) {
    # Keep XAMPP's own start page instead of deleting it.
    if (Test-Path $htdocs) {
      $existing = @(Get-ChildItem -Force $htdocs)
      if ($existing.Count) {
        $backup = Join-Path $XamppPath 'htdocs-xampp-original'
        New-Item -ItemType Directory -Force $backup | Out-Null
        $existing | Move-Item -Destination $backup -Force
        Info "Moved XAMPP's default start page to $backup"
      }
    } else {
      New-Item -ItemType Directory -Force $htdocs | Out-Null
    }
    $aacDir = Get-Verified $MyAac 'myaac-1.9.5.zip'
    Get-ChildItem -Force $aacDir | Move-Item -Destination $htdocs -Force
    Remove-Item (Split-Path $aacDir -Parent) -Recurse -Force
    Info "Copied MyAAC into $htdocs"
  }

  # Optional PHP extensions: gd draws player signatures, zip installs website plugins.
  $phpIni = Join-Path $XamppPath 'php\php.ini'
  if (Test-Path $phpIni) {
    $ini = Get-Content $phpIni -Raw
    $updated = $ini -replace '(?m)^;[ \t]*extension[ \t]*=[ \t]*(gd|zip)[ \t]*(?=\r?$)', 'extension=$1'
    if ($updated -ne $ini) {
      Set-Content -Path $phpIni -Value $updated -NoNewline
      Info 'Enabled the gd and zip PHP extensions.'
      if (Test-WebServer $WebUrl) { Stop-WebServer; Start-Sleep -Seconds 2 } # restart Apache to load them
    }
  }

  try { $startedWeb = Start-WebServer $WebUrl } catch { Fail $_.Exception.Message }
  Info 'Apache is running.'

  # Run MyAAC's own installer, exactly as if someone clicked through http://localhost/install.
  # It only answers to addresses listed in ip.txt.
  Set-Content -Path (Join-Path $htdocs 'install\ip.txt') -Value "127.0.0.1`r`n::1"
  $install = "$WebUrl/install/"
  $session = $null
  function Invoke-Installer([string]$url, [hashtable]$form, [string]$what) {
    $params = @{ Uri = $url; UseBasicParsing = $true; WebSession = $script:session; TimeoutSec = 300 }
    if ($form) {
      $pairs = foreach ($key in $form.Keys) { [uri]::EscapeDataString($key) + '=' + [uri]::EscapeDataString([string]$form[$key]) }
      $params.Method = 'Post'
      $params.ContentType = 'application/x-www-form-urlencoded'
      $params.Body = $pairs -join '&'
    }
    $response = Invoke-WebRequest @params
    if ($response.Content -match 'alert-danger|class="error"|Fatal error') {
      $text = ($response.Content -replace '<[^>]+>', ' ' -replace '\s+', ' ')
      $hint = [regex]::Matches($text, '[^.]*(error|fail|please|must)[^.]*\.', 'IgnoreCase') | Select-Object -First 3 | ForEach-Object { $_.Value.Trim() }
      Fail "The website installer reported a problem during ${what}: $($hint -join ' ')"
    }
  }
  $first = Invoke-WebRequest -Uri "${install}?step=welcome" -UseBasicParsing -SessionVariable newSession
  $script:session = $newSession

  $serverPath = ($Server -replace '\\', '/') + '/'
  Info 'Saving the site configuration...'
  Invoke-Installer "${install}?step=database" @{
    'vars[site_url]' = $settings['SITE_URL']; 'vars[server_path]' = $serverPath;
    'vars[date_timezone]' = $settings['TZ']; 'vars[client]' = '1098'; 'vars[usage]' = '0'
  } 'configuration'
  Info 'Creating the website tables...'
  Invoke-Installer "${install}tools/5-database.php" $null 'database setup'
  Info "Creating the admin account '$($settings['ADMIN_ACCOUNT'])' and character '$($settings['ADMIN_CHARACTER'])'..."
  Invoke-Installer "${install}?step=finish" @{
    'vars[account]' = $settings['ADMIN_ACCOUNT']; 'vars[email]' = $settings['ADMIN_EMAIL'];
    'vars[password]' = $settings['ADMIN_PASSWORD']; 'vars[password_confirm]' = $settings['ADMIN_PASSWORD'];
    'vars[player_name]' = $settings['ADMIN_CHARACTER']
  } 'admin account creation'
  Invoke-Installer "${install}tools/7-finish.php" $null 'the final step'
  Info "MyAAC is installed. Website: $($settings['SITE_URL'])"
}

# The website reads config.lua and data\ from the server folder. Point it at this copy, so moving or
# renaming the folder (or extracting a new version elsewhere) keeps the website working.
$localConfig = Join-Path $htdocs 'config.local.php'
if (Test-Path $localConfig) {
  $serverPathPhp = ($Server -replace '\\', '/') + '/'
  $configText = Get-Content $localConfig -Raw
  # In the replacement, $$ is a literal dollar sign.
  $updated = [regex]::Replace($configText, "\`$config\['server_path'\]\s*=\s*'[^']*';", "`$`$config['server_path'] = '$serverPathPhp';")
  if ($updated -ne $configText) { Set-Content -Path $localConfig -Value $updated -NoNewline; Info "The website now reads the server files from $Server" }
}

# ---- 5. The Valdoria website design -------------------------------------------------------
Step 'Applying the Valdoria website design'
$templateDir = Join-Path $htdocs 'templates\valdoria'
if (Test-Path $templateDir) { Remove-Item $templateDir -Recurse -Force }
Copy-Item (Join-Path $Root 'website\valdoria') $templateDir -Recurse
# The footer's Discord button links to DISCORD_URL from .env.
if ($settings['DISCORD_URL']) { Set-Content -Path (Join-Path $templateDir 'discord.url') -Value $settings['DISCORD_URL'] -NoNewline }
$php = Join-Path $XamppPath 'php\php.exe'
Push-Location $htdocs
try {
  $ErrorActionPreference = 'Continue' # see the note in common.ps1
  & $php aac settings:set core.template valdoria 2>&1 | Out-Null
  $setOk = $LASTEXITCODE -eq 0
  # Highscores and the online list refresh every minute instead of every 15.
  & $php aac settings:set core.highscores_cache_ttl 1 2>&1 | Out-Null
  & $php aac settings:set core.online_cache_ttl 1 2>&1 | Out-Null
  & $php aac cache:clear 2>&1 | Out-Null
  $ErrorActionPreference = 'Stop'
} finally { Pop-Location }
if ($setOk) { Info 'The website now uses the Valdoria design.' }
else { Info 'Copied the design, but could not switch to it. In the admin panel, open Settings and choose the "valdoria" template.' }

# Replace MyAAC's sample news with a welcome post, but only while they are still the untouched samples.
$welcome = '<p>The gates are open. Valdoria is a realm of ancient keeps, deep dungeons and untamed wilds, and it is waiting for its first heroes.</p><p><b>Getting started:</b> create a free account, make your first character, then download our client and log in. New here? Say <i>hi</i> to the townsfolk and ask about their jobs.</p><p>See you in the game!</p>'
Invoke-Sql $UserAuth @"
UPDATE myaac_news SET title = 'Welcome to Valdoria', body = '$welcome' WHERE (title = 'Hello!' AND body LIKE 'MyAAC is just READY%') OR title = 'Welcome to Hollowmere' OR (title = 'Welcome to Valdoria' AND body LIKE '%old-school realm%');
UPDATE myaac_news SET title = 'Server open', body = 'The server is open! Create your account and be among the first adventurers.' WHERE title = 'Hello tickers!' AND body LIKE '%my-aac.org%';
"@ $DbName | Out-Null
Info 'Added the welcome news post.'

# The owner's GOD characters move to the Owner group (7 in groups.xml) and lose the "GOD " in front of
# their name, unless a character with the shorter name already exists. Log out before running this:
# the server saves the group again when an online character logs out.
Invoke-Sql $UserAuth @"
UPDATE players SET group_id = 7 WHERE group_id = 6 AND name LIKE 'GOD %';
UPDATE players p SET p.name = SUBSTRING(p.name, 5) WHERE p.group_id = 7 AND p.name LIKE 'GOD %' AND NOT EXISTS (SELECT 1 FROM (SELECT name FROM players) q WHERE q.name = SUBSTRING(p.name, 5));
"@ $DbName | Out-Null
Info 'Your GOD characters are now in the Owner group.'

# Our own Downloads, Commands and Rules pages in place of MyAAC's samples (pages you edited are kept).
$ErrorActionPreference = 'Continue'
$pagesOut = & $php (Join-Path $Root 'website\pages\install-pages.php') 127.0.0.1 $DbUser $DbPass $DbName 2>&1
$ErrorActionPreference = 'Stop'
Info ("$pagesOut".Trim())

# The game client lives in the client folder of this project. CipSoft's Tibia.dat and Tibia.spr are not in
# the repository, so copy them in once from the OTClientV8 folder on the Desktop if they are missing.
$things = Join-Path $Root 'client\data\things\1098'
if (-not (Test-Path (Join-Path $things 'Tibia.spr')) -and $OnWindows) {
  $oldThings = Join-Path ([Environment]::GetFolderPath('Desktop')) 'otclientv8-master\data\things\1098'
  if ((Test-Path (Join-Path $oldThings 'Tibia.dat')) -and (Test-Path (Join-Path $oldThings 'Tibia.spr'))) {
    New-Item -ItemType Directory -Force -Path $things | Out-Null
    Copy-Item (Join-Path $oldThings 'Tibia.dat'), (Join-Path $oldThings 'Tibia.spr') $things
    Info 'Copied Tibia.dat and Tibia.spr into the client folder.'
  } else {
    Info "Put the 10.98 Tibia.dat and Tibia.spr in $things to play."
  }
}

# The Download button on the website serves htdocs\files\Valdoria-Client.zip, packed from the client
# folder (or CLIENT_FOLDER in .env). Delete the zip and run setup again to repack it after changes.
$files = Join-Path $htdocs 'files'
New-Item -ItemType Directory -Force -Path $files | Out-Null
$clientZip = Join-Path $files 'Valdoria-Client.zip'
$clientFolder = $settings['CLIENT_FOLDER']
if (-not $clientFolder) { $clientFolder = Join-Path $Root 'client' }
if (Test-Path $clientZip) {
  Info 'The client download is ready.'
} elseif ($clientFolder -and (Test-Path $clientFolder)) {
  Info "Packing the client from $clientFolder (this can take a minute)..."
  Compress-Archive -Path (Join-Path $clientFolder '*') -DestinationPath $clientZip
  Info 'The client download is ready.'
} else {
  Info "No client download yet. Put your client zip at $clientZip, or set CLIENT_FOLDER in .env and run setup again."
}

# Map editor: if RME sits in this folder, give it the borders, brushes and palettes for all our items,
# plus the server's item list. The first time, the original data folder is kept as 1098-original.
$rmeData = Join-Path $Root 'RME\data\1098'
if (Test-Path $rmeData) {
  $rmeBackup = Join-Path $Root 'RME\data\1098-original'
  if (-not (Test-Path $rmeBackup)) { Copy-Item $rmeData $rmeBackup -Recurse }
  Copy-Item (Join-Path $Root 'tools\rme\1098\*.xml') $rmeData -Force
  Copy-Item (Join-Path $Server 'data\items\items.otb'), (Join-Path $Server 'data\items\items.xml') $rmeData -Force
  Info 'Updated the map editor (RME) with all items, borders and palettes.'
}

# Leave things as we found them: start.bat starts MySQL and Apache whenever the server runs.
if ($startedWeb) { Stop-WebServer }
if ($startedDb) { Stop-Database }

Write-Host ''
Write-Host 'All set!' -ForegroundColor Green
Write-Host '  1. Double-click start.bat. It starts the database, the website and the game server together.'
Write-Host "  2. Open $($settings['SITE_URL']) to create accounts."
Write-Host '  3. Log in with your client on 127.0.0.1, port 7171.'
