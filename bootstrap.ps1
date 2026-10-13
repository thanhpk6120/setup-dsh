# bootstrap.ps1 - Bootstrap DSH Desktop environment on fresh machine
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$Force,
    [switch]$OverwriteAll,
    [switch]$EnableMemorix,
    [switch]$DisableMemorix,
    [string]$DshHome = "$env:USERPROFILE\.dsh",
    [string]$DshProfileDir = "$env:APPDATA\dsh-desktop\harness\profiles\web",
    [string]$CredentialsPath = "$env:APPDATA\dsh-desktop\harness\.credentials.yaml"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Ham xac nhan cai dat tung MCP Server (interactive choice y/N, mac dinh N)
function Confirm-McpInstall {
    param([string]$Name)
    if ($DryRun) {
        Write-Host "  -> [WhatIf] Bo qua prompt cai dat MCP '$Name'." -ForegroundColor DarkGray
        return $false
    }
    if (-not [Environment]::UserInteractive -or $env:CI) {
        return $false
    }
    if ($SkipInstall) {
        return $false
    }
    $choice = Read-Host "[?] Cai dat MCP '$Name'? [y/N]"
    if (-not [string]::IsNullOrWhiteSpace($choice) -and ($choice.Trim().ToLower() -eq 'y' -or $choice.Trim().ToLower() -eq 'yes')) {
        return $true
    }
    return $false
}

# Xử lý lựa chọn Memorix
if (-not $PSBoundParameters.ContainsKey('EnableMemorix') -and -not $PSBoundParameters.ContainsKey('DisableMemorix')) {
    $installMemorix = Confirm-McpInstall -Name "memorix"
    if (-not $installMemorix) { Write-Host "Skipped MCP 'memorix' theo lua chon nguoi dung." -ForegroundColor Yellow }
} elseif ($DisableMemorix.IsPresent) {
    $installMemorix = $false
    Write-Host "Skipped MCP 'memorix' theo lua chon nguoi dung." -ForegroundColor Yellow
} else {
    $installMemorix = $EnableMemorix.IsPresent
}

Write-Host "==> Xac nhan cai dat cac MCP Server khac..." -ForegroundColor Cyan
$installAtlassian = Confirm-McpInstall -Name "company-atlassian"
if (-not $installAtlassian) { Write-Host "Skipped MCP 'company-atlassian' theo lua chon nguoi dung." -ForegroundColor Yellow }

$installGitnexus = Confirm-McpInstall -Name "gitnexus"
if (-not $installGitnexus) { Write-Host "Skipped MCP 'gitnexus' theo lua chon nguoi dung." -ForegroundColor Yellow }

$installContext7 = Confirm-McpInstall -Name "context7"
if (-not $installContext7) { Write-Host "Skipped MCP 'context7' theo lua chon nguoi dung." -ForegroundColor Yellow }

$installGlab = Confirm-McpInstall -Name "glab"
if (-not $installGlab) { Write-Host "Skipped MCP 'glab' theo lua chon nguoi dung." -ForegroundColor Yellow }

$installCloakbrowser = Confirm-McpInstall -Name "cloakbrowser"
if (-not $installCloakbrowser) { Write-Host "Skipped MCP 'cloakbrowser' theo lua chon nguoi dung." -ForegroundColor Yellow }

$isForce = $Force.IsPresent -or $OverwriteAll.IsPresent

# 2. Quy tắc an toàn: Safe-Trash (Recycle Bin / Trash)
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

# 3. Nạp biến môi trường từ .env (nếu có)
function Load-Env {
    param([string]$EnvPath = (Join-Path $PSScriptRoot ".env"))
    if (Test-Path $EnvPath) {
        Write-Host "  -> Nạp biến môi trường từ $EnvPath..." -ForegroundColor Cyan
        Get-Content $EnvPath | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#")) {
                $idx = $line.IndexOf("=")
                if ($idx -gt 0) {
                    $key = $line.Substring(0, $idx).Trim()
                    $val = $line.Substring($idx + 1).Trim()
                    if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                        $val = $val.Substring(1, $val.Length - 2)
                    }
                    if (-not [string]::IsNullOrWhiteSpace($key) -and -not [string]::IsNullOrWhiteSpace($val)) {
                        [Environment]::SetEnvironmentVariable($key, $val, "Process")
                    }
                }
            }
        }
    }
}
Load-Env

