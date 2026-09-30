# bootstrap.ps1 - Bootstrap DSH Desktop environment on fresh machine
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipInstall,
    [string]$DshHome = "$env:USERPROFILE\.dsh",
    [string]$DshProfileDir = "$env:APPDATA\dsh-desktop\harness\profiles\web",
    [string]$CloakBrowserPath = "D:\Thanhpk\AI\cloakbrowser\mcp-server-full.mjs"
)

$ErrorActionPreference = "Stop"

function Get-EnvOrPrompt {
    param(
        [string]$EnvName,
        [string]$PromptMessage,
        [string]$DefaultValue
    )
    $val = [Environment]::GetEnvironmentVariable($EnvName)
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ([string]::IsNullOrWhiteSpace($DefaultValue)) {
            $val = Read-Host "$PromptMessage (leave empty for none)"
        } else {
            $val = Read-Host "$PromptMessage [$DefaultValue]"
            if ([string]::IsNullOrWhiteSpace($val)) {
                $val = $DefaultValue
            }
        }
    }
    return $val
}


Write-Host "==> Checking runtime dependencies..." -ForegroundColor Cyan
foreach ($tool in @("node", "npm", "git")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Missing '$tool' in PATH. Please install it first."
    }
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

# gitnexus: vendor recommends a global install + absolute-path config to avoid npx
# cold-cache stalls exceeding the 30s MCP timeout
# (https://github.com/abhigyanpatwari/GitNexus README, "Fastest MCP startup").
$gitnexusAbs = "__GITNEXUS_ABS_PATH__"
if (-not $SkipInstall) {
    Write-Host "==> Installing gitnexus globally..." -ForegroundColor Cyan
    if (-not $DryRun) {
        try {
            npm install -g gitnexus --silent
        } catch {
            Write-Warning "gitnexus global install failed, falling back to detected path: $($_.Exception.Message)"
        }
    }
}
$gitnexusBin = Get-Command "gitnexus" -ErrorAction SilentlyContinue
if ($gitnexusBin -and $gitnexusBin.Source) {
    $gitnexusAbs = $gitnexusBin.Source
}

$context7Abs = "__CONTEXT7_JS_PATH__"
if (-not $SkipInstall) {
    Write-Host "==> Installing context7 globally..." -ForegroundColor Cyan
    if (-not $DryRun) {
        try {
            npm install -g @upstash/context7-mcp --silent
        } catch {
            Write-Warning "context7 global install failed, falling back to detected path: $($_.Exception.Message)"
        }
    }
}
try {
    $npmGlobalRoot = npm root -g 2>$null
    if ($npmGlobalRoot) {
        $ctxJsPath = Join-Path $npmGlobalRoot "@upstash\context7-mcp\dist\index.js"
        if (Test-Path $ctxJsPath) {
            $context7Abs = $ctxJsPath
        }
    }
} catch {}

Write-Host "==> Ensuring directory $DshProfileDir exists..." -ForegroundColor Cyan
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $DshProfileDir | Out-Null
}

# cordis.patch.yml template — mirrors live profile; placeholders resolved below.
#   llm-pi-ai (anthropic @ 9router): 4 models claude-fable-5 / claude-haiku-4-5-20251001 / claude-opus-5 / claude-sonnet-5
#   subagent-model-selection-settings: all 4 models allowed
#   MCPs: memorix / gitnexus / company-atlassian (pinned mcp-atlassian==0.23.1) / cloakbrowser / context7
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
        baseURL: __PROVIDER_BASE_URL__
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
    command: cmd
    args:
      - /c
      - __GITNEXUS_ABS_PATH__
      - mcp
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
      TOOLSETS: jira,confluence
- id: mcp-cloakbrowser
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: cloakbrowser
    transport: stdio
    command: node
    args:
      - __CLOAKBROWSER_PATH__
- id: mcp-context7
  name: "@deepseek-ai/dsh-mcp-client"
  config:
    serverName: context7
    transport: stdio
    command: node
    args:
      - __CONTEXT7_JS_PATH__
    env:
      CONTEXT7_API_KEY: __CONTEXT7_API_KEY__
'@

