# test-bootstrap.ps1 - Assert-based test for DSH bootstrap script
$ErrorActionPreference = "Stop"

$tempHome = Join-Path $env:TEMP ("dsh-home-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempProfile = Join-Path $env:TEMP ("dsh-profile-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempCredsDir = Join-Path $env:TEMP ("dsh-creds-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempCreds = Join-Path $tempCredsDir ".credentials.yaml"

$env:AI_BASE_URL = "https://mock.provider.com/v1"
$env:AI_API_KEY = "MOCK_AI_API_KEY"
$env:JIRA_URL = "https://mock.jira.com"
$env:JIRA_PERSONAL_TOKEN = "MOCK_JIRA_TOKEN"
$env:CONFLUENCE_URL = "https://mock.conf.com"
$env:CONFLUENCE_PERSONAL_TOKEN = "MOCK_CONF_TOKEN"
$env:CONTEXT7_API_KEY = "MOCK_CONTEXT7_KEY"

$oldErrorActionPreference = $ErrorActionPreference

try {
    Write-Host "Running DSH bootstrap into temp dirs: $tempHome, $tempProfile"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -DshHome $tempHome -DshProfileDir $tempProfile -CredentialsPath $tempCreds
    
    $path = Join-Path $tempProfile "cordis.patch.yml"
    if (-not (Test-Path $path)) {
        throw "ASSERTION FAILED: Missing generated file: $path"
    }
    
    $yamlRaw = Get-Content $path -Raw
    if (-not $yamlRaw.Contains("serverName: gitnexus") -or -not $yamlRaw.Contains("serverName: memorix") -or -not $yamlRaw.Contains("serverName: company-atlassian") -or -not $yamlRaw.Contains("serverName: context7")) {
        throw "ASSERTION FAILED: cordis.patch.yml is missing one or more MCP servers"
    }
    
    if (-not $yamlRaw.Contains("model: claude-sonnet-5")) {
        throw "ASSERTION FAILED: cordis.patch.yml is missing models block"
    }
    
    if (-not $yamlRaw.Contains("apiKeyEnv: ANTHROPIC_API_KEY")) {
        throw "ASSERTION FAILED: cordis.patch.yml lost apiKeyEnv ANTHROPIC_API_KEY"
    }
    
    if (-not $yamlRaw.Contains("baseURL: https://mock.provider.com/v1")) {
        throw "ASSERTION FAILED: cordis.patch.yml did not replace AI_BASE_URL correctly"
    }
    if (-not $yamlRaw.Contains("JIRA_URL: https://mock.jira.com")) {
        throw "ASSERTION FAILED: cordis.patch.yml did not replace JIRA_URL correctly"
    }
    if (-not $yamlRaw.Contains("JIRA_PERSONAL_TOKEN: MOCK_JIRA_TOKEN")) {
        throw "ASSERTION FAILED: cordis.patch.yml did not replace JIRA_PERSONAL_TOKEN correctly"
    }
    if (-not $yamlRaw.Contains("CONFLUENCE_URL: https://mock.conf.com")) {
        throw "ASSERTION FAILED: cordis.patch.yml did not replace CONFLUENCE_URL correctly"
    }
    if (-not $yamlRaw.Contains("CONFLUENCE_PERSONAL_TOKEN: MOCK_CONF_TOKEN")) {
        throw "ASSERTION FAILED: cordis.patch.yml did not replace CONFLUENCE_PERSONAL_TOKEN correctly"
    }
    if (-not $yamlRaw.Contains("CONTEXT7_API_KEY: MOCK_CONTEXT7_KEY")) {
        throw "ASSERTION FAILED: cordis.patch.yml did not replace CONTEXT7_API_KEY correctly"
    }
    
    if (-not (Test-Path $tempCreds)) {
        throw "ASSERTION FAILED: Missing generated credentials file: $tempCreds"
    }
    $credRaw = Get-Content $tempCreds -Raw
    if (-not $credRaw.Contains("refs:")) {
        throw "ASSERTION FAILED: .credentials.yaml missing refs: block"
    }
    if (-not $credRaw.Contains("ANTHROPIC_API_KEY: MOCK_AI_API_KEY")) {
        throw "ASSERTION FAILED: .credentials.yaml did not inject ANTHROPIC_API_KEY correctly"
    }

    $agentsPath = Join-Path $tempHome "AGENTS.md"
    if (-not (Test-Path $agentsPath)) {
        throw "ASSERTION FAILED: Missing copied file: $agentsPath"
    }

    $skills = Get-ChildItem -Path (Join-Path $tempHome "skills") -Filter "SKILL.md" -Recurse -ErrorAction SilentlyContinue
    if (-not $skills -or $skills.Count -lt 1) {
        throw "ASSERTION FAILED: Missing at least 1 skill SKILL.md under $tempHome/skills"
    }

    Write-Host "TEST PASSED: DSH bootstrap created valid configs." -ForegroundColor Green
}
finally {
    Remove-Item env:AI_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item env:AI_API_KEY -ErrorAction SilentlyContinue
    Remove-Item env:PROVIDER_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item env:JIRA_URL -ErrorAction SilentlyContinue
    Remove-Item env:JIRA_PERSONAL_TOKEN -ErrorAction SilentlyContinue
    Remove-Item env:CONFLUENCE_URL -ErrorAction SilentlyContinue
    Remove-Item env:CONFLUENCE_PERSONAL_TOKEN -ErrorAction SilentlyContinue
    Remove-Item env:CONTEXT7_API_KEY -ErrorAction SilentlyContinue
    if (Test-Path $tempHome) { Remove-Item -Recurse -Force $tempHome }
    if (Test-Path $tempProfile) { Remove-Item -Recurse -Force $tempProfile }
    if (Test-Path $tempCredsDir) { Remove-Item -Recurse -Force $tempCredsDir }
}
