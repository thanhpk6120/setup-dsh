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

# 1. Xử lý tùy chọn Memorix
if (-not $PSBoundParameters.ContainsKey('EnableMemorix') -and -not $PSBoundParameters.ContainsKey('DisableMemorix')) {
    if (Get-Command "memorix" -ErrorAction SilentlyContinue) {
        Write-Host "==> Đã phát hiện Memorix CLI trong hệ thống. Tự động kích hoạt và cập nhật lên phiên bản mới nhất..." -ForegroundColor Green
        $EnableMemorix = $true
    } else {
        $memorixChoice = Read-Host "Bạn có muốn cài đặt Memorix (MCP & Session Memory) không? [y/N]"
        $EnableMemorix = if (-not [string]::IsNullOrWhiteSpace($memorixChoice) -and $memorixChoice.Trim().ToLower() -eq 'y') { $true } else { $false }
    }
} elseif ($DisableMemorix.IsPresent) {
    $EnableMemorix = $false
} else {
    $EnableMemorix = $EnableMemorix.IsPresent
}

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
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        } elseif ([System.IO.File]::Exists($Path)) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        }
    } catch {
        Write-Warning "Không thể di chuyển '$Path' vào Thùng rác: $($_.Exception.Message)"
    }
}

function Setup-TrashGuard {
    function global:Remove-Item {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
            [string[]]$Path,
            [switch]$Recurse,
            [switch]$Force
        )
        process {
            foreach ($target in $Path) {
                if (Test-Path -LiteralPath $target) {
                    Safe-Trash -Path (Resolve-Path -LiteralPath $target).Path
                }
            }
        }
    }
}
Setup-TrashGuard

# 3. Kiểm tra các công cụ runtime cơ bản
Write-Host "==> Kiểm tra các công cụ runtime..." -ForegroundColor Cyan
foreach ($tool in @("node", "npm", "git")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Thiếu công cụ '$tool' trong PATH. Vui lòng cài đặt trước khi tiếp tục."
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
    if ($EnableMemorix) { $toolsList = "memorix, gitnexus, context7" }
    throw "Yêu cầu Node.js >= 22.18.0 (do $toolsList yêu cầu Node mới). Phiên bản hiện tại: '$nodeVerRaw'. Vui lòng nâng cấp Node.js."
}

# uv / uvx (dùng cho company-atlassian MCP)
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
            try {
                uv tool install mcp-atlassian==0.23.1 --force
            } catch {
                Write-Warning "Cài đặt mcp-atlassian gặp lỗi: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "'uv' không khả dụng. Vui lòng cài đặt mcp-atlassian thủ công: uv tool install mcp-atlassian==0.23.1"
        }
    }
}

# 4. Quản lý cài đặt gói Memorix theo lựa chọn
if ($EnableMemorix) {
    if (-not $SkipInstall) {
        Write-Host "==> Đang cài đặt/cập nhật memorix lên phiên bản mới nhất qua npm..." -ForegroundColor Cyan
        if (-not $DryRun) {
            npm install -g memorix --silent
        }
    }

    if (-not $SkipInstall) {
        Write-Host "==> Đang đăng ký plugin và hooks cho Memorix (agent dsh)..." -ForegroundColor Cyan
        if (-not $DryRun) {
            try {
                memorix setup --agent dsh --global
            } catch {
                Write-Warning "Đăng ký hook memorix gặp lỗi (hãy chạy thủ công): $($_.Exception.Message)"
            }
        }
    }
} else {
    Write-Host "==> Bỏ qua cài đặt Memorix (MCP & Session Memory được tắt theo yêu cầu)." -ForegroundColor Yellow
}

# 5. Cài đặt các MCP tools khác
if (-not $SkipInstall) {
    Write-Host "==> Cài đặt gitnexus globally..." -ForegroundColor Cyan
    if (-not $DryRun) {
        try {
            npm install -g gitnexus --silent
        } catch {
            Write-Warning "Cài đặt gitnexus gặp lỗi: $($_.Exception.Message)"
        }
    }
}

