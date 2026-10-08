# install.ps1 - One-line interactive installer for setup-dsh (DeepSeek Harness)
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$OverwriteAll,
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$EnableMemorix,
    [switch]$DisableMemorix,
    [string]$DshHome,
    [string]$DshProfileDir,
    [string]$CredentialsPath
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "       SETUP-DSH (DEEPSEEK HARNESS) - INTERACTIVE INSTALLER     " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Kiểm tra DSH CLI trong PATH
Write-Host "==> Kiểm tra DSH CLI trong hệ thống..." -ForegroundColor Cyan
$dshCmd = Get-Command "dsh" -ErrorAction SilentlyContinue
if (-not $dshCmd) {
    $shellName = if ($PSVersionTable.PSEdition -eq 'Core') { "PowerShell Core (pwsh)" } elseif ($PSVersionTable.PSEdition -eq 'Desktop') { "Windows PowerShell 5.1" } else { "Command Prompt / Shell" }
    Write-Warning "Không tìm thấy 'dsh' trong PATH (Môi trường phát hiện: $shellName)."
    $installChoice = Read-Host "DSH CLI chưa được cài đặt. Bạn có muốn cài đặt chính gốc ngay bây giờ không? [Y/n]"
    $installChoice = if ($installChoice) { $installChoice.Trim() } else { "Y" }
    if ($installChoice -notmatch '^[nN]$') {
        Write-Host "==> Đang cài đặt DSH CLI chính gốc từ nhà phát triển..." -ForegroundColor Cyan
        try {
            npm install -g deepseek-harness --silent
        } catch {
            Write-Warning "Cài đặt DSH CLI tự động gặp lỗi: $($_.Exception.Message)"
        }

        # Nạp lại $env:Path trong session hiện tại
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"

        $dshCmd = Get-Command "dsh" -ErrorAction SilentlyContinue
        if ($dshCmd) {
            Write-Host "==> Đã cài đặt và nhận diện thành công DSH CLI tại: $($dshCmd.Source)" -ForegroundColor Green
        } else {
            Write-Warning "Đã nạp lại PATH nhưng chưa nhận diện được lệnh 'dsh'. Nếu là ứng dụng Desktop, bạn có thể khởi chạy qua Start Menu."
        }
    } else {
        Write-Host "==> Bỏ qua bước cài đặt DSH CLI." -ForegroundColor Yellow
    }
} else {
    Write-Host "==> Đã phát hiện DSH CLI tại: $($dshCmd.Source)" -ForegroundColor Green
}

# 2. Hỏi tương tác cấu hình AI Provider
Write-Host ""
Write-Host "==> Cấu hình kết nối AI Provider..." -ForegroundColor Cyan
$defaultAiUrl = if ($env:AI_BASE_URL) { $env:AI_BASE_URL } else { "http://localhost:20128/v1" }
$inputAiUrl = Read-Host "Nhập AI Base URL [Mặc định: $defaultAiUrl]"
$aiBaseUrl = if ([string]::IsNullOrWhiteSpace($inputAiUrl)) { $defaultAiUrl } else { $inputAiUrl.Trim() }

$aiApiKey = ""
if ($env:AI_API_KEY -and -not [string]::IsNullOrWhiteSpace($env:AI_API_KEY)) {
    $aiApiKey = $env:AI_API_KEY.Trim()
    Write-Host "==> Sử dụng AI_API_KEY từ biến môi trường hiện tại." -ForegroundColor Green
} else {
    while ($true) {
        $inputKey = Read-Host "Nhập AI API Key (Bắt buộc)"
        if (-not [string]::IsNullOrWhiteSpace($inputKey)) {
            $aiApiKey = $inputKey.Trim()
            break
        }
        Write-Host "Cảnh báo: AI API Key là bắt buộc, không được để trống! Vui lòng nhập lại." -ForegroundColor Yellow
    }
}

