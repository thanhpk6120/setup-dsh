# install.ps1 - One-line installer for setup-dsh (DeepSeek Harness)
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (-not $env:AI_BASE_URL) {
    $env:AI_BASE_URL = "http://localhost:20128/v1"
}


$zipUrl = "https://github.com/thanhpk6120/setup-dsh/archive/refs/heads/main.zip"
$tempBase = Join-Path $env:TEMP ("dsh-install-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("dsh-repo-" + [System.Guid]::NewGuid().ToString("N") + ".zip")

try {
    Write-Host "==> Downloading setup-dsh package from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    Write-Host "==> Extracting files..." -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath $tempBase -Force

    $extractedRoot = Join-Path $tempBase "setup-dsh-main"
    if (-not (Test-Path $extractedRoot)) {
        $found = Get-ChildItem -Directory $tempBase | Select-Object -First 1
        if ($found) { $extractedRoot = $found.FullName }
    }

    $bootstrapScript = Join-Path $extractedRoot "bootstrap.ps1"
    if (-not (Test-Path $bootstrapScript)) {
        throw "Lỗi: Không tìm thấy bootstrap.ps1 trong gói cài đặt."
    }

    Write-Host "==> Launching bootstrap..." -ForegroundColor Cyan
    & $bootstrapScript
}
finally {
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    function Safe-Trash($p) {
        if ($p -and (Test-Path $p)) {
            if (Get-Command "trash" -ErrorAction SilentlyContinue) {
                trash $p
            } else {
                try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, 'OnlyErrorDialogs', 'SendToRecycleBin') } catch {}
                try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin') } catch {}
            }
        }
    }
    Safe-Trash $zipFile
    Safe-Trash $tempBase
}