Write-Host "==> Preparing configuration file..." -ForegroundColor Cyan
Write-Host ""
Write-Host "==> Gathering configuration..." -ForegroundColor Cyan
$providerBaseUrl = Get-EnvOrPrompt -EnvName "PROVIDER_BASE_URL" -PromptMessage "Provider Base URL" -DefaultValue "https://9router.thanhpk.io.vn/v1"
$jiraUrl = Get-EnvOrPrompt -EnvName "JIRA_URL" -PromptMessage "Jira URL" -DefaultValue "https://jira.cybertech.vn"
$jiraToken = Get-EnvOrPrompt -EnvName "JIRA_PERSONAL_TOKEN" -PromptMessage "Jira Personal Token" -DefaultValue "YOUR_JIRA_PERSONAL_TOKEN"
$confUrl = Get-EnvOrPrompt -EnvName "CONFLUENCE_URL" -PromptMessage "Confluence URL" -DefaultValue "https://conf.cybertech.vn"
$confToken = Get-EnvOrPrompt -EnvName "CONFLUENCE_PERSONAL_TOKEN" -PromptMessage "Confluence Personal Token" -DefaultValue "YOUR_CONFLUENCE_PERSONAL_TOKEN"
$context7ApiKey = Get-EnvOrPrompt -EnvName "CONTEXT7_API_KEY" -PromptMessage "Context7 API Key" -DefaultValue ""

$escapedCloakBrowser = $CloakBrowserPath -replace '\\', '\\'

$cordisYaml = $cordisTemplate
$cordisYaml = $cordisYaml.Replace("__PROVIDER_BASE_URL__", $providerBaseUrl)
$cordisYaml = $cordisYaml.Replace("__JIRA_URL__", $jiraUrl)
$cordisYaml = $cordisYaml.Replace("__JIRA_PERSONAL_TOKEN__", $jiraToken)
$cordisYaml = $cordisYaml.Replace("__CONFLUENCE_URL__", $confUrl)
$cordisYaml = $cordisYaml.Replace("__CONFLUENCE_PERSONAL_TOKEN__", $confToken)
$cordisYaml = $cordisYaml.Replace("__CONTEXT7_API_KEY__", $context7ApiKey)
$cordisYaml = $cordisYaml.Replace("__CLOAKBROWSER_PATH__", $escapedCloakBrowser)
$cordisYaml = $cordisYaml.Replace("__GITNEXUS_ABS_PATH__", ($gitnexusAbs -replace '\\', '\\'))
$cordisYaml = $cordisYaml.Replace("__CONTEXT7_JS_PATH__", ($context7Abs -replace '\\', '\\'))
if (-not (Test-Path $CloakBrowserPath)) {
    Write-Warning "CloakBrowser server not found at '$CloakBrowserPath' - omitting mcp-cloakbrowser from cordis.patch.yml"
    $cordisYaml = $cordisYaml -replace "(?ms)\r?\n- id: mcp-cloakbrowser\r?\n(?:.*\r?\n)*?      - __CLOAKBROWSER_PATH__".Replace("__CLOAKBROWSER_PATH__", [regex]::Escape($escapedCloakBrowser)), ''
}

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
    if (-not $DryRun -and -not (Test-Path $targetSkillsDir)) {
        New-Item -ItemType Directory -Force -Path $targetSkillsDir | Out-Null
    }
    
    $skillItems = Get-ChildItem -Path $sourceSkillsDir
    foreach ($item in $skillItems) {
        $targetItem = Join-Path $targetSkillsDir $item.Name
        if (Test-Path $targetItem) {
            Write-Host "  -> Skipping skill $($item.Name) (already exists)" -ForegroundColor Yellow
        } else {
            Write-Host "  -> Copying skill $($item.Name)" -ForegroundColor Green
            if (-not $DryRun) {
                Copy-Item -Path $item.FullName -Destination $targetItem -Recurse -Force
            }
        }
    }
}


Write-Host "`nBootstrap for DSH finished. Notes:" -ForegroundColor Green
Write-Host '  - LLM auth uses apiKeyEnv ANTHROPIC_API_KEY (stored in harness .credentials.yaml). Set it in DSH Settings or via:'
Write-Host '      $env:ANTHROPIC_API_KEY = "..."'
Write-Host '  - Atlassian tokens (optional, else placeholder):'
Write-Host '      $env:JIRA_PERSONAL_TOKEN = "..."'
Write-Host '      $env:CONFLUENCE_PERSONAL_TOKEN = "..."'
Write-Host '  - Restart DSH Desktop so the new cordis.patch.yml takes effect.'