if (-not $SkipInstall) {
    Write-Host "==> Cài đặt context7 globally..." -ForegroundColor Cyan
    if (-not $DryRun) {
        try {
            npm install -g @upstash/context7-mcp --silent
        } catch {
            Write-Warning "Cài đặt context7 gặp lỗi: $($_.Exception.Message)"
        }
    }
}

if (-not $SkipInstall -and -not (Get-Command "glab" -ErrorAction SilentlyContinue)) {
    Write-Host "==> Cài đặt glab (GitLab CLI)..." -ForegroundColor Cyan
    if (-not $DryRun) {
        if (Get-Command "winget" -ErrorAction SilentlyContinue) {
            winget install --id GitLab.glab -e --accept-source-agreements --accept-package-agreements
        } elseif (Get-Command "scoop" -ErrorAction SilentlyContinue) {
            scoop install glab
        } else {
            Write-Warning "Không tìm thấy winget hoặc scoop để cài glab. Vui lòng cài glab thủ công."
        }
    }
}

# 6. Đọc .env nếu có
function Load-Env {
    param([string]$EnvPath = (Join-Path $PSScriptRoot ".env"))
    if (Test-Path $EnvPath) {
        Write-Host "  -> Đang nạp cấu hình từ $EnvPath..." -ForegroundColor Cyan
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
                        $currentVal = [Environment]::GetEnvironmentVariable($key, "Process")
                        if ([string]::IsNullOrWhiteSpace($currentVal)) {
                            [Environment]::SetEnvironmentVariable($key, $val, "Process")
                        }
                    }
                }
            }
        }
    }
}
Load-Env

# 7. Hàm hỏi cấu hình tương tác
function Get-EnvOrPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$EnvName,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string]$Default,
        [switch]$AllowEmpty
    )
    $val = [Environment]::GetEnvironmentVariable($EnvName, "Process")
    if (-not [string]::IsNullOrWhiteSpace($val)) { return $val }

    $hasDefault = $PSBoundParameters.ContainsKey('Default')
    while ($true) {
        $promptStr = $Prompt
        if ($hasDefault) { $promptStr = "$Prompt (Mặc định: $Default)" }
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
        Write-Host "Lỗi: '$EnvName' là bắt buộc, không được để trống! Vui lòng nhập lại." -ForegroundColor Yellow
    }
}

# 8. Cấu hình CloakBrowser
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

    Write-Host "`n==> Quét danh sách ổ đĩa (Local Drives) để cài đặt CloakBrowser MCP:" -ForegroundColor Cyan
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

Write-Host "==> Thu thập các giá trị cấu hình..." -ForegroundColor Cyan
$aiBaseUrl = Get-EnvOrPrompt -EnvName "AI_BASE_URL" -Prompt "AI Base URL" -Default "http://localhost:20128/v1"
$aiKey     = Get-EnvOrPrompt -EnvName "AI_API_KEY" -Prompt "AI API Key"
$jiraUrl   = Get-EnvOrPrompt -EnvName "JIRA_URL" -Prompt "Jira URL" -Default "https://jira.cybertech.vn"
$jiraToken = Get-EnvOrPrompt -EnvName "JIRA_PERSONAL_TOKEN" -Prompt "Jira Personal Token" -Default "YOUR_JIRA_PERSONAL_TOKEN"
$confUrl   = Get-EnvOrPrompt -EnvName "CONFLUENCE_URL" -Prompt "Confluence URL" -Default "https://conf.cybertech.vn"
$confToken = Get-EnvOrPrompt -EnvName "CONFLUENCE_PERSONAL_TOKEN" -Prompt "Confluence Personal Token" -Default "YOUR_CONFLUENCE_PERSONAL_TOKEN"
$ctxKey    = Get-EnvOrPrompt -EnvName "CONTEXT7_API_KEY" -Prompt "Context7 API Key" -AllowEmpty
$gitlabHost = Get-EnvOrPrompt -EnvName "GITLAB_HOST" -Prompt "GitLab Host" -Default "10.30.1.17"
$gitlabToken = Get-EnvOrPrompt -EnvName "GITLAB_TOKEN" -Prompt "GitLab Token" -AllowEmpty

