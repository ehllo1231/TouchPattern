$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$TouchPatternRoot = Split-Path -Parent $PSScriptRoot
$TouchPatternTools = Join-Path $TouchPatternRoot '.tools'
$TouchPatternVersion = '4.7.2-stable'
$TouchPatternArchiveName = "Godot_v${TouchPatternVersion}_win64.exe.zip"
$TouchPatternEngine = Join-Path $TouchPatternTools "Godot_v${TouchPatternVersion}_win64.exe"

if (Test-Path $TouchPatternEngine) {
    Write-Host "Godot is ready: $TouchPatternEngine"
    exit 0
}

New-Item -ItemType Directory -Force -Path $TouchPatternTools | Out-Null
$TouchPatternRelease = "https://github.com/godotengine/godot/releases/download/$TouchPatternVersion"
$TouchPatternArchive = Join-Path $TouchPatternTools $TouchPatternArchiveName
Write-Host 'Fetching official Godot SHA512 checksums...'
$TouchPatternChecksums = (Invoke-WebRequest -UseBasicParsing -Uri "$TouchPatternRelease/SHA512-SUMS.txt" -TimeoutSec 30).Content
# GitHub serves this text file as application/octet-stream, which Windows PowerShell reads as bytes.
if ($TouchPatternChecksums -is [byte[]]) {
    $TouchPatternChecksums = [Text.Encoding]::UTF8.GetString($TouchPatternChecksums)
}
$TouchPatternChecksumLine = $TouchPatternChecksums -split "`n" | Where-Object { $_.TrimEnd() -match ([regex]::Escape($TouchPatternArchiveName) + '$') }
if (-not $TouchPatternChecksumLine) { throw 'Official SHA512 checksum not found.' }
$TouchPatternExpected = ($TouchPatternChecksumLine.Trim() -split '\s+')[0]
$TouchPatternCached = (Test-Path -LiteralPath $TouchPatternArchive) -and
    ((Get-FileHash -LiteralPath $TouchPatternArchive -Algorithm SHA512).Hash -eq $TouchPatternExpected)
if ($TouchPatternCached) {
    Write-Host 'Using the downloaded Godot archive (SHA512 verified).'
} else {
    Write-Host "Downloading Godot $TouchPatternVersion (portable, no system installation)..."
    Invoke-WebRequest -UseBasicParsing -Uri "$TouchPatternRelease/$TouchPatternArchiveName" -OutFile $TouchPatternArchive -TimeoutSec 600
}
$TouchPatternActual = (Get-FileHash -Path $TouchPatternArchive -Algorithm SHA512).Hash
if ($TouchPatternActual -ne $TouchPatternExpected) { throw 'Godot download checksum mismatch.' }
Write-Host 'Extracting Godot...'
Expand-Archive -Path $TouchPatternArchive -DestinationPath $TouchPatternTools -Force
Remove-Item $TouchPatternArchive
Write-Host "Godot is ready: $TouchPatternEngine"
