# install.ps1 - One-line interactive installer for setup-dsh (DeepSeek Harness)
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$Force,
    [switch]$OverwriteAll,
    [switch]$EnableMemorix,
    [switch]$DisableMemorix,
    [string]$DshHome,
    [string]$DshProfileDir,
    [string]$CredentialsPath
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

function Safe-Trash {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (Get-Command "trash" -ErrorAction SilentlyContinue) {
        trash $Path
        return
    }
    try {
        if ([System.IO.Directory]::Exists($Path)) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } elseif ([System.IO.File]::Exists($Path)) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        }
    } catch {
        Write-Warning "Khong the di chuyen '$Path' vao Thung rac: $($_.Exception.Message)"
    }
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "             SETUP-DSH INSTALLER - INTERACTIVE SETUP            " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Kiem tra DSH Desktop va moi truong runtime (Node.js, Git)
Write-Host "==> Kiem tra ung dung DSH Desktop va runtime..." -ForegroundColor Cyan
$dshExePaths = @(
    "C:\Program Files\DSH Desktop\DSH Desktop.exe",
    "$env:LOCALAPPDATA\Programs\DSH Desktop\DSH Desktop.exe",
    "$env:ProgramFiles\DSH Desktop\DSH Desktop.exe"
)
$dshInstalled = $false
foreach ($exe in $dshExePaths) {
    if (Test-Path $exe) {
        $dshInstalled = $true
        Write-Host "==> Da phat hien DSH Desktop tai: $exe" -ForegroundColor Green
        break
    }
}
if (-not $dshInstalled) {
    $dshAppData = Join-Path $env:APPDATA "dsh-desktop"
    if (Test-Path $dshAppData) {
        Write-Host "==> Da phat hien thu muc profile DSH Desktop tai: $dshAppData" -ForegroundColor Green
        $dshInstalled = $true
    }
}

if (-not $dshInstalled) {
    Write-Host "[!] DSH Desktop chua duoc cai dat trong he thong." -ForegroundColor Yellow
    Write-Host "  -> Luu y: Ban can cai dat ung dung DSH Desktop de su dung profile va harness." -ForegroundColor DarkGray
}

foreach ($tool in @("node", "git")) {
    $toolCmd = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $toolCmd) {
        throw "Loi: Thieu '$tool' trong PATH. Vui long cai dat '$tool' truoc."
    } else {
        Write-Host "  -> Tim thay ${tool}: $($toolCmd.Source)" -ForegroundColor DarkGray
    }
}

# 2. Cau hinh ket noi AI Provider
Write-Host ""
Write-Host "==> Cau hinh ket noi AI Provider..." -ForegroundColor Cyan
$defaultAiUrl = "http://localhost:20128/v1"
if ($env:AI_BASE_URL) { $defaultAiUrl = $env:AI_BASE_URL }
$inputAiUrl = ""
if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
    $inputAiUrl = $defaultAiUrl
} else {
    $inputAiUrl = Read-Host "Nhap AI Base URL [Mac dinh: $defaultAiUrl]"
}
$aiBaseUrl = if ([string]::IsNullOrWhiteSpace($inputAiUrl)) { $defaultAiUrl } else { $inputAiUrl.Trim() }

$aiApiKey = ""
if (-not [string]::IsNullOrWhiteSpace($env:AI_API_KEY)) { $aiApiKey = $env:AI_API_KEY.Trim() }
while ([string]::IsNullOrWhiteSpace($aiApiKey)) {
    if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
        throw "Loi: Dang chay o che do non-interactive nhung AI API Key chua duoc cung cap qua bien moi truong `$env:AI_API_KEY`."
    }
    $inputKey = Read-Host "Nhap AI API Key (Bat buoc)"
    if (-not [string]::IsNullOrWhiteSpace($inputKey)) {
        $aiApiKey = $inputKey.Trim()
        break
    }
    Write-Host "[!] AI API Key khong duoc de trong. Vui long nhap key." -ForegroundColor Yellow
}