if (-not [string]::IsNullOrWhiteSpace($gitlabToken) -and -not $DryRun) {
    try {
        if (Get-Command "glab" -ErrorAction SilentlyContinue) {
            glab auth login --hostname $gitlabHost --token $gitlabToken 2>$null
        }
    } catch {
        Write-Warning "Không thể tự động cấu hình xác thực glab: $($_.Exception.Message)"
    }
}

# 9. Tách mẫu cấu hình templates/ với fallback chuỗi an toàn
function Get-TemplateContent {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateName,
        [string]$FallbackContent = ""
    )
    $templatePath = Join-Path $PSScriptRoot (Join-Path "templates" $TemplateName)
    if (Test-Path -LiteralPath $templatePath) {
        return (Get-Content -Path $templatePath -Raw -Encoding UTF8)
    }
    return $FallbackContent
}

$cordisFallback = @'
# Your patch layer for this dsh profile, applied after every bundle layer:
# a top-level YAML array of loader patch entries (id-targeted config
# overrides, disables, and insert lists; `!!js` expressions allowed).
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
        baseURL: __AI_BASE_URL__
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
__MEMORIX_CONFIG__
- id: mcp-gitnexus
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: gitnexus
    transport: stdio
__GITNEXUS_CONFIG__
- id: mcp-company-atlassian
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
      JIRA_URL: __JIRA_URL__
      JIRA_PERSONAL_TOKEN: __JIRA_PERSONAL_TOKEN__
      CONFLUENCE_URL: __CONFLUENCE_URL__
      CONFLUENCE_PERSONAL_TOKEN: __CONFLUENCE_PERSONAL_TOKEN__
      TOOLSETS: default
- id: mcp-context7
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: context7
    transport: stdio
__CONTEXT7_CONFIG__
- id: mcp-glab
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: glab
    transport: stdio
    command: glab
    args:
      - mcp
      - serve
- id: mcp-cloakbrowser
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: cloakbrowser
    transport: stdio
    command: node
    args:
      - "__CLOAKBROWSER_SCRIPT__"
'@

$credentialsFallback = @"
version: 1
refs:
  ANTHROPIC_API_KEY: __AI_API_KEY__
apiKey: __AI_API_KEY__
"@

$cordisTemplate = Get-TemplateContent -TemplateName "cordis.patch.yml" -FallbackContent $cordisFallback
$credentialsTemplate = Get-TemplateContent -TemplateName ".credentials.yaml" -FallbackContent $credentialsFallback

# Dynamic path resolution: gitnexus
$gitnexusConfig = ""
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
    throw "gitnexus không tìm thấy bằng Get-Command"
}

# Dynamic path resolution: context7
$context7Config = ""
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
    throw "context7 index.js không tìm thấy"
}

if (-not [string]::IsNullOrWhiteSpace($ctxKey)) {
    $context7Config += @"
`n    env:
      CONTEXT7_API_KEY: $ctxKey
"@
}

$cbSourceDir = Join-Path $PSScriptRoot "mcp-servers\cloakbrowser"
$cbTargetDir = Get-CloakBrowserInstallDir
$cloakScriptPath = Setup-CloakBrowser -TargetDir $cbTargetDir -SourceDir $cbSourceDir -DryRun:$DryRun -SkipInstall:$SkipInstall
$escapedCloakScript = ($cloakScriptPath).Replace('\', '\\')

# Render nội dung cordis.patch.yml
$cordisYaml = $cordisTemplate
$cordisYaml = $cordisYaml.Replace("__AI_BASE_URL__", $aiBaseUrl)
$cordisYaml = $cordisYaml.Replace("__JIRA_URL__", $jiraUrl)
$cordisYaml = $cordisYaml.Replace("__JIRA_PERSONAL_TOKEN__", $jiraToken)
$cordisYaml = $cordisYaml.Replace("__CONFLUENCE_URL__", $confUrl)
$cordisYaml = $cordisYaml.Replace("__CONFLUENCE_PERSONAL_TOKEN__", $confToken)
$cordisYaml = $cordisYaml.Replace("__CLOAKBROWSER_SCRIPT__", $escapedCloakScript)
$cordisYaml = $cordisYaml.Replace("__GITNEXUS_CONFIG__", $gitnexusConfig)
$cordisYaml = $cordisYaml.Replace("__CONTEXT7_CONFIG__", $context7Config)

if ($EnableMemorix) {
    $memorixMcpYaml = @"
- id: mcp-memorix
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
    $cordisYaml = $cordisYaml.Replace("__MEMORIX_CONFIG__`r`n", "$memorixMcpYaml`r`n").Replace("__MEMORIX_CONFIG__`n", "$memorixMcpYaml`n").Replace("__MEMORIX_CONFIG__", $memorixMcpYaml)
} else {
    $cordisYaml = $cordisYaml.Replace("__MEMORIX_CONFIG__`r`n", "").Replace("__MEMORIX_CONFIG__`n", "").Replace("__MEMORIX_CONFIG__", "")
}

