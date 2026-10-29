param([string]$BackendRoot = (Join-Path $PSScriptRoot '../../phamngocanh'))
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath (Join-Path $BackendRoot 'phamngocanh.csproj'))) { throw 'Backend project not found.' }
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$packageRoot = Join-Path $workspaceRoot ('build/vps-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (Test-Path -LiteralPath $packageRoot) { throw 'Export folder already exists. Try again in a second.' }
$sourceOut = New-Item -ItemType Directory -Path (Join-Path $packageRoot 'backend')
$deployOut = New-Item -ItemType Directory -Path (Join-Path $packageRoot 'deploy')
foreach ($folder in @('Controllers', 'Data', 'DTOs', 'Models', 'Migrations', 'Services')) {
    Copy-Item -LiteralPath (Join-Path $BackendRoot $folder) -Destination $sourceOut.FullName -Recurse
}
foreach ($file in @('Program.cs', 'phamngocanh.csproj')) {
    Copy-Item -LiteralPath (Join-Path $BackendRoot $file) -Destination $sourceOut.FullName
}
if (Test-Path -LiteralPath (Join-Path $BackendRoot 'WeatherForecast.cs')) {
    Copy-Item -LiteralPath (Join-Path $BackendRoot 'WeatherForecast.cs') -Destination $sourceOut.FullName
}
# Export only a clean config. Connection strings, JWT/SMTP secrets stay out of the archive.
'{"Logging":{"LogLevel":{"Default":"Information","Microsoft.AspNetCore":"Warning"}},"AllowedHosts":"*"}' |
    Set-Content -Encoding utf8 -LiteralPath (Join-Path $sourceOut.FullName 'appsettings.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'backend.dockerignore') -Destination (Join-Path $sourceOut.FullName '.dockerignore')
foreach ($file in @('Dockerfile', 'compose.yaml', 'Caddyfile', '.env.example', 'README.md')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $deployOut.FullName
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open(($packageRoot + '.zip'), [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in (Get-ChildItem -LiteralPath $packageRoot -Recurse -File)) {
        $entryName = $file.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName) | Out-Null
    }
} finally { $zip.Dispose() }
Write-Output ('Exported deployment package without private configuration: ' + $packageRoot + '.zip')
