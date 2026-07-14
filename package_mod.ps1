param(
    [string]$ModId = "Secdude-FruitAggregator"
)

$OutZip = "$ModId.zip"
$SourceDir = "$ModId"

if (-Not (Test-Path $SourceDir)) {
    Write-Error "Mod directory '$SourceDir' not found."
    exit 1
}

$TempDir = Join-Path $env:TEMP "BrotatoPack_$ModId"
if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
$TargetDir = Join-Path $TempDir "mods-unpacked\$ModId"
$null = New-Item -ItemType Directory -Path $TargetDir -Force

Copy-Item -Path "$SourceDir\*" -Destination $TargetDir -Recurse -Exclude "*.zip", ".git"

if (Test-Path $OutZip) { Remove-Item $OutZip -Force }

# Zip the "mods-unpacked" folder so it extracts with the correct hierarchy
Compress-Archive -Path "$TempDir\mods-unpacked" -DestinationPath $OutZip -Force

Remove-Item $TempDir -Recurse -Force

Write-Host "Successfully packaged $ModId into $OutZip"
