# bootstrap.ps1 - Bootstrap DSH Desktop environment on fresh machine
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipInstall,
    [string]$DshHome = "$env:USERPROFILE\.dsh",
    [string]$DshProfileDir = "$env:APPDATA\dsh-desktop\harness\profiles\web",
    [string]$CredentialsPath = "$env:APPDATA\dsh-desktop\harness\.credentials.yaml"
)

$ErrorActionPreference = "Stop"

# Load-Env: read .env at $PSScriptRoot and set into [Environment] (process scope).
$dotEnvPath = Join-Path $PSScriptRoot ".env"
if (Test-Path $dotEnvPath) {
    Write-Host "==> Loading .env from $dotEnvPath ..." -ForegroundColor Cyan
    foreach ($line in (Get-Content -Path $dotEnvPath)) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) { continue }
        $idx = $trimmed.IndexOf("=")
        if ($idx -lt 1) { continue }
        $k = $trimmed.Substring(0, $idx).Trim()
        $v = $trimmed.Substring($idx + 1).Trim()
        if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        if (-not [string]::IsNullOrWhiteSpace($k) -and -not [string]::IsNullOrWhiteSpace($v)) {
            [Environment]::SetEnvironmentVariable($k, $v)
        }
    }
}

function Get-EnvOrPrompt {
    param(
        [string]$EnvName,
        [string]$PromptMessage,
        [string]$DefaultValue,
        [switch]$AllowEmpty
    )
    $val = [Environment]::GetEnvironmentVariable($EnvName, "Process")
    if (-not [string]::IsNullOrWhiteSpace($val)) { return $val }
    if ($AllowEmpty -and $val -ne $null) { return $val }

    $hasDefault = $PSBoundParameters.ContainsKey('DefaultValue') -or -not [string]::IsNullOrWhiteSpace($DefaultValue)
    while ($true) {
        $promptStr = if ($hasDefault) { "$PromptMessage [$DefaultValue]" } elseif ($AllowEmpty) { "$PromptMessage (leave empty for none)" } else { $PromptMessage }
        try {
            $inputVal = Read-Host $promptStr
        } catch {
            if ($hasDefault) { return $DefaultValue }
            if ($AllowEmpty) { return "" }
            throw ("Error reading prompt for " + $EnvName + ": " + $_.Exception.Message)
        }
        
        if (-not [string]::IsNullOrWhiteSpace($inputVal)) {
            return $inputVal.Trim()
        }
        if ($hasDefault) {
            return $DefaultValue
        }
        if ($AllowEmpty) {
            return ""
        }
        Write-Host "Lỗi: '$EnvName' không được bỏ trống. Vui lòng nhập giá trị." -ForegroundColor Red
    }
}

Write-Host "==> Checking runtime dependencies..." -ForegroundColor Cyan
foreach ($tool in @("node", "npm", "git")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Missing '$tool' in PATH. Please install it first."
    }
}

$nodeVerRaw = (node -v).Trim()
try {
    $nodeVer = [version]($nodeVerRaw.TrimStart('v'))
} catch {
    throw "Không thể xác định version của Node.js: '$nodeVerRaw'."
}
if ($nodeVer -lt [version]"22.18.0") {
    throw "Yêu cầu Node.js >= 22.18.0 (do memorix yêu cầu >= 22.18.0, gitnexus yêu cầu ^22.18.0 || >= 24.11.0, context7 yêu cầu >= 20.18.1). Phiên bản hiện tại: '$nodeVerRaw'. Vui lòng nâng cấp Node.js."
}


# uv / uvx (required by company-atlassian MCP)
if (-not $SkipInstall -and -not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Host "==> 'uv' not found. Installing uv..." -ForegroundColor Cyan
    if (-not $DryRun) {
        $installed = $false
        if (Get-Command "pip" -ErrorAction SilentlyContinue) {
            try {
                pip install uv --quiet
                $installed = $true
            } catch {}
        }
        if (-not $installed -and (Get-Command "winget" -ErrorAction SilentlyContinue)) {
            try {
                winget install --id=astral-sh.uv -e --silent --accept-source-agreements --accept-package-agreements
                $installed = $true
            } catch {}
        }
        if (-not $installed) {
            try {
                irm https://astral.sh/uv/install.ps1 | iex
                $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:Path"
            } catch {
                Write-Warning "Could not install uv automatically. Please install it manually: https://docs.astral.sh/uv/"
            }
        }
    }
}

