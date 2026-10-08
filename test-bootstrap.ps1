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
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " [TEST 1] Run DSH bootstrap with -DisableMemorix (default off)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -Force -DisableMemorix -DshHome $tempHome -DshProfileDir $tempProfile -CredentialsPath $tempCreds

    $path = Join-Path $tempProfile "cordis.patch.yml"
    if (-not (Test-Path $path)) {
        throw "ASSERTION FAILED: cordis.patch.yml was not created at $path"
    }

    $yamlRaw = Get-Content $path -Raw
    Write-Host "  -> Verifying LLM Provider config..." -ForegroundColor Gray
    if (-not $yamlRaw.Contains("baseURL: https://mock.provider.com/v1")) {
        throw "ASSERTION FAILED: baseURL in cordis.patch.yml is incorrect"
    }
    if (-not $yamlRaw.Contains("apiKeyEnv: ANTHROPIC_API_KEY")) {
        throw "ASSERTION FAILED: apiKeyEnv ANTHROPIC_API_KEY is missing"
    }
    if (-not $yamlRaw.Contains("model: claude-sonnet-5")) {
        throw "ASSERTION FAILED: default model claude-sonnet-5 is missing"
    }

    Write-Host "  -> Verifying standard MCP Servers..." -ForegroundColor Gray
    if (-not $yamlRaw.Contains("serverName: gitnexus")) {
        throw "ASSERTION FAILED: mcp-gitnexus is missing"
    }
    if (-not $yamlRaw.Contains("serverName: company-atlassian")) {
        throw "ASSERTION FAILED: mcp-company-atlassian is missing"
    }
    if (-not $yamlRaw.Contains("serverName: context7")) {
        throw "ASSERTION FAILED: mcp-context7 is missing"
    }
    if (-not $yamlRaw.Contains("serverName: glab")) {
        throw "ASSERTION FAILED: mcp-glab is missing"
    }
    if (-not $yamlRaw.Contains("serverName: cloakbrowser")) {
        throw "ASSERTION FAILED: mcp-cloakbrowser is missing"
    }

    Write-Host "  -> Verifying Memorix is OFF..." -ForegroundColor Gray
    if ($yamlRaw.Contains("mcp-memorix") -or $yamlRaw.Contains("serverName: memorix")) {
        throw "ASSERTION FAILED: mcp-memorix found in cordis.patch.yml despite -DisableMemorix"
    }

    $targetAgentsPath = Join-Path $tempHome "AGENTS.md"
    if (-not (Test-Path $targetAgentsPath)) {
        throw "ASSERTION FAILED: AGENTS.md was not copied to $tempHome"
    }
    $agentsContent = Get-Content $targetAgentsPath -Raw
    if ($agentsContent.Contains("# Memorix")) {
        throw "ASSERTION FAILED: AGENTS.md contains Memorix instructions when -DisableMemorix is set"
    }

    $targetSkillsPath = Join-Path $tempHome "skills"
    if (Test-Path (Join-Path $targetSkillsPath "memorix-memory")) {
        throw "ASSERTION FAILED: memorix-memory skill exists in skills when -DisableMemorix is set"
    }
    if (-not (Test-Path (Join-Path $targetSkillsPath "security-review"))) {
        throw "ASSERTION FAILED: base skills (such as security-review) were not copied"
    }

    if (-not (Test-Path $tempCreds)) {
        throw "ASSERTION FAILED: Credentials was not created at $tempCreds"
    }
    $credsRaw = Get-Content $tempCreds -Raw
    if (-not $credsRaw.Contains("apiKey: MOCK_AI_API_KEY")) {
        throw "ASSERTION FAILED: apiKey in credentials is incorrect"
    }

    Write-Host "  => TEST 1 PASSED!" -ForegroundColor Green

    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host " [TEST 2] Run DSH bootstrap with -EnableMemorix (Memorix enabled)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    $tempProfileMem = Join-Path $env:TEMP ("dsh-profile-mem-" + [System.Guid]::NewGuid().ToString("N"))
    $tempHomeMem = Join-Path $env:TEMP ("dsh-home-mem-" + [System.Guid]::NewGuid().ToString("N"))
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -Force -EnableMemorix -DshHome $tempHomeMem -DshProfileDir $tempProfileMem -CredentialsPath $tempCreds

    $pathMem = Join-Path $tempProfileMem "cordis.patch.yml"
    $yamlRawMem = Get-Content $pathMem -Raw
    if (-not $yamlRawMem.Contains("mcp-memorix")) {
        throw "ASSERTION FAILED: mcp-memorix is missing in cordis.patch.yml when -EnableMemorix is set"
    }
    if (-not $yamlRawMem.Contains("command: memorix")) {
        throw "ASSERTION FAILED: command: memorix is missing when -EnableMemorix is set"
    }

    $agentsContentMem = Get-Content (Join-Path $tempHomeMem "AGENTS.md") -Raw
    if (-not $agentsContentMem.Contains("# Memorix")) {
        throw "ASSERTION FAILED: AGENTS.md does not contain Memorix instructions when -EnableMemorix is set"
    }

    $skillsMemDir = Join-Path $tempHomeMem "skills"
    if (-not (Test-Path (Join-Path $skillsMemDir "memorix-memory"))) {
        throw "ASSERTION FAILED: memorix-memory skill was not copied when -EnableMemorix is set"
    }
    Write-Host "  => TEST 2 PASSED!" -ForegroundColor Green

    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host " [TEST 3] Verify old Memorix skill cleanup via Safe-Trash" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    $dummySkillDir = Join-Path $targetSkillsPath "memorix-troubleshooting"
    New-Item -ItemType Directory -Force -Path $dummySkillDir | Out-Null
    Set-Content -Path (Join-Path $dummySkillDir "dummy.txt") -Value "dummy content"
    if (-not (Test-Path $dummySkillDir)) { throw "ASSERTION FAILED: Failed to create dummy skill" }

    # Run again with -DisableMemorix
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -Force -DisableMemorix -DshHome $tempHome -DshProfileDir $tempProfile -CredentialsPath $tempCreds

    if (Test-Path $dummySkillDir) {
        throw "ASSERTION FAILED: Dummy skill memorix-troubleshooting was not cleaned up when Memorix disabled"
    }
    Write-Host "  => TEST 3 PASSED!" -ForegroundColor Green

    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host " [TEST 4] Verify YAML configuration Merge (cordis.patch.yml)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    $customServerYaml = "- id: mcp-my-custom-db`r`n  name: `"@deepseek-ai/dsh-mcp-client`"`r`n  config:`r`n    serverName: my-custom-db`r`n    transport: stdio"
    $existingYaml = $yamlRaw + "`r`n" + $customServerYaml
    Set-Content -Path $path -Value $existingYaml -Encoding UTF8

    . "$PSScriptRoot\bootstrap.ps1" -DryRun:$true -SkipInstall -Force -DisableMemorix -DshHome $tempHome -DshProfileDir $tempProfile -CredentialsPath $tempCreds
    $merged = Merge-CordisPatchYaml -ExistingContent $existingYaml -NewContent $yamlRaw

    if (-not $merged.Contains("mcp-my-custom-db")) {
        throw "ASSERTION FAILED: mcp-my-custom-db custom server was lost after Merge"
    }
    if (-not $merged.Contains("serverName: gitnexus")) {
        throw "ASSERTION FAILED: Standard MCP servers were lost after Merge"
    }
    Write-Host "  => TEST 4 PASSED!" -ForegroundColor Green

    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host " [TEST 5] Verify templates/ Fallback mechanism" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    $fallbackTest = Get-TemplateContent -TemplateName "non-existent-template.xyz" -FallbackContent "FALLBACK_SUCCESS_OK"
    if ($fallbackTest -ne "FALLBACK_SUCCESS_OK") {
        throw "ASSERTION FAILED: Get-TemplateContent did not return fallback when template missing"
    }

    $existingTemplateTest = Get-TemplateContent -TemplateName "cordis.patch.yml" -FallbackContent "FAIL"
    if ($existingTemplateTest -eq "FAIL" -or -not $existingTemplateTest.Contains("id: permission")) {
        throw "ASSERTION FAILED: Get-TemplateContent failed to load cordis.patch.yml from templates/"
    }
    Write-Host "  => TEST 5 PASSED!" -ForegroundColor Green

    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host " [TEST 6] Verify Safe-Trash with temp file and directory" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    $trashTestDir = Join-Path $env:TEMP ("dsh-trash-test-dir-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $trashTestDir | Out-Null
    $trashTestFile = Join-Path $trashTestDir "sample.txt"
    Set-Content -Path $trashTestFile -Value "Test Trash"

    Safe-Trash -Path $trashTestFile
    if (Test-Path $trashTestFile) {
        throw "ASSERTION FAILED: Sample file still exists after Safe-Trash"
    }

    Safe-Trash -Path $trashTestDir
    if (Test-Path $trashTestDir) {
        throw "ASSERTION FAILED: Sample directory still exists after Safe-Trash"
    }
    Write-Host "  => TEST 6 PASSED!" -ForegroundColor Green

    Write-Host "`n================================================================" -ForegroundColor Green
    Write-Host "        ALL DSH BOOTSTRAP ASSERTION TESTS PASSED!               " -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
}
finally {
    $env:Path = $oldPath
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    function Cleanup-Trash($p) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            try {
                if ([System.IO.Directory]::Exists($p)) {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, 'OnlyErrorDialogs', 'SendToRecycleBin')
                } elseif ([System.IO.File]::Exists($p)) {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin')
                }
            } catch {}
        }
    }

    Cleanup-Trash $tempHome
    Cleanup-Trash $tempProfile
    if ($tempProfile2) { Cleanup-Trash $tempProfile2 }
    if ($tempProfileMem) { Cleanup-Trash $tempProfileMem }
    if ($tempHomeMem) { Cleanup-Trash $tempHomeMem }
    Cleanup-Trash $tempCredsDir
    Cleanup-Trash $mockBinDir
    Cleanup-Trash $mockNpmDir
}
