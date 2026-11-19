$ErrorActionPreference = 'Stop'
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
Write-Host "Downloading Godot $TouchPatternVersion (portable, no system installation)..."
Invoke-WebRequest -UseBasicParsing -Uri "$TouchPatternRelease/$TouchPatternArchiveName" -OutFile $TouchPatternArchive
$TouchPatternChecksums = (Invoke-WebRequest -UseBasicParsing -Uri "$TouchPatternRelease/SHA512-SUMS.txt").Content
$TouchPatternChecksumLine = $TouchPatternChecksums -split "`n" | Where-Object { $_ -match ([regex]::Escape($TouchPatternArchiveName) + '$') }
if (-not $TouchPatternChecksumLine) { throw 'Official SHA512 checksum not found.' }
$TouchPatternExpected = ($TouchPatternChecksumLine.Trim() -split '\s+')[0]
$TouchPatternActual = (Get-FileHash -Path $TouchPatternArchive -Algorithm SHA512).Hash
if ($TouchPatternActual -ne $TouchPatternExpected) { throw 'Godot download checksum mismatch.' }
Expand-Archive -Path $TouchPatternArchive -DestinationPath $TouchPatternTools -Force
Remove-Item $TouchPatternArchive
Write-Host "Godot is ready: $TouchPatternEngine"
