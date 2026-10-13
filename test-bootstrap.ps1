# test-bootstrap.ps1 - Assert-based test for DSH bootstrap script
$ErrorActionPreference = "Stop"

$tempHome = Join-Path $env:TEMP ("dsh-home-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempProfile = Join-Path $env:TEMP ("dsh-profile-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempProfile2 = Join-Path $env:TEMP ("dsh-profile-test2-" + [System.Guid]::NewGuid().ToString("N"))
$tempProfile3 = Join-Path $env:TEMP ("dsh-profile-test3-" + [System.Guid]::NewGuid().ToString("N"))
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
Set-Content -Path (Join-Path $mockBinDir "npm.cmd") -Value "@echo off`nif `"%1`"==`"root`" if `"%2`"==`"-g`" (echo $mockNpmDir& exit /b 0)`nexit /b 0"
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
    # Test 1: DryRun / SkipInstall / Default mode -> Tat ca MCP mac dinh bi tu choi (N)
    Write-Host "Running DSH bootstrap (Test 1: SkipInstall non-interactive, all MCPs skipped) into temp dirs: $tempHome, $tempProfile"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -DshHome $tempHome -DshProfileDir $tempProfile -CredentialsPath $tempCreds

    $path = Join-Path $tempProfile "cordis.patch.yml"
    if (-not (Test-Path $path)) {
        throw "ASSERTION FAILED: Missing generated file: $path"
    }

    $yamlRaw = Get-Content $path -Raw
    if ($yamlRaw.Contains("serverName: gitnexus") -or $yamlRaw.Contains("serverName: memorix") -or $yamlRaw.Contains("serverName: company-atlassian") -or $yamlRaw.Contains("serverName: context7") -or $yamlRaw.Contains("serverName: cloakbrowser") -or $yamlRaw.Contains("serverName: glab")) {
        throw "ASSERTION FAILED: In default run with SkipInstall, skipped MCP servers should NOT be present in cordis.patch.yml"
    }

    if ($yamlRaw.Contains("__AI_BASE_URL__") -or $yamlRaw.Contains("__JIRA_URL__") -or $yamlRaw.Contains("__GITNEXUS_CONFIG__") -or $yamlRaw.Contains("__CONTEXT7_CONFIG__") -or $yamlRaw.Contains("__CLOAKBROWSER_SCRIPT__")) {
        throw "ASSERTION FAILED: Unresolved placeholders found in cordis.patch.yml"
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

    # Test 2: Mock pipeline Y/N - Case 1: Tu choi het (pipe n cho 6 MCP prompts)
    Write-Host "`nRunning DSH bootstrap (Test 2: Pipeline Y/N - Refuse all MCPs) into $tempProfile2"
    $psScript = "$PSScriptRoot\bootstrap.ps1"
    $refuseAll = "n`nn`nn`nn`nn`nn`n"
    $refuseAll | pwsh -NoProfile -ExecutionPolicy Bypass -Command @"
        `$env:CI = `$null
        [Environment]::SetEnvironmentVariable('CI', `$null, 'Process')
        `$env:AI_BASE_URL = '$($env:AI_BASE_URL)'
        `$env:AI_API_KEY = '$($env:AI_API_KEY)'
        `$env:Path = '$($env:Path)'
        & '$psScript' -DryRun:`$false -DshHome '$tempHome' -DshProfileDir '$tempProfile2' -CredentialsPath '$tempCreds'
"@

    $path2 = Join-Path $tempProfile2 "cordis.patch.yml"
    if (-not (Test-Path $path2)) {
        throw "ASSERTION FAILED: Missing generated file: $path2"
    }
    $yamlRaw2 = Get-Content $path2 -Raw
    if ($yamlRaw2.Contains("serverName: gitnexus") -or $yamlRaw2.Contains("serverName: memorix") -or $yamlRaw2.Contains("serverName: company-atlassian") -or $yamlRaw2.Contains("serverName: context7") -or $yamlRaw2.Contains("serverName: cloakbrowser") -or $yamlRaw2.Contains("serverName: glab")) {
        throw "ASSERTION FAILED: cordis.patch.yml should NOT contain any MCP server when user chooses 'n' to all"
    }

    # Test 3: Mock pipeline Y/N - Case 2: Nhan memorix (y) nhung tu choi hook (n), cac MCP con lai tu choi (n)
    # Thu tu prompts trong bootstrap.ps1:
    # 1. MCP 'memorix'? -> y
    # 2. MCP 'company-atlassian'? -> n
    # 3. MCP 'gitnexus'? -> n
    # 4. MCP 'context7'? -> n
    # 5. MCP 'glab'? -> n
    # 6. MCP 'cloakbrowser'? -> n
    # 7. Hook memorix vao DSH? -> n
    Write-Host "`nRunning DSH bootstrap (Test 3: Pipeline Y/N - Accept memorix, refuse hook & other MCPs) into $tempProfile3"
    $acceptMemorixOnly = "y`nn`nn`nn`nn`nn`nn`n"
    $acceptMemorixOnly | pwsh -NoProfile -ExecutionPolicy Bypass -Command @"
        `$env:CI = `$null
        [Environment]::SetEnvironmentVariable('CI', `$null, 'Process')
        `$env:AI_BASE_URL = '$($env:AI_BASE_URL)'
        `$env:AI_API_KEY = '$($env:AI_API_KEY)'
        `$env:Path = '$($env:Path)'
        & '$psScript' -DryRun:`$false -DshHome '$tempHome' -DshProfileDir '$tempProfile3' -CredentialsPath '$tempCreds'
"@

    $path3 = Join-Path $tempProfile3 "cordis.patch.yml"
    if (-not (Test-Path $path3)) {
        throw "ASSERTION FAILED: Missing generated file: $path3"
    }
    $yamlRaw3 = Get-Content $path3 -Raw
    if (-not $yamlRaw3.Contains("serverName: memorix") -or -not $yamlRaw3.Contains("- id: mcp-memorix")) {
        throw "ASSERTION FAILED: cordis.patch.yml should contain memorix when user chose 'y'"
    }
    if ($yamlRaw3.Contains("serverName: gitnexus") -or $yamlRaw3.Contains("serverName: company-atlassian") -or $yamlRaw3.Contains("serverName: context7") -or $yamlRaw3.Contains("serverName: cloakbrowser") -or $yamlRaw3.Contains("serverName: glab")) {
        throw "ASSERTION FAILED: cordis.patch.yml should NOT contain other MCPs when rejected"
    }

    Write-Host "`nAll isolated tests passed successfully!" -ForegroundColor Green
}
finally {
    $env:Path = $oldPath
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    function Safe-Trash($p) {
        if ($p -and (Test-Path $p)) {
            if (Get-Command "trash" -ErrorAction SilentlyContinue) {
                trash $p
            } else {
                try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin) } catch {}
                try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin) } catch {}
            }
        }
    }

    Safe-Trash $mockBinDir
    Safe-Trash $mockNpmDir
    if (Test-Path Function:npm) { Microsoft.PowerShell.Management\Remove-Item Function:npm -ErrorAction SilentlyContinue }
    Safe-Trash $tempHome
    Safe-Trash $tempProfile
    if ($tempProfile2) { Safe-Trash $tempProfile2 }
    if ($tempProfile3) { Safe-Trash $tempProfile3 }
    Safe-Trash $tempCredsDir
}
