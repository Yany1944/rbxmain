# Обновление Control и панели на сервере напрямую с этого компьютера, без GitHub.
# Запуск из корня проекта:  powershell -ExecutionPolicy Bypass -File control-server\deploy\deploy.ps1
param(
  [string]$Server = 'root@193.39.143.31',
  [string]$Key = "$env:USERPROFILE\.ssh\skin_relay"
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..").Path

# Тесты запускаются на сервере на Node 24 до переключения релиза
$archive = Join-Path $env:TEMP 'violite-release.tgz'
Remove-Item $archive -ErrorAction SilentlyContinue
# Секреты и база никогда не попадают в архив
tar -czf $archive -C $root `
  --exclude='*.sqlite*' --exclude='config.json' --exclude='FIRST-LOGIN.txt' `
  --exclude='__pycache__' --exclude='node_modules' --exclude='*.md' `
  admin-panel control-server
if ($LASTEXITCODE) { throw 'Packing failed' }

Write-Host '== Upload'
scp -i $Key -q $archive "${Server}:/tmp/violite-release.tgz"
if ($LASTEXITCODE) { throw 'Upload failed' }

# release.sh берётся из того же архива; CRLF после git на Windows убирается
$remote = 'rm -rf /tmp/violite-deploy && mkdir /tmp/violite-deploy && ' +
  'tar -xzf /tmp/violite-release.tgz -C /tmp/violite-deploy control-server/deploy/release.sh && ' +
  "sed -i 's/\r$//' /tmp/violite-deploy/control-server/deploy/release.sh && " +
  'sh /tmp/violite-deploy/control-server/deploy/release.sh /tmp/violite-release.tgz'
ssh -i $Key $Server $remote
$code = $LASTEXITCODE
Remove-Item $archive -ErrorAction SilentlyContinue
if ($code) { throw 'Release failed on the server (see output above)' }
Write-Host 'Panel: https://panel.193-39-143-31.sslip.io'