$credentialsYaml = $credentialsTemplate.Replace("__AI_API_KEY__", $aiKey)

# 10. Hàm hợp nhất cấu hình YAML (Merge cordis.patch.yml)
function Merge-CordisPatchYaml {
    param(
        [Parameter(Mandatory = $true)][string]$ExistingContent,
        [Parameter(Mandatory = $true)][string]$NewContent
    )
    $oldServers = @{}
    $lines = $ExistingContent -split "`r?`n"
    $currentId = $null
    $currentBlock = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if ($line -match '^\s*-\s+id:\s*([^\s]+)') {
            if ($currentId -and $currentBlock.Count -gt 0) {
                $oldServers[$currentId] = ($currentBlock -join "`r`n")
            }
            $currentId = $matches[1].Trim()
            $currentBlock = [System.Collections.Generic.List[string]]::new()
            $currentBlock.Add($line)
        } elseif ($currentId) {
            if ($line -match '^[a-zA-Z]') {
                $oldServers[$currentId] = ($currentBlock -join "`r`n")
                $currentId = $null
                $currentBlock = [System.Collections.Generic.List[string]]::new()
            } else {
                $currentBlock.Add($line)
            }
        }
    }
    if ($currentId -and $currentBlock.Count -gt 0) {
        $oldServers[$currentId] = ($currentBlock -join "`r`n")
    }

    $newIds = @()
    foreach ($line in ($NewContent -split "`r?`n")) {
        if ($line -match '^\s*-\s+id:\s*([^\s]+)') {
            $newIds += $matches[1].Trim()
        }
    }

    $customBlocks = @()
    foreach ($oldKey in $oldServers.Keys) {
        if ($oldKey -notin $newIds) {
            $customBlocks += $oldServers[$oldKey]
        }
    }

    if ($customBlocks.Count -gt 0) {
        return ($NewContent.TrimEnd() + "`r`n" + ($customBlocks -join "`r`n`r`n") + "`r`n")
    }
    return $NewContent
}
function Merge-CredentialsYaml {
    param(
        [Parameter(Mandatory = $true)][string]$ExistingContent,
        [Parameter(Mandatory = $true)][string]$NewContent
    )
    if ($ExistingContent -match '(?ms)(records:\s*\r?\n.*?)(?=refs:|$|\z)') {
        $recordsBlock = $matches[1].TrimEnd()
        if (-not ($NewContent -match 'records:')) {
            if ($NewContent -match 'version:\s*\d+') {
                return ($NewContent -replace '(version:\s*\d+)', "`$1`r`n$recordsBlock")
            } else {
                return "$recordsBlock`r`n$NewContent"
            }
        }
    }
    return $NewContent
}


