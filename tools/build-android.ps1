param(
    [string]$OutputPath = 'builds/android/RINNER-debug.apk'
)
$ErrorActionPreference = 'Stop'
$RinnerRoot = Split-Path -Parent $PSScriptRoot
$RinnerVersion = '4.7.2-stable'
$RinnerEngine = Join-Path $RinnerRoot ".tools\Godot_v${RinnerVersion}_win64_console.exe"
$RinnerTemplates = Join-Path $RinnerRoot '.tools\export_templates\4.7.2.stable'

if (-not (Test-Path $RinnerEngine)) {
    & (Join-Path $PSScriptRoot 'setup-godot.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Godot setup failed.' }
}
if (-not (Test-Path (Join-Path $RinnerTemplates 'android_debug.apk'))) {
    $RinnerArchiveName = "Godot_v${RinnerVersion}_export_templates.tpz"
    $RinnerRelease = "https://github.com/godotengine/godot/releases/download/$RinnerVersion"
    $RinnerArchive = Join-Path ([IO.Path]::GetTempPath()) $RinnerArchiveName
    Write-Host 'Downloading the official export template archive (about 1.2 GB, first build only)...'
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri "$RinnerRelease/$RinnerArchiveName" -OutFile $RinnerArchive
    $RinnerSums = (Invoke-WebRequest -UseBasicParsing -Uri "$RinnerRelease/SHA512-SUMS.txt").Content
    $RinnerLine = $RinnerSums -split "`n" | Where-Object { $_ -match ([regex]::Escape($RinnerArchiveName) + '$') }
    if (-not $RinnerLine) { throw 'Official export template checksum not found.' }
    $RinnerExpected = ($RinnerLine.Trim() -split '\s+')[0]
    if ((Get-FileHash -Path $RinnerArchive -Algorithm SHA512).Hash -ne $RinnerExpected) {
        throw 'Export template SHA512 verification failed.'
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $RinnerTemplates | Out-Null
    $RinnerZip = [IO.Compression.ZipFile]::OpenRead($RinnerArchive)
    try {
        foreach ($RinnerFile in @('android_debug.apk', 'android_release.apk', 'version.txt')) {
            $RinnerEntry = $RinnerZip.GetEntry("templates/$RinnerFile")
            if ($null -eq $RinnerEntry) { throw "Missing template: $RinnerFile" }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($RinnerEntry, (Join-Path $RinnerTemplates $RinnerFile), $true)
        }
    } finally {
        $RinnerZip.Dispose()
    }
    Remove-Item $RinnerArchive
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $RinnerRoot $OutputPath
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
& $RinnerEngine --headless --path $RinnerRoot --editor --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot project import failed.' }
& $RinnerEngine --headless --path $RinnerRoot --script res://tools/sync_songs.gd
if ($LASTEXITCODE -ne 0) { throw 'Song bundling failed. Check the saved charts and their audio paths.' }
& $RinnerEngine --headless --path $RinnerRoot --export-debug Android $OutputPath
if ($LASTEXITCODE -ne 0) { throw 'Android export failed. Check the Android SDK and Java SDK paths in Godot Editor Settings.' }
$RinnerApk = Get-Item $OutputPath
Write-Host ('APK ready: {0} ({1:N1} MB)' -f $RinnerApk.FullName, ($RinnerApk.Length / 1MB))