# 4. Hàm nhập liệu Get-EnvOrPrompt
function Get-EnvOrPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvName,
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [string]$Default,
        [switch]$AllowEmpty
    )
    $val = [Environment]::GetEnvironmentVariable($EnvName, "Process")
    if (-not [string]::IsNullOrWhiteSpace($val)) { return $val }

    $hasDefault = $PSBoundParameters.ContainsKey('Default')
    while ($true) {
        $promptStr = $Prompt
        if ($hasDefault) { $promptStr = "$Prompt (Default: $Default)" }
        $inputVal = Read-Host $promptStr
        if (-not [string]::IsNullOrWhiteSpace($inputVal)) {
            return $inputVal.Trim()
        }
        if ($hasDefault) {
            return $Default
        }
        if ($AllowEmpty) {
            return ""
        }
        if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
            throw "Error: '$EnvName' is required but cannot prompt in non-interactive session."
        }
        Write-Host "Error: '$EnvName' is required. Please provide a value." -ForegroundColor Red
    }
}

# 5. Kiểm tra môi trường Node.js và Git
Write-Host "==> Kiểm tra môi trường runtime..." -ForegroundColor Cyan
foreach ($tool in @("node", "npm", "git")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Lỗi: Không tìm thấy '$tool' trong PATH. Vui lòng cài đặt trước."
    }
}

$nodeVerRaw = (node -v 2>$null | Out-String).Trim()
try {
    $nodeVer = [version]($nodeVerRaw.TrimStart('v'))
} catch {
    throw "Không thể xác định phiên bản Node.js: '$nodeVerRaw'"
}
if ($nodeVer -lt [version]"22.18.0") {
    $toolsList = "gitnexus, context7"
    if ($installMemorix) { $toolsList = "memorix, gitnexus, context7" }
    throw "Yêu cầu Node.js >= 22.18.0 (do $toolsList yêu cầu Node mới). Phiên bản hiện tại: '$nodeVerRaw'. Vui lòng nâng cấp Node.js."
}

# 6. Cài đặt các công cụ phụ thuộc theo lựa chọn MCP
if ($installAtlassian) {
    if (-not $SkipInstall -and -not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
        Write-Host "==> Đang cài đặt uv qua lệnh chính gốc..." -ForegroundColor Cyan
        if (-not $DryRun) {
            try {
                powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
                $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
                $env:Path = "$machinePath;$userPath"
            } catch {
                Write-Warning "Không thể tự động cài đặt uv: $($_.Exception.Message)"
            }
        }
    }

    if (-not $SkipInstall) {
        if (-not $DryRun) {
            if (Get-Command "uv" -ErrorAction SilentlyContinue) {
                $hasAtlassian = $false
                try {
                    $uvList = (uv tool list 2>&1 | Out-String)
                    if ($uvList -match 'mcp-atlassian\s+v?0\.23\.1' -or $uvList -match 'mcp-atlassian') {
                        $hasAtlassian = $true
                    }
                } catch {}

                $uvToolsPath = Join-Path $env:APPDATA "uv\tools\mcp-atlassian"
                if (Test-Path $uvToolsPath) { $hasAtlassian = $true }
                if (Get-Command "mcp-atlassian" -ErrorAction SilentlyContinue) { $hasAtlassian = $true }

                if ($hasAtlassian) {
                    Write-Host "==> mcp-atlassian đã có sẵn trên máy. Bỏ qua cài đặt lại để tránh lỗi khóa file Windows." -ForegroundColor Green
                } else {
                    try {
                        Write-Host "==> Cài đặt mcp-atlassian==0.23.1 qua uv tool..." -ForegroundColor Cyan
                        $installOutput = (uv tool install mcp-atlassian==0.23.1 2>&1 | Out-String)
                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "Cài đặt uv tool mcp-atlassian: $installOutput"
                            Write-Host "==> Lưu ý: DSH chạy qua 'uvx --from mcp-atlassian==0.23.1' nên công cụ vẫn sẽ tự động tải." -ForegroundColor Cyan
                        } else {
                            Write-Host "==> Cài đặt mcp-atlassian thành công." -ForegroundColor Green
                        }
                    } catch {
                        Write-Warning "Cài đặt mcp-atlassian gặp lỗi: $($_.Exception.Message)"
                    }
                }
            } else {
                Write-Warning "'uv' chưa khả dụng trong PATH hiện tại."
            }
        }
    }
}

