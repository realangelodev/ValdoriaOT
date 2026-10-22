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
try { $startedDb = Start-Database } catch { Fail $_.Exception.Message }
Info 'MySQL is running.'
try { Invoke-Sql $RootAuth 'SELECT 1' | Out-Null }
catch { Fail 'MySQL refused the root login. If you gave XAMPP''s root user a password, run: setup.bat -RootPassword yourpassword' }

Invoke-Sql $RootAuth @"
CREATE DATABASE IF NOT EXISTS ``$DbName`` CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$DbUser'@'localhost' IDENTIFIED BY '$DbPass';
CREATE USER IF NOT EXISTS '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPass';
ALTER USER '$DbUser'@'localhost' IDENTIFIED BY '$DbPass';
ALTER USER '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPass';
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
$php = Join-Path $XamppPath 'php\php.exe'
Push-Location $htdocs
try {
  $ErrorActionPreference = 'Continue' # see the note in common.ps1
  & $php aac settings:set core.template valdoria 2>&1 | Out-Null
  $setOk = $LASTEXITCODE -eq 0
  & $php aac cache:clear 2>&1 | Out-Null
  $ErrorActionPreference = 'Stop'
} finally { Pop-Location }
if ($setOk) { Info 'The website now uses the Valdoria design.' }
else { Info 'Copied the design, but could not switch to it. In the admin panel, open Settings and choose the "valdoria" template.' }

# Replace MyAAC's sample news with a welcome post, but only while they are still the untouched samples.
$welcome = '<p>The gates are open. Valdoria is an old-school realm in the classic style: no shortcuts, just you, your party and the wilds beyond the town walls.</p><p><b>Getting started:</b> create a free account, make your first character, then download our client and log in. New here? Say <i>hi</i> to the townsfolk and ask about their jobs.</p><p>See you in the game!</p>'
Invoke-Sql $UserAuth @"
UPDATE myaac_news SET title = 'Welcome to Valdoria', body = '$welcome' WHERE (title = 'Hello!' AND body LIKE 'MyAAC is just READY%') OR title = 'Welcome to Hollowmere';
UPDATE myaac_news SET title = 'Server open', body = 'The server is open! Create your account and be among the first adventurers.' WHERE title = 'Hello tickers!' AND body LIKE '%my-aac.org%';
"@ $DbName | Out-Null
Info 'Added the welcome news post.'

# Leave things as we found them: start.bat starts MySQL and Apache whenever the server runs.
if ($startedWeb) { Stop-WebServer }
if ($startedDb) { Stop-Database }

Write-Host ''
Write-Host 'All set!' -ForegroundColor Green
Write-Host '  1. Double-click start.bat. It starts the database, the website and the game server together.'
Write-Host "  2. Open $($settings['SITE_URL']) to create accounts."
Write-Host '  3. Log in with your client on 127.0.0.1, port 7171.'
