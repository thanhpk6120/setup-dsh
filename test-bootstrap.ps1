# test-bootstrap.ps1 - Assert-based test for DSH bootstrap script
$ErrorActionPreference = "Stop"

$tempHome = Join-Path $env:TEMP ("dsh-home-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempProfile = Join-Path $env:TEMP ("dsh-profile-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempProfile2 = $null
$tempCredsDir = Join-Path $env:TEMP ("dsh-creds-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempCreds = Join-Path $tempCredsDir ".credentials.yaml"

$env:AI_BASE_URL = "https://mock.provider.com/v1"
$env:AI_API_KEY = "MOCK_AI_API_KEY"
$env:JIRA_URL = "https://mock.jira.com"
$env:JIRA_PERSONAL_TOKEN = "MOCK_JIRA_TOKEN"
$env:CONFLUENCE_URL = "https://mock.conf.com"
$env:CONFLUENCE_PERSONAL_TOKEN = "MOCK_CONF_TOKEN"
$env:CONTEXT7_API_KEY = "MOCK_CONTEXT7_KEY"


# Setup mock environment for gitnexus and context7 to ensure test succeeds in clean environment
$mockBinDir = Join-Path $env:TEMP ("dsh-mock-bin-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $mockBinDir | Out-Null
Set-Content -Path (Join-Path $mockBinDir "gitnexus.cmd") -Value "@echo off`necho gitnexus"
$oldPath = $env:Path
$env:Path = "$mockBinDir;$env:Path"

$mockNpmDir = Join-Path $env:TEMP ("dsh-mock-npm-" + [System.Guid]::NewGuid().ToString("N"))
$mockContext7Path = Join-Path $mockNpmDir "@upstash\context7-mcp\dist"
New-Item -ItemType Directory -Force -Path $mockContext7Path | Out-Null
Set-Content -Path (Join-Path $mockContext7Path "index.js") -Value "// mock"

function global:npm {
    param([Parameter(ValueFromRemainingArguments)]$remaining)
    if ($remaining -contains "root" -and $remaining -contains "-g") {
        return $mockNpmDir
    }
    $realNpm = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($realNpm) {
        & $realNpm @remaining
    }
}

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

    if (-not $yamlRaw.Contains("serverName: cloakbrowser") -or -not $yamlRaw.Contains("mcp-cloakbrowser")) {
        throw "ASSERTION FAILED: cordis.patch.yml should contain cloakbrowser"
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

    # Test 2: when CONTEXT7_API_KEY is empty, env block should NOT be present
    $env:CONTEXT7_API_KEY = ""
    $tempProfile2 = Join-Path $env:TEMP ("dsh-profile-test-" + [System.Guid]::NewGuid().ToString("N"))
    Write-Host "Running DSH bootstrap again with empty CONTEXT7_API_KEY into $tempProfile2"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -DshHome $tempHome -DshProfileDir $tempProfile2 -CredentialsPath $tempCreds
    $path2 = Join-Path $tempProfile2 "cordis.patch.yml"
    $yamlRaw2 = Get-Content $path2 -Raw
    if ($yamlRaw2.Contains("CONTEXT7_API_KEY")) {
        throw "ASSERTION FAILED: cordis.patch.yml should NOT contain CONTEXT7_API_KEY if empty"
    }

    Write-Host "TEST PASSED: DSH bootstrap created valid configs." -ForegroundColor Green
}
finally {

    $env:Path = $oldPath
    if ($mockBinDir -and (Test-Path $mockBinDir)) { Remove-Item -Recurse -Force $mockBinDir -ErrorAction SilentlyContinue }
    if ($mockNpmDir -and (Test-Path $mockNpmDir)) { Remove-Item -Recurse -Force $mockNpmDir -ErrorAction SilentlyContinue }
    Remove-Item function:global:npm -ErrorAction SilentlyContinue

    Remove-Item env:AI_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item env:AI_API_KEY -ErrorAction SilentlyContinue
    Remove-Item env:PROVIDER_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item env:JIRA_URL -ErrorAction SilentlyContinue
    Remove-Item env:JIRA_PERSONAL_TOKEN -ErrorAction SilentlyContinue
    Remove-Item env:CONFLUENCE_URL -ErrorAction SilentlyContinue
    Remove-Item env:CONFLUENCE_PERSONAL_TOKEN -ErrorAction SilentlyContinue
    Remove-Item env:CONTEXT7_API_KEY -ErrorAction SilentlyContinue
    if ($tempHome -and (Test-Path $tempHome)) { Remove-Item -Recurse -Force $tempHome }
    if ($tempProfile -and (Test-Path $tempProfile)) { Remove-Item -Recurse -Force $tempProfile }
    if ($tempProfile2 -and (Test-Path $tempProfile2)) { Remove-Item -Recurse -Force $tempProfile2 }
    if ($tempCredsDir -and (Test-Path $tempCredsDir)) { Remove-Item -Recurse -Force $tempCredsDir }
}