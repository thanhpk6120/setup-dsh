# install.ps1 - One-line installer for setup-dsh (DeepSeek Harness)
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
    if (Test-Path $zipFile) { Remove-Item -Force $zipFile -ErrorAction SilentlyContinue }
    if (Test-Path $tempBase) { Remove-Item -Recurse -Force $tempBase -ErrorAction SilentlyContinue }
}