if ($installGitnexus) {
    if (-not $SkipInstall) {
        Write-Host "==> Cài đặt gitnexus toàn cục..." -ForegroundColor Cyan
        if (-not $DryRun) {
            npm install -g gitnexus --silent
        }
    }
}

if ($installContext7) {
    if (-not $SkipInstall) {
        Write-Host "==> Cài đặt @upstash/context7-mcp toàn cục..." -ForegroundColor Cyan
        if (-not $DryRun) {
            npm install -g @upstash/context7-mcp --silent
        }
    }
}

if ($installGlab) {
    if (-not $SkipInstall -and -not (Get-Command "glab" -ErrorAction SilentlyContinue)) {
        Write-Host "==> Cài đặt glab (GitLab CLI)..." -ForegroundColor Cyan
        if (-not $DryRun) {
            if (Get-Command "winget" -ErrorAction SilentlyContinue) {
                try {
                    winget install -e --id GLab.GLab --silent --accept-source-agreements --accept-package-agreements | Out-Null
                    $glabProg = "$env:LOCALAPPDATA\Programs\glab"
                    if (Test-Path $glabProg) {
                        $env:Path = "$glabProg;$env:Path"
                    }
                } catch {
                    Write-Warning "Không thể cài đặt glab qua winget: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Lệnh 'winget' không khả dụng. Vui lòng tự cài đặt glab."
            }
        }
    }
}

if ($installMemorix) {
    if (-not $SkipInstall) {
        Write-Host "==> Cài đặt memorix toàn cục..." -ForegroundColor Cyan
        if (-not $DryRun) {
            npm install -g memorix
        }
    }

    $shouldSetupHook = $false
    if (-not $DryRun -and [Environment]::UserInteractive -and -not $env:CI -and -not $SkipInstall) {
        $hookChoice = Read-Host "[?] Cai dat Hook tich hop Memorix vao DSH? (Yeu cau cai dat 'bun') [y/N]"
        if (-not [string]::IsNullOrWhiteSpace($hookChoice) -and ($hookChoice.Trim().ToLower() -eq 'y' -or $hookChoice.Trim().ToLower() -eq 'yes')) {
            $shouldSetupHook = $true
        }
    }

    if ($shouldSetupHook) {
        Write-Host "==> Cấu hình hook Memorix cho DSH..." -ForegroundColor Cyan
        $npmPrefix = ""
        try { $npmPrefix = (npm prefix -g 2>$null | Out-String).Trim() } catch {}
        if ($npmPrefix -and (Test-Path $npmPrefix) -and ($env:Path -notlike "*$npmPrefix*")) {
            $env:Path = "$npmPrefix;$env:Path"
        }
        try {
            memorix setup --agent dsh --global
        } catch {
            Write-Warning "Không thể chạy hook 'memorix setup --agent dsh --global': $($_.Exception.Message)"
        }
    } else {
        if (-not $DryRun) {
            Write-Host "==> Bo qua cau hinh hook memorix cho DSH." -ForegroundColor DarkGray
        }
    }
}

# 7. Cấu hình CloakBrowser (nếu được chọn)
function Get-CloakBrowserInstallDir {
    param([string]$EnvVarName = "CLOAKBROWSER_DIR")
    $envVal = [Environment]::GetEnvironmentVariable($EnvVarName, "Process")
    if (-not [string]::IsNullOrWhiteSpace($envVal)) { return $envVal.Trim() }

    $drives = @()
    try {
        $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 } | Sort-Object FreeSpace -Descending
    } catch {
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } | Sort-Object Free -Descending
    }
    if (-not $drives -or $drives.Count -eq 0) { return "$env:USERPROFILE\mcp-servers\cloakbrowser" }

    $defaultDrive = $drives | Where-Object { ($_.DeviceID -eq 'D:' -or $_.Name -eq 'D') } | Select-Object -First 1
    if (-not $defaultDrive) { $defaultDrive = $drives[0] }
    $defaultLetter = ""
    if ($defaultDrive.DeviceID) { $defaultLetter = $defaultDrive.DeviceID } else { $defaultLetter = "$($defaultDrive.Name):" }

    if ([Environment]::GetEnvironmentVariable("CI") -or -not [Environment]::UserInteractive) {
        return "$defaultLetter\mcp-servers\cloakbrowser"
    }

    Write-Host "`n==> Quét danh sách ổ đĩa để cài đặt CloakBrowser MCP:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $d = $drives[$i]
        $devId = ""
        if ($d.DeviceID) { $devId = $d.DeviceID } else { $devId = "$($d.Name):" }
        $volName = ""
        if ($d.VolumeName) { $volName = " ($($d.VolumeName))" }
        $freeVal = $d.Free
        if ($d.FreeSpace) { $freeVal = $d.FreeSpace }
        $freeGB = [math]::Round(($freeVal / 1GB), 2)
        $sizeGB = "N/A"
        if ($d.Size) { $sizeGB = [math]::Round(($d.Size / 1GB), 2) }
        Write-Host "  [$($i+1)] Ổ $devId$volName | Trống: $freeGB GB / $sizeGB GB"
    }

    $promptMsg = "Chọn số thứ tự ổ đĩa muốn lưu CloakBrowser (mặc định ổ $defaultLetter)"
    try {
        $inputVal = Read-Host $promptMsg
        if (-not [string]::IsNullOrWhiteSpace($inputVal)) {
            $parsedIdx = 0
            if ([int]::TryParse($inputVal.Trim(), [ref]$parsedIdx)) {
                if ($parsedIdx -ge 1 -and $parsedIdx -le $drives.Count) {
                    $selectedDrive = $drives[$parsedIdx - 1]
                    $chosenLetter = if ($selectedDrive.DeviceID) { $selectedDrive.DeviceID } else { "$($selectedDrive.Name):" }
                    return "$chosenLetter\mcp-servers\cloakbrowser"
                }
            }
        }
    } catch {}

    return "$defaultLetter\mcp-servers\cloakbrowser"
}