# 3. Hỏi tương tác cài đặt Memorix (Mặc định: Tự động kích hoạt nếu đã có CLI, hoặc hỏi người dùng)
Write-Host ""
Write-Host "==> Cấu hình tiện ích bổ sung..." -ForegroundColor Cyan
if ($PSBoundParameters.ContainsKey('EnableMemorix')) {
    $enableMemorix = $EnableMemorix.IsPresent
} elseif ($PSBoundParameters.ContainsKey('DisableMemorix')) {
    $enableMemorix = -not $DisableMemorix.IsPresent
} else {
    if (Get-Command "memorix" -ErrorAction SilentlyContinue) {
        Write-Host "==> Đã phát hiện Memorix CLI trong hệ thống. Tự động kích hoạt và cập nhật lên phiên bản mới nhất..." -ForegroundColor Green
        $enableMemorix = $true
    } else {
        $memorixChoice = Read-Host "Bạn có muốn cài đặt Memorix (MCP & Session Memory) không? [y/N]"
        $enableMemorix = if (-not [string]::IsNullOrWhiteSpace($memorixChoice) -and $memorixChoice.Trim().ToLower() -eq 'y') { $true } else { $false }
    }
}

$env:AI_BASE_URL = $aiBaseUrl
$env:AI_API_KEY = $aiApiKey

# Lưu cấu hình vào file .env tạm thời nếu chưa có
$localEnvPath = Join-Path $PWD ".env"
if (-not (Test-Path $localEnvPath)) {
    $envContent = @"
AI_BASE_URL=$aiBaseUrl
AI_API_KEY=$aiApiKey
JIRA_URL=https://jira.cybertech.vn
JIRA_PERSONAL_TOKEN=
CONFLUENCE_URL=https://conf.cybertech.vn
CONFLUENCE_PERSONAL_TOKEN=
CONTEXT7_API_KEY=
GITLAB_HOST=10.30.1.17
GITLAB_TOKEN=
"@
    Set-Content -Path $localEnvPath -Value $envContent -Encoding UTF8
    Write-Host "==> Đã lưu cấu hình ban đầu vào $localEnvPath" -ForegroundColor DarkGray
}

# 4. Tải hoặc xác định gói cài đặt
$zipUrl = "https://github.com/thanhpk6120/setup-dsh/archive/refs/heads/main.zip"
$tempBase = Join-Path $env:TEMP ("dsh-install-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("dsh-repo-" + [System.Guid]::NewGuid().ToString("N") + ".zip")

# Hàm dọn dẹp bằng cách di chuyển vào Thùng rác (Recycle Bin)
Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
function Safe-Trash {
    param([string]$Target)
    if ($Target -and (Test-Path -LiteralPath $Target)) {
        if (Get-Command "trash" -ErrorAction SilentlyContinue) {
            trash $Target
            return
        }
        try {
            if ([System.IO.Directory]::Exists($Target)) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Target, 'OnlyErrorDialogs', 'SendToRecycleBin')
            } elseif ([System.IO.File]::Exists($Target)) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Target, 'OnlyErrorDialogs', 'SendToRecycleBin')
            }
        } catch {
            Write-Warning "Không thể di chuyển '$Target' vào Thùng rác: $($_.Exception.Message)"
        }
    }
}

try {
    # Kiểm tra nếu đang chạy trực tiếp trong repo có sẵn bootstrap.ps1
    $localBootstrap = Join-Path $PSScriptRoot "bootstrap.ps1"
    $bootstrapScript = ""

    if (Test-Path $localBootstrap) {
        Write-Host "==> Sử dụng mã nguồn cục bộ tại: $PSScriptRoot" -ForegroundColor Green
        $bootstrapScript = $localBootstrap
    } else {
        Write-Host "==> Đang tải gói setup-dsh từ GitHub ($zipUrl)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

        Write-Host "==> Đang giải nén tập tin..." -ForegroundColor Cyan
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
    }

    $bootstrapParams = @{}
    if ($Force) { $bootstrapParams['Force'] = $true }
    if ($OverwriteAll) { $bootstrapParams['OverwriteAll'] = $true }
    if ($DryRun) { $bootstrapParams['DryRun'] = $true }
    if ($SkipInstall) { $bootstrapParams['SkipInstall'] = $true }
    if ($enableMemorix) { $bootstrapParams['EnableMemorix'] = $true } else { $bootstrapParams['DisableMemorix'] = $true }
    if ($DshHome) { $bootstrapParams['DshHome'] = $DshHome }
    if ($DshProfileDir) { $bootstrapParams['DshProfileDir'] = $DshProfileDir }
    if ($CredentialsPath) { $bootstrapParams['CredentialsPath'] = $CredentialsPath }

    Write-Host "==> Kích hoạt bootstrap.ps1..." -ForegroundColor Cyan
    & $bootstrapScript @bootstrapParams
}
finally {
    if (Test-Path $zipFile) { Safe-Trash -Target $zipFile }
    if (Test-Path $tempBase) { Safe-Trash -Target $tempBase }
}
