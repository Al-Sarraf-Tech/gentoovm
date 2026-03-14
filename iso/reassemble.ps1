# GentooVM ISO Reassembly Script (PowerShell / Windows)
# Downloads are split due to GitHub's 2GB file size limit.
# This script safely reassembles and verifies the ISO.

$ErrorActionPreference = "Stop"

Write-Host "`nGentooVM ISO Reassembly" -ForegroundColor Cyan
Write-Host ""

# Check parts exist
$parts = Get-ChildItem -Filter "gentoovm.iso.part.*" -ErrorAction SilentlyContinue | Sort-Object Name
if (-not $parts -or $parts.Count -eq 0) {
    Write-Host "Error: No gentoovm.iso.part.* files found in current directory." -ForegroundColor Red
    Write-Host "Download all part files into the same directory and run this script again."
    exit 1
}

Write-Host "Found $($parts.Count) parts:"
foreach ($p in $parts) {
    $sizeMB = [math]::Round($p.Length / 1MB, 1)
    Write-Host "  $($p.Name) ($sizeMB MB)"
}
Write-Host ""

# Reassemble
Write-Host "Reassembling..." -ForegroundColor Yellow
$output = "gentoovm.iso"
if (Test-Path $output) {
    Remove-Item $output -Force
}

$outStream = [System.IO.File]::Create($output)
try {
    foreach ($p in $parts) {
        Write-Host "  Reading $($p.Name)..."
        $inStream = [System.IO.File]::OpenRead($p.FullName)
        try {
            $inStream.CopyTo($outStream)
        } finally {
            $inStream.Close()
        }
    }
} finally {
    $outStream.Close()
}

$isoSize = [math]::Round((Get-Item $output).Length / 1GB, 2)
Write-Host "  Created: $output ($isoSize GB)" -ForegroundColor Green
Write-Host ""

# Verify
Write-Host "Verifying integrity..." -ForegroundColor Yellow
if (Test-Path "gentoovm.iso.sha256") {
    $expected = (Get-Content "gentoovm.iso.sha256").Split(" ")[0].Trim()
    $actual = (Get-FileHash -Algorithm SHA256 $output).Hash.ToLower()

    if ($actual -eq $expected) {
        Write-Host "ISO verified successfully!" -ForegroundColor Green
    } else {
        Write-Host "CHECKSUM MISMATCH - the ISO may be corrupted. Re-download all parts." -ForegroundColor Red
        Write-Host "  Expected: $expected"
        Write-Host "  Got:      $actual"
        exit 1
    }
} else {
    Write-Host "  Warning: gentoovm.iso.sha256 not found - cannot verify." -ForegroundColor Yellow
    Write-Host "  Download it from the release page."
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Write-Host "You can now:"
Write-Host "  1. Delete the part files"
Write-Host "  2. Boot the ISO - see README.md or GETTING-STARTED.md for instructions"
Write-Host ""