# 11. Ghi file cấu hình với cơ chế giải quyết xung đột [O/M/s]
function Write-ConfigFileWithConflictResolution {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$IsMcpYaml,
        [switch]$DryRun,
        [switch]$Force
    )
    $fileName = Split-Path $TargetPath -Leaf
    $dir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $dir) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $bakPath = "$TargetPath.bak"

    if (Test-Path $TargetPath) {
        if ($IsMcpYaml) {
            if ($Force) {
                Write-Host "  -> File '$fileName' đã tồn tại. [-Force] Tự động sao lưu và ghi đè." -ForegroundColor Yellow
                if (-not $DryRun) {
                    Copy-Item -Path $TargetPath -Destination $bakPath -Force
                    [System.IO.File]::WriteAllText($TargetPath, $Content, [System.Text.UTF8Encoding]::new($false))
                }
            } else {
                $choice = Read-Host "[?] File '$fileName' đã tồn tại. Bạn có muốn [O]verwrite (ghi đè), [M]erge (hợp nhất cấu hình cũ và mới), hay [S]kip (bỏ qua)? [O/M/s]"
                $choice = if ($choice) { $choice.Trim() } else { "O" }
                if ($choice -match '^[mM]$') {
                    Write-Host "  -> Hợp nhất cấu hình cũ và mới (đã sao lưu sang $bakPath)..." -ForegroundColor Green
                    if (-not $DryRun) {
                        Copy-Item -Path $TargetPath -Destination $bakPath -Force
                        $existingContent = Get-Content -Path $TargetPath -Raw -Encoding UTF8
                        $mergedContent = Merge-CordisPatchYaml -ExistingContent $existingContent -NewContent $Content
                        [System.IO.File]::WriteAllText($TargetPath, $mergedContent, [System.Text.UTF8Encoding]::new($false))
                    }
                } elseif ($choice -match '^[sS]$') {
                    Write-Host "  -> Bỏ qua '$fileName' (giữ nguyên file hiện tại)." -ForegroundColor Yellow
                } else {
                    Write-Host "  -> Ghi đè file '$fileName' (đã sao lưu sang $bakPath)..." -ForegroundColor Green
                    if (-not $DryRun) {
                        Copy-Item -Path $TargetPath -Destination $bakPath -Force
                        [System.IO.File]::WriteAllText($TargetPath, $Content, [System.Text.UTF8Encoding]::new($false))
                    }
                }
            }
        } else {
            if ($Force) {
                Write-Host "  -> File '$fileName' đã tồn tại. [-Force] Tự động sao lưu và ghi đè." -ForegroundColor Yellow
                if (-not $DryRun) {
                    Copy-Item -Path $TargetPath -Destination $bakPath -Force
                    $existingContent = Get-Content -Path $TargetPath -Raw -Encoding UTF8
                    $mergedCreds = Merge-CredentialsYaml -ExistingContent $existingContent -NewContent $Content
                    [System.IO.File]::WriteAllText($TargetPath, $mergedCreds, [System.Text.UTF8Encoding]::new($false))
                }
            } else {
                $choice = Read-Host "[?] File '$fileName' đã tồn tại. Bạn có muốn [O]verwrite (ghi đè) hay [S]kip (bỏ qua)? [O/s]"
                $choice = if ($choice) { $choice.Trim() } else { "O" }
                if ($choice -match '^[sS]$') {
                    Write-Host "  -> Bỏ qua '$fileName' (giữ nguyên file hiện tại)." -ForegroundColor Yellow
                } else {
                    Write-Host "  -> Ghi đè file '$fileName' (đã sao lưu sang $bakPath)..." -ForegroundColor Green
                    if (-not $DryRun) {
                        Copy-Item -Path $TargetPath -Destination $bakPath -Force
                        $existingContent = Get-Content -Path $TargetPath -Raw -Encoding UTF8
                        $mergedCreds = Merge-CredentialsYaml -ExistingContent $existingContent -NewContent $Content
                        [System.IO.File]::WriteAllText($TargetPath, $mergedCreds, [System.Text.UTF8Encoding]::new($false))
                    }
                }
            }
        }
    } else {
        Write-Host "  -> Đang tạo mới file cấu hình $TargetPath..." -ForegroundColor Green
        if (-not $DryRun) {
            [System.IO.File]::WriteAllText($TargetPath, $Content, [System.Text.UTF8Encoding]::new($false))
        }
    }
}

