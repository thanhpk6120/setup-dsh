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

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "             SETUP-DSH INSTALLER - INTERACTIVE SETUP            " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Kiểm tra Node.js và Git trong hệ thống
Write-Host "==> Kiem tra Node.js va Git trong he thong..." -ForegroundColor Cyan
foreach ($tool in @("node", "git")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Loi: Thieu '$tool' trong PATH. Vui long cai dat '$tool' truoc."
    }
}

# 2. Cấu hình kết nối AI Provider
Write-Host ""
Write-Host "==> Cau hinh ket noi AI Provider..." -ForegroundColor Cyan
$defaultAiUrl = "http://localhost:20128/v1"
if ($env:AI_BASE_URL) { $defaultAiUrl = $env:AI_BASE_URL }
$inputAiUrl = Read-Host "Nhap AI Base URL [Mac dinh: $defaultAiUrl]"
$aiBaseUrl = if ([string]::IsNullOrWhiteSpace($inputAiUrl)) { $defaultAiUrl } else { $inputAiUrl.Trim() }

$aiApiKey = ""
if ($env:AI_API_KEY) { $aiApiKey = $env:AI_API_KEY }
while ([string]::IsNullOrWhiteSpace($aiApiKey)) {
    $inputKey = Read-Host "Nhap AI API Key (Bat buoc, khong co mac dinh)"
    if (-not [string]::IsNullOrWhiteSpace($inputKey)) {
        $aiApiKey = $inputKey.Trim()
    } else {
        Write-Host "Loi: AI API Key khong duoc bo trong. Vui long nhap khoa hop le." -ForegroundColor Red
    }
}

# 3. Cau hinh tien ich bo sung (Memorix)
Write-Host ""
Write-Host "==> Cau hinh tien ich bo sung..." -ForegroundColor Cyan
$selectedMemorix = $null

if ($PSBoundParameters.ContainsKey('EnableMemorix')) {
    $selectedMemorix = $true
} elseif ($PSBoundParameters.ContainsKey('DisableMemorix')) {
    $selectedMemorix = $false
} else {
    $existingMemorix = Get-Command "memorix" -ErrorAction SilentlyContinue
    if ($existingMemorix) {
        Write-Host "==> Phat hien he thong da co san Memorix tai: $($existingMemorix.Source)" -ForegroundColor Green
        Write-Host "==> Tu dong bat Memorix va cap nhat len phien ban moi nhat." -ForegroundColor Green
        $selectedMemorix = $true
    } else {
        $memorixPrompt = Read-Host "Ban co muon cai dat them tien ich Memorix (quan ly memory, reasoning, project history) khong? [y/N]"
        if (-not [string]::IsNullOrWhiteSpace($memorixPrompt) -and $memorixPrompt.Trim().ToLower() -eq 'y') {
            $selectedMemorix = $true
        } else {
            $selectedMemorix = $false
        }
    }
}

$env:AI_BASE_URL = $aiBaseUrl
$env:AI_API_KEY = $aiApiKey

# 4. Tải hoặc xác định gói cài đặt
$zipUrl = "https://github.com/thanhpk6120/setup-dsh/archive/refs/heads/main.zip"
$tempBase = Join-Path $env:TEMP ("dsh-install-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("dsh-repo-" + [System.Guid]::NewGuid().ToString("N") + ".zip")

# Hàm dọn dẹp bằng cách di chuyển vào Thùng rác (Recycle Bin)
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

try {
    # Kiểm tra nếu đang chạy trực tiếp trong repo có sẵn bootstrap.ps1
    $localBootstrap = Join-Path $PSScriptRoot "bootstrap.ps1"
    $bootstrapScript = ""

    if (Test-Path $localBootstrap) {
        Write-Host "==> Su dung ma nguon cuc bo tai: $PSScriptRoot" -ForegroundColor Green
        $bootstrapScript = $localBootstrap
    } else {
        Write-Host "==> Dang tai goi setup-dsh tu GitHub ($zipUrl)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

        Write-Host "==> Dang giai nen tap tin..." -ForegroundColor Cyan
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

        # Ghi file .env tạm thời để bootstrap.ps1 có thể nạp
        $envFilePath = Join-Path $extractedRoot ".env"
        $envContent = @"
AI_BASE_URL=$aiBaseUrl
AI_API_KEY=$aiApiKey
"@
        [System.IO.File]::WriteAllText($envFilePath, $envContent, [System.Text.UTF8Encoding]::new($false))
    }

    Write-Host "==> Kich hoat bootstrap.ps1..." -ForegroundColor Cyan
    $bootstrapParams = @{}
    if ($PSBoundParameters.ContainsKey('Force')) { $bootstrapParams['Force'] = $Force }
    if ($PSBoundParameters.ContainsKey('OverwriteAll')) { $bootstrapParams['OverwriteAll'] = $OverwriteAll }
    if ($PSBoundParameters.ContainsKey('DryRun')) { $bootstrapParams['DryRun'] = $DryRun }
    if ($PSBoundParameters.ContainsKey('SkipInstall')) { $bootstrapParams['SkipInstall'] = $SkipInstall }
    if ($PSBoundParameters.ContainsKey('DshHome')) { $bootstrapParams['DshHome'] = $DshHome }
    if ($PSBoundParameters.ContainsKey('DshProfileDir')) { $bootstrapParams['DshProfileDir'] = $DshProfileDir }
    if ($PSBoundParameters.ContainsKey('CredentialsPath')) { $bootstrapParams['CredentialsPath'] = $CredentialsPath }
    if ($selectedMemorix -ne $null) {
        if ($selectedMemorix) { $bootstrapParams['EnableMemorix'] = $true } else { $bootstrapParams['DisableMemorix'] = $true }
    }

    $paramList = @()
    foreach ($key in $bootstrapParams.Keys) {
        if ($bootstrapParams[$key] -eq $true) {
            $paramList += "-$key"
        } elseif ($bootstrapParams[$key] -eq $false) {
            # omit false switch
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
Write-Host " CAI DAT HOAN TAT CHO DSH (DEEPSEEK HARNESS)!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