if (-not $SkipInstall -and -not (Get-Command "memorix" -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing memorix globally..." -ForegroundColor Cyan
    if (-not $DryRun) {
        npm install -g memorix --silent
    }
}

if (-not $SkipInstall) {
    Write-Host "==> Installing gitnexus globally..." -ForegroundColor Cyan
    if (-not $DryRun) {
        try {
            npm install -g gitnexus --silent
        } catch {
            Write-Warning "gitnexus global install failed: $($_.Exception.Message)"
        }
    }
}

if (-not $SkipInstall) {
    Write-Host "==> Installing context7 globally..." -ForegroundColor Cyan
    if (-not $DryRun) {
        try {
            npm install -g @upstash/context7-mcp --silent
        } catch {
            Write-Warning "context7 global install failed: $($_.Exception.Message)"
        }
    }
}

Write-Host "==> Ensuring directory $DshProfileDir exists..." -ForegroundColor Cyan
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $DshProfileDir | Out-Null
}

# cordis.patch.yml template — mirrors live profile; placeholders resolved below.
#   llm-pi-ai (anthropic @ 9router): 4 models claude-fable-5 / claude-haiku-4-5-20251001 / claude-opus-5 / claude-sonnet-5
#   subagent-model-selection-settings: all 4 models allowed
#   MCPs: memorix / gitnexus / company-atlassian (pinned mcp-atlassian==0.23.1) / context7
$cordisTemplate = @'
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
'@

Write-Host "==> Preparing configuration file..." -ForegroundColor Cyan
Write-Host ""
Write-Host "==> Gathering configuration..." -ForegroundColor Cyan
$aiBaseUrl = Get-EnvOrPrompt -EnvName "AI_BASE_URL" -PromptMessage "AI Base URL" -DefaultValue "https://9router.thanhpk.io.vn/v1"
$aiApiKey = Get-EnvOrPrompt -EnvName "AI_API_KEY" -PromptMessage "AI API Key" -DefaultValue ""
$jiraUrl = Get-EnvOrPrompt -EnvName "JIRA_URL" -PromptMessage "Jira URL" -DefaultValue "https://jira.cybertech.vn"
$jiraToken = Get-EnvOrPrompt -EnvName "JIRA_PERSONAL_TOKEN" -PromptMessage "Jira Personal Token" -DefaultValue "YOUR_JIRA_PERSONAL_TOKEN"
$confUrl = Get-EnvOrPrompt -EnvName "CONFLUENCE_URL" -PromptMessage "Confluence URL" -DefaultValue "https://conf.cybertech.vn"
$confToken = Get-EnvOrPrompt -EnvName "CONFLUENCE_PERSONAL_TOKEN" -PromptMessage "Confluence Personal Token" -DefaultValue "YOUR_CONFLUENCE_PERSONAL_TOKEN"
$context7ApiKey = Get-EnvOrPrompt -EnvName "CONTEXT7_API_KEY" -PromptMessage "Context7 API Key" -AllowEmpty