# 3. Cau hinh tien ich bo sung (Memorix)
Write-Host ""
Write-Host "==> Cau hinh tien ich bo sung..." -ForegroundColor Cyan
if ($PSBoundParameters.ContainsKey('EnableMemorix')) {
    $enableMemorix = $EnableMemorix.IsPresent
} elseif ($PSBoundParameters.ContainsKey('DisableMemorix')) {
    $enableMemorix = -not $DisableMemorix.IsPresent
} else {
    $memorixCmd = Get-Command "memorix" -ErrorAction SilentlyContinue
    if ($memorixCmd) {
        Write-Host "==> Da phat hien Memorix tren he thong tai: $($memorixCmd.Source)" -ForegroundColor Green
    }
    $installMemorixPrompt = ""
    if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
        $installMemorixPrompt = "n"
    } else {
        $installMemorixPrompt = Read-Host "Ban co muon cai dat Memorix (MCP & Session Memory) khong? [y/N]"
    }
    $enableMemorix = if (-not [string]::IsNullOrWhiteSpace($installMemorixPrompt) -and $installMemorixPrompt.Trim().ToLower() -eq 'y') { $true } else { $false }
}

$env:AI_BASE_URL = $aiBaseUrl
$env:AI_API_KEY = $aiApiKey

# 4. Tai va giai nen setup-dsh tu GitHub
$zipUrl = "https://github.com/thanhpk6120/setup-dsh/archive/refs/heads/main.zip"
$tempBase = Join-Path $env:TEMP ("dsh-install-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("dsh-repo-" + [System.Guid]::NewGuid().ToString("N") + ".zip")

try {
    Write-Host ""
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
        throw "Loi: Khong tim thay bootstrap.ps1 trong goi cai dat."
    }

    Write-Host "==> Launching bootstrap..." -ForegroundColor Cyan
    $bootstrapParams = @{}
    if ($PSBoundParameters.ContainsKey('Force')) { $bootstrapParams['Force'] = $Force }
    if ($PSBoundParameters.ContainsKey('OverwriteAll')) { $bootstrapParams['OverwriteAll'] = $OverwriteAll }
    if ($PSBoundParameters.ContainsKey('DryRun')) { $bootstrapParams['DryRun'] = $DryRun }
    if ($PSBoundParameters.ContainsKey('SkipInstall')) { $bootstrapParams['SkipInstall'] = $SkipInstall }
    if ($PSBoundParameters.ContainsKey('DshHome')) { $bootstrapParams['DshHome'] = $DshHome }
    if ($PSBoundParameters.ContainsKey('DshProfileDir')) { $bootstrapParams['DshProfileDir'] = $DshProfileDir }
    if ($PSBoundParameters.ContainsKey('CredentialsPath')) { $bootstrapParams['CredentialsPath'] = $CredentialsPath }
    if ($enableMemorix) {
        $bootstrapParams['EnableMemorix'] = $true
    } else {
        $bootstrapParams['DisableMemorix'] = $true
    }

    $paramList = @()
    foreach ($key in $bootstrapParams.Keys) {
        if ($bootstrapParams[$key] -eq $true) {
            $paramList += "-$key"
        } else {
            $paramList += "-$key", "$($bootstrapParams[$key])"
        }
    }

    $psExe = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path $psExe)) { $psExe = Join-Path $PSHOME "powershell.exe" }
    if (-not (Test-Path $psExe)) { $psExe = "powershell" }

    $argsArray = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $bootstrapScript) + $paramList
    & $psExe $argsArray
    if ($LASTEXITCODE -ne 0) { throw "bootstrap.ps1 that bai voi ma loi exit code $LASTEXITCODE." }
}
finally {
    if (Test-Path $zipFile) { Safe-Trash -Path $zipFile }
    if (Test-Path $tempBase) { Safe-Trash -Path $tempBase }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " CAI DAT THANH CONG CHO DSH DESKTOP!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