function Setup-CloakBrowser {
    param([string]$TargetDir, [string]$SourceDir, [switch]$DryRun, [switch]$SkipInstall)
    Write-Host "==> Cấu hình CloakBrowser tại: $TargetDir" -ForegroundColor Cyan
    if (-not (Test-Path $TargetDir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
    }

    $mainScript = Join-Path $TargetDir "mcp-server-full.mjs"
    $pkgJson = Join-Path $TargetDir "package.json"
    if ((Test-Path $mainScript) -and (Test-Path $pkgJson)) {
        Write-Host "  -> CloakBrowser đã tồn tại đầy đủ file mã nguồn. Giữ nguyên dữ liệu & profile cũ (không ghi đè)." -ForegroundColor Green
    } else {
        Write-Host "  -> Sao chép mã nguồn CloakBrowser sang $TargetDir..." -ForegroundColor Green
        if (-not $DryRun -and (Test-Path $SourceDir)) {
            Copy-Item -Path "$SourceDir\*" -Destination $TargetDir -Recurse -Force
        }
    }

    $nodeModules = Join-Path $TargetDir "node_modules"
    if (-not $SkipInstall -and -not (Test-Path $nodeModules)) {
        Write-Host "  -> Đang chạy 'npm install' cho CloakBrowser..." -ForegroundColor Cyan
        if (-not $DryRun) {
            Push-Location $TargetDir
            try {
                npm install --omit=dev --silent
                npx playwright install chromium
            } catch {
                Write-Warning "npm install cho CloakBrowser gặp lỗi: $($_.Exception.Message)"
            } finally {
                Pop-Location
            }
        }
    }
    return $mainScript
}

# 8. Thu thập thông tin cấu hình
Write-Host "==> Thu thập các giá trị cấu hình..." -ForegroundColor Cyan
$aiBaseUrl = Get-EnvOrPrompt -EnvName "AI_BASE_URL" -Prompt "AI Base URL" -Default "http://localhost:20128/v1"
$aiKey     = Get-EnvOrPrompt -EnvName "AI_API_KEY" -Prompt "AI API Key"

$jiraUrl   = ""
$jiraToken = ""
$confUrl   = ""
$confToken = ""
if ($installAtlassian) {
    $jiraUrl   = Get-EnvOrPrompt -EnvName "JIRA_URL" -Prompt "Jira URL" -Default "https://jira.cybertech.vn"
    $jiraToken = Get-EnvOrPrompt -EnvName "JIRA_PERSONAL_TOKEN" -Prompt "Jira Personal Token" -Default "YOUR_JIRA_PERSONAL_TOKEN"
    $confUrl   = Get-EnvOrPrompt -EnvName "CONFLUENCE_URL" -Prompt "Confluence URL" -Default "https://conf.cybertech.vn"
    $confToken = Get-EnvOrPrompt -EnvName "CONFLUENCE_PERSONAL_TOKEN" -Prompt "Confluence Personal Token" -Default "YOUR_CONFLUENCE_PERSONAL_TOKEN"
}

$ctxKey = ""
if ($installContext7) {
    $ctxKey = Get-EnvOrPrompt -EnvName "CONTEXT7_API_KEY" -Prompt "Context7 API Key" -AllowEmpty
}

$gitlabHost = "10.30.1.17"
$gitlabToken = ""
if ($installGlab) {
    $gitlabHost  = Get-EnvOrPrompt -EnvName "GITLAB_HOST" -Prompt "GitLab Host" -Default "10.30.1.17"
    $gitlabToken = Get-EnvOrPrompt -EnvName "GITLAB_TOKEN" -Prompt "GitLab Personal Token" -AllowEmpty

    if (-not [string]::IsNullOrWhiteSpace($gitlabToken) -and -not $DryRun) {
        try {
            if (Get-Command "glab" -ErrorAction SilentlyContinue) {
                glab auth login --hostname $gitlabHost --token $gitlabToken 2>$null
            }
        } catch {
            Write-Warning "Không thể đăng nhập tự động vào GitLab: $($_.Exception.Message)"
        }
    }
}

$gitnexusConfig = ""
if ($installGitnexus) {
    $gitnexusBin = Get-Command "gitnexus" -ErrorAction SilentlyContinue
    if ($gitnexusBin -and $gitnexusBin.Source) {
        $gnPath = $gitnexusBin.Source.Replace('\', '\\')
        $gitnexusConfig = @"
    command: cmd
    args:
      - /c
      - "$gnPath"
      - mcp
"@
    } else {
        throw "Lỗi: Không tìm thấy gitnexus bằng Get-Command."
    }
}

$context7Config = ""
if ($installContext7) {
    $context7Detected = $false
    try {
        $npmGlobalRoot = npm root -g 2>$null
        if ($npmGlobalRoot) {
            $ctxJsPath = Join-Path $npmGlobalRoot "@upstash\context7-mcp\dist\index.js"
            if (Test-Path $ctxJsPath) {
                $context7Detected = $true
                $c7Path = $ctxJsPath.Replace('\', '\\')
                $context7Config = @"
    command: node
    args:
      - "$c7Path"
"@
            }
        }
    } catch {}

    if (-not $context7Detected) {
        throw "Lỗi: Không tìm thấy context7 index.js."
    }

    if (-not [string]::IsNullOrWhiteSpace($ctxKey)) {
        $context7Config += @"
`n    env:
      CONTEXT7_API_KEY: $ctxKey
"@
    }
}

$escapedCloakScript = ""
if ($installCloakbrowser) {
    $cbSourceDir = Join-Path $PSScriptRoot "mcp-servers\cloakbrowser"
    $cbTargetDir = Get-CloakBrowserInstallDir
    $cloakScriptPath = Setup-CloakBrowser -TargetDir $cbTargetDir -SourceDir $cbSourceDir -DryRun:$DryRun -SkipInstall:$SkipInstall
    $escapedCloakScript = ($cloakScriptPath).Replace('\', '\\')
}

# 9. Khởi tạo và xây dựng cordis.patch.yml an toàn
$baseCordisYaml = @"
# Your patch layer for this dsh profile, applied after every bundle layer:
# a top-level YAML array of loader patch entries (id-targeted config
# overrides, disables, and insert lists; ``!!js`` expressions allowed).
- id: permission
  name: "@deepseek-ai/dsh-permission-presets"
  config:
    presets:
      read-only:
        sandbox: read-only
        approval: ask
      workspace-write:
        sandbox: workspace-write
        approval: ask
      danger-full-access:
        sandbox: danger-full-access
        approval: never
    defaultPreset: danger-full-access
- id: ui-chat
  name: "@deepseek-ai/dsh-client-ui-chat"
  config:
    transcriptView: compact
- id: ui-theme
  name: "@deepseek-ai/dsh-client-ui-theme"
  config:
    fontSize: 12
- id: llm-pi-ai
  name: "@deepseek-ai/dsh-llm-pi-ai"
  config:
    providers:
      anthropic:
        baseURL: $aiBaseUrl
        models:
          - id: claude-fable-5
            name: Claude Fable 5
            contextWindow: 1000000
            maxTokens: 128000
            input:
              - text
              - image
          - id: claude-haiku-4-5-20251001
            name: Claude Haiku 4.5
            contextWindow: 200000
            maxTokens: 64000
            input:
              - text
              - image
          - id: claude-opus-5
            name: Claude Opus 5
            contextWindow: 1000000
            maxTokens: 128000
            input:
              - text
              - image
          - id: claude-sonnet-5
            name: Claude Sonnet 5
            contextWindow: 1000000
            maxTokens: 128000
            input:
              - text
              - image
        apiKeyEnv: ANTHROPIC_API_KEY
- id: agent-preset-registry
  name: "@deepseek-ai/dsh-agent-preset-registry"
  config:
    default: standard
    selectedDefault: ptc
- id: agent-default-model
  name: "@deepseek-ai/dsh-agent-default-model"
  config:
    provider: anthropic
    model: claude-sonnet-5
    reasoningEffort: medium
- id: subagent-model-selection-settings
  name: "@deepseek-ai/dsh-tool-subagent/model-selection-settings"
  config:
    enabled: true
    allowedModels:
      - provider: anthropic
        model: claude-fable-5
      - provider: anthropic
        model: claude-haiku-4-5-20251001
      - provider: anthropic
        model: claude-opus-5
      - provider: anthropic
        model: claude-sonnet-5
- id: subagent
  name: "@deepseek-ai/dsh-subagent"
  config:
    maxDepth: 6
    maxActiveSubagents: 32
"@

if ($installMemorix) {
    $baseCordisYaml += @"
`n- id: mcp-memorix
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: memorix
    transport: stdio
    command: memorix
    args:
      - serve
      - --mode
      - lite
"@
}

if ($installGitnexus) {
    $baseCordisYaml += @"
`n- id: mcp-gitnexus
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: gitnexus
    transport: stdio
$($gitnexusConfig.TrimEnd())
"@
}

if ($installAtlassian) {
    $baseCordisYaml += @"
`n- id: mcp-company-atlassian
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: company-atlassian
    transport: stdio
    command: uvx
    args:
      - --from
      - mcp-atlassian==0.23.1
      - mcp-atlassian
    env:
      JIRA_URL: $jiraUrl
      JIRA_PERSONAL_TOKEN: $jiraToken
      CONFLUENCE_URL: $confUrl
      CONFLUENCE_PERSONAL_TOKEN: $confToken
      TOOLSETS: default
"@
}

if ($installContext7) {
    $baseCordisYaml += @"
`n- id: mcp-context7
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: context7
    transport: stdio
$($context7Config.TrimEnd())
"@
}

if ($installGlab) {
    $baseCordisYaml += @"
`n- id: mcp-glab
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: glab
    transport: stdio
    command: glab
    args:
      - mcp
      - serve
"@
}

if ($installCloakbrowser) {
    $baseCordisYaml += @"
`n- id: mcp-cloakbrowser
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: cloakbrowser
    transport: stdio
    command: node
    args:
      - "$escapedCloakScript"
"@
}

$baseCordisYaml += "`n"

$credentialsYaml = @"
version: 1
refs:
  ANTHROPIC_API_KEY: $aiKey
apiKey: $aiKey
"@

# 10. Hàm hợp nhất cấu hình YAML (Merge cordis.patch.yml)
function Merge-CordisPatchYaml {
    param(
        [Parameter(Mandatory = $true)][string]$ExistingContent,
        [Parameter(Mandatory = $true)][string]$NewContent
    )
    $pattern = '(?m)^-\s+id:\s+([^\r\n]+)'
    $splitExisting = [System.Text.RegularExpressions.Regex]::Split($ExistingContent, $pattern)
    $splitNew      = [System.Text.RegularExpressions.Regex]::Split($NewContent, $pattern)

    $orderedIds = [System.Collections.Generic.List[string]]::new()
    $blocks = @{}

    for ($i = 1; $i -lt $splitExisting.Count; $i += 2) {
        $id = $splitExisting[$i].Trim()
        $body = $splitExisting[$i + 1]
        $orderedIds.Add($id)
        $blocks[$id] = "- id: $id$body"
    }

    for ($i = 1; $i -lt $splitNew.Count; $i += 2) {
        $id = $splitNew[$i].Trim()
        $body = $splitNew[$i + 1]
        if (-not $orderedIds.Contains($id)) {
            $orderedIds.Add($id)
        }
        $blocks[$id] = "- id: $id$body"
    }

    $header = $splitNew[0]
    $merged = $header.TrimEnd() + "`n"
    foreach ($id in $orderedIds) {
        $merged += $blocks[$id].TrimEnd() + "`n"
    }
    return $merged
}

function Write-ConfigFileWithConflictResolution {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$IsMcpYaml,
        [switch]$DryRun,
        [switch]$Force
    )
    $parentDir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $parentDir) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if (-not (Test-Path $TargetPath)) {
        Write-Host "  -> Tạo mới: $TargetPath" -ForegroundColor Green
        if (-not $DryRun) {
            [System.IO.File]::WriteAllText($TargetPath, $Content, [System.Text.UTF8Encoding]::new($false))
        }
        return
    }

    if ($Force) {
        Write-Host "  -> Ghi đè (--Force): $TargetPath" -ForegroundColor Green
        if (-not $DryRun) {
            [System.IO.File]::WriteAllText($TargetPath, $Content, [System.Text.UTF8Encoding]::new($false))
        }
        return
    }

    if ($IsMcpYaml) {
        $existing = Get-Content $TargetPath -Raw
        $merged = Merge-CordisPatchYaml -ExistingContent $existing -NewContent $Content
        Write-Host "  -> Hợp nhất cấu hình vào: $TargetPath" -ForegroundColor Green
        if (-not $DryRun) {
            [System.IO.File]::WriteAllText($TargetPath, $merged, [System.Text.UTF8Encoding]::new($false))
        }
    } else {
        Write-Host "  -> Bỏ qua $TargetPath (đã tồn tại)" -ForegroundColor Yellow
    }
}

# 11. Ghi file cấu hình
$cordisPatchPath = Join-Path $DshProfileDir "cordis.patch.yml"
Write-ConfigFileWithConflictResolution -TargetPath $cordisPatchPath -Content $baseCordisYaml -IsMcpYaml -DryRun:$DryRun -Force:$isForce

Write-ConfigFileWithConflictResolution -TargetPath $CredentialsPath -Content $credentialsYaml -DryRun:$DryRun -Force:$isForce

# 12. Sao chép AGENTS.md và skills/
$sourceAgents = Join-Path $PSScriptRoot "AGENTS.md"
$targetAgents = Join-Path $DshHome "AGENTS.md"
if (Test-Path $sourceAgents) {
    Write-Host "  -> Cập nhật AGENTS.md tại $targetAgents..." -ForegroundColor Green
    if (-not $DryRun) {
        $agentsDir = Split-Path $targetAgents -Parent
        if (-not (Test-Path $agentsDir)) { New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null }
        Copy-Item -Path $sourceAgents -Destination $targetAgents -Force
    }
}

$sourceSkillsDir = Join-Path $PSScriptRoot "skills"
$targetSkillsDir = Join-Path $DshHome "skills"
if (Test-Path $sourceSkillsDir) {
    Write-Host "  -> Cập nhật skills/ tại $targetSkillsDir..." -ForegroundColor Green
    if (-not $DryRun) {
        if (-not (Test-Path $targetSkillsDir)) { New-Item -ItemType Directory -Path $targetSkillsDir -Force | Out-Null }
        Copy-Item -Path "$sourceSkillsDir\*" -Destination $targetSkillsDir -Recurse -Force
    }
}

Write-Host ""
Write-Host "Hoàn tất bootstrap DSH Desktop!" -ForegroundColor Cyan