$cordisPatchPath = Join-Path $DshProfileDir "cordis.patch.yml"
Write-ConfigFileWithConflictResolution -TargetPath $cordisPatchPath -Content $cordisYaml -IsMcpYaml -DryRun:$DryRun -Force:$isForce

Write-ConfigFileWithConflictResolution -TargetPath $CredentialsPath -Content $credentialsYaml -DryRun:$DryRun -Force:$isForce

# 12. Sao chép và quản lý tài liệu Agent (AGENTS.md)
$sourceAgents = Join-Path $PSScriptRoot "AGENTS.md"
$targetAgents = Join-Path $DshHome "AGENTS.md"
if (Test-Path $sourceAgents) {
    Write-Host "  -> Cấu hình tài liệu Agent tại $targetAgents..." -ForegroundColor Cyan
    $agentDocContent = Get-Content -Path $sourceAgents -Raw -Encoding UTF8

    if ($EnableMemorix) {
        $memorixSectionTemplate = Get-TemplateContent -TemplateName "memorix-agents-section.md" -FallbackContent ""
        if (-not [string]::IsNullOrWhiteSpace($memorixSectionTemplate)) {
            $agentDocContent = $agentDocContent.TrimEnd() + "`r`n`r`n" + $memorixSectionTemplate.Trim() + "`r`n"
        }
    }

    if (-not $DryRun) {
        if (-not (Test-Path $DshHome)) {
            New-Item -ItemType Directory -Path $DshHome -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($targetAgents, $agentDocContent, [System.Text.UTF8Encoding]::new($false))
    }
}

# 13. Quản lý các Skills và dọn dẹp các Skill Memorix nếu tắt
$sourceSkills = Join-Path $PSScriptRoot "skills"
$targetSkills = Join-Path $DshHome "skills"
$memorixSkills = @(
    "memorix-git-memory",
    "memorix-memory",
    "memorix-mini-skills",
    "memorix-orchestrate",
    "memorix-reasoning",
    "memorix-sessions",
    "memorix-troubleshooting"
)

if (Test-Path $sourceSkills) {
    Write-Host "  -> Đồng bộ kỹ năng (skills) vào $targetSkills..." -ForegroundColor Cyan
    if (-not (Test-Path $targetSkills) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $targetSkills -Force | Out-Null
    }

    $skillDirs = Get-ChildItem -Directory -Path $sourceSkills
    foreach ($sDir in $skillDirs) {
        $sName = $sDir.Name
        if (-not $EnableMemorix -and ($sName -in $memorixSkills)) {
            continue
        }
        $destPath = Join-Path $targetSkills $sName
        if (-not $DryRun) {
            Copy-Item -Path $sDir.FullName -Destination $destPath -Recurse -Force
        }
    }

    # Nếu Memorix tắt: Dọn dẹp các thư mục skill Memorix cũ bằng Safe-Trash
    if (-not $EnableMemorix -and (Test-Path $targetSkills)) {
        foreach ($mSkill in $memorixSkills) {
            $existingSkillPath = Join-Path $targetSkills $mSkill
            if (Test-Path -LiteralPath $existingSkillPath) {
                Write-Host "     Phát hiện skill Memorix '$mSkill' khi Memorix bị tắt. Đang chuyển vào Thùng rác..." -ForegroundColor Yellow
                if (-not $DryRun) {
                    Safe-Trash -Path $existingSkillPath
                }
            }
        }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "        HOÀN TẤT THIẾT LẬP MÔI TRƯỜNG DEEPSEEK HARNESS          " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  - File cấu hình Profile: $cordisPatchPath" -ForegroundColor White
Write-Host "  - File xác thực Credentials: $CredentialsPath" -ForegroundColor White
Write-Host "  - Thư mục Agent Home: $DshHome" -ForegroundColor White
Write-Host "  - Trạng thái Memorix: $(if ($EnableMemorix) { 'ĐÃ BẬT' } else { 'ĐÃ TẮT' })" -ForegroundColor $(if ($EnableMemorix) { 'Green' } else { 'Yellow' })
Write-Host "================================================================" -ForegroundColor Green