# Dynamic path resolution: gitnexus
$gitnexusConfig = ""
$gitnexusBin = Get-Command "gitnexus" -ErrorAction SilentlyContinue
if ($gitnexusBin -and $gitnexusBin.Source) {
    $gnPath = $gitnexusBin.Source -replace '\\', '\\'
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
            $c7Path = $ctxJsPath -replace '\\', '\\'
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

if (-not [string]::IsNullOrWhiteSpace($context7ApiKey)) {
    $context7Config += @"
`n    env:
      CONTEXT7_API_KEY: $context7ApiKey
"@
}

$cordisYaml = $cordisTemplate
$cordisYaml = $cordisYaml.Replace("__AI_BASE_URL__", $aiBaseUrl)
$cordisYaml = $cordisYaml.Replace("__JIRA_URL__", $jiraUrl)
$cordisYaml = $cordisYaml.Replace("__JIRA_PERSONAL_TOKEN__", $jiraToken)
$cordisYaml = $cordisYaml.Replace("__CONFLUENCE_URL__", $confUrl)
$cordisYaml = $cordisYaml.Replace("__CONFLUENCE_PERSONAL_TOKEN__", $confToken)
$cordisYaml = $cordisYaml.Replace("__GITNEXUS_CONFIG__", $gitnexusConfig.TrimEnd())
$cordisYaml = $cordisYaml.Replace("__CONTEXT7_CONFIG__", $context7Config.TrimEnd())

$targetPath = Join-Path $DshProfileDir "cordis.patch.yml"
if (Test-Path $targetPath) {
    Write-Host "  -> Skipping $targetPath (already exists)" -ForegroundColor Yellow
} else {
    Write-Host "  -> Creating $targetPath" -ForegroundColor Green
    if (-not $DryRun) {
        Set-Content -Path $targetPath -Value $cordisYaml -Encoding UTF8
    }
}

Write-Host "==> Ensuring DshHome $DshHome exists..." -ForegroundColor Cyan
if (-not $DryRun -and -not (Test-Path $DshHome)) {
    New-Item -ItemType Directory -Force -Path $DshHome | Out-Null
}

$sourceAgents = Join-Path $PSScriptRoot "AGENTS.md"
$targetAgents = Join-Path $DshHome "AGENTS.md"
if (Test-Path $sourceAgents) {
    if (Test-Path $targetAgents) {
        Write-Host "  -> Skipping $targetAgents (already exists)" -ForegroundColor Yellow
    } else {
        Write-Host "  -> Copying $targetAgents" -ForegroundColor Green
        if (-not $DryRun) {
            Copy-Item -Path $sourceAgents -Destination $targetAgents -Force
        }
    }
}

$sourceSkillsDir = Join-Path $PSScriptRoot "skills"
$targetSkillsDir = Join-Path $DshHome "skills"
if (Test-Path $sourceSkillsDir) {
    Write-Host "  -> Copying skills/ to $targetSkillsDir (overwrite)" -ForegroundColor Green
    if (-not $DryRun) {
        Copy-Item -Path $sourceSkillsDir -Destination $targetSkillsDir -Recurse -Force
    }
}

Write-Host "==> Syncing AI API key into credentials file..." -ForegroundColor Cyan
if (-not $DryRun -and -not [string]::IsNullOrWhiteSpace($aiApiKey)) {
    $credDir = Split-Path -Parent $CredentialsPath
    if (-not [string]::IsNullOrWhiteSpace($credDir) -and -not (Test-Path $credDir)) {
        New-Item -ItemType Directory -Force -Path $credDir | Out-Null
    }
    if (Test-Path $CredentialsPath) {
        $credRaw = Get-Content -Path $CredentialsPath -Raw
        if ($credRaw -match '(?m)^(\s*)ANTHROPIC_API_KEY\s*:.*$') {
            $credRaw = [regex]::Replace($credRaw, '(?m)^(\s*)ANTHROPIC_API_KEY\s*:.*$', ('$1ANTHROPIC_API_KEY: ' + $aiApiKey))
        } elseif ($credRaw -match '(?m)^refs:\s*\{\}\s*$') {
            $credRaw = [regex]::Replace($credRaw, '(?m)^refs:\s*\{\}\s*$', ("refs:`n  ANTHROPIC_API_KEY: " + $aiApiKey))
        } elseif ($credRaw -match '(?m)^refs:\s*$') {
            $credRaw = [regex]::Replace($credRaw, '(?m)^refs:\s*$', ("refs:`n  ANTHROPIC_API_KEY: " + $aiApiKey))
        } else {
            $credRaw = $credRaw.TrimEnd() + "`nrefs:`n  ANTHROPIC_API_KEY: $aiApiKey`n"
        }
        Set-Content -Path $CredentialsPath -Value $credRaw -Encoding UTF8
        Write-Host "  -> Updated ANTHROPIC_API_KEY in $CredentialsPath" -ForegroundColor Green
    } else {
        $credNew = "version: 1`nrecords: {}`nrefs:`n  ANTHROPIC_API_KEY: $aiApiKey`n"
        Set-Content -Path $CredentialsPath -Value $credNew -Encoding UTF8
        Write-Host "  -> Created $CredentialsPath" -ForegroundColor Green
    }
} elseif ([string]::IsNullOrWhiteSpace($aiApiKey)) {
    Write-Warning "AI_API_KEY is empty - skipping .credentials.yaml update."
}

Write-Host "`nBootstrap for DSH finished. Notes:" -ForegroundColor Green
Write-Host '  - LLM auth uses apiKeyEnv ANTHROPIC_API_KEY (stored in harness .credentials.yaml). Set it in DSH Settings or via:'
Write-Host '      $env:ANTHROPIC_API_KEY = "..."'
Write-Host '  - Atlassian tokens (optional, else placeholder):'
Write-Host '      $env:JIRA_PERSONAL_TOKEN = "..."'
Write-Host '      $env:CONFLUENCE_PERSONAL_TOKEN = "..."'
Write-Host '  - Restart DSH Desktop so the new cordis.patch.yml takes effect.'