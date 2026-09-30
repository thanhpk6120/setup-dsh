# test-bootstrap.ps1 - Assert-based test for DSH bootstrap script
$ErrorActionPreference = "Stop"

$tempHome = Join-Path $env:TEMP ("dsh-home-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempProfile = Join-Path $env:TEMP ("dsh-profile-test-" + [System.Guid]::NewGuid().ToString("N"))

try {
    Write-Host "Running DSH bootstrap into temp dirs: $tempHome, $tempProfile"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -DshHome $tempHome -DshProfileDir $tempProfile
    
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
    
    # Check that placeholders are intact or replaced correctly
    if ($yamlRaw.Contains("NTg5NDM4ODY3ODUzOvauX4uXJ")) {
        throw "ASSERTION FAILED: cordis.patch.yml leaked personal token instead of using env placeholder"
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
    if (Test-Path $tempHome) { Remove-Item -Recurse -Force $tempHome }
    if (Test-Path $tempProfile) { Remove-Item -Recurse -Force $tempProfile }
}