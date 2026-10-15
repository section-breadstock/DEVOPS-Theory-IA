#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the local demonstration of the Trivy container security gate.

.DESCRIPTION
    1. Verifies Docker is installed and the daemon is running (Linux containers).
    2. Runs the Node.js unit tests (npm test).
    3. Builds the vulnerable demonstration image (DEMO_SCENARIO=vulnerable).
    4. Builds the fixed image (DEMO_SCENARIO=fixed).
    5. If the Trivy CLI is installed locally, scans both images with the gate policy
       (library vulnerabilities, HIGH,CRITICAL) and checks the expected outcomes:
         - vulnerable image: gate must FAIL (non-zero exit code, qualifying finding present)
         - fixed image:      gate must PASS (zero exit code)
    6. If Trivy is NOT installed, the scans are skipped and the script says so explicitly.
       It never reports a local scan as successful when it did not run.

    Exit codes:
      0  all executed checks met their expectations
      1  an unexpected outcome or script error occurred

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\demo.ps1
#>

[CmdletBinding()]
param(
    # Directory where the JSON reports are written (git-ignored). Defaults to <project>\reports.
    [string]$ReportDir
)

# Native command failures are NOT turned into terminating errors; each exit code is checked explicitly.
$ErrorActionPreference = 'Continue'

# Resolve the project root from the script location (works with -File and dot-sourcing).
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $ScriptDir '..')).Path
Set-Location -LiteralPath $ProjectRoot

if ([string]::IsNullOrWhiteSpace($ReportDir)) {
    $ReportDir = Join-Path $ProjectRoot 'reports'
}

$Severity = 'HIGH,CRITICAL'
$script:Failures = 0

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host ('==> ' + $Message) -ForegroundColor Cyan
}

function Write-Pass {
    param([string]$Message)
    Write-Host ('[PASS] ' + $Message) -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host ('[FAIL] ' + $Message) -ForegroundColor Red
    $script:Failures++
}

function Write-Info {
    param([string]$Message)
    Write-Host ('[INFO] ' + $Message) -ForegroundColor Yellow
}


# ---------------------------------------------------------------------------
# 1. Docker availability
# ---------------------------------------------------------------------------
Write-Step 'Checking Docker availability'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Fail 'Docker CLI not found on PATH. Install Docker Desktop and re-run this script.'
    exit 1
}

$dockerOs = (& docker info --format '{{.OSType}}' 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dockerOs)) {
    Write-Fail 'Docker daemon is not running. Start Docker Desktop, wait for "Engine running", then re-run.'
    exit 1
}
if ($dockerOs -ne 'linux') {
    Write-Fail "Docker is using '$dockerOs' containers. Switch Docker Desktop to Linux containers."
    exit 1
}
Write-Pass "Docker daemon is running with Linux containers (OSType=$dockerOs)."

# ---------------------------------------------------------------------------
# 2. Unit tests
# ---------------------------------------------------------------------------
Write-Step 'Running application unit tests (npm test)'

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'node_modules'))) {
    Write-Info 'node_modules not found; running npm ci to install the locked fixed dependencies.'
    npm ci
    if ($LASTEXITCODE -ne 0) {
        Write-Fail 'npm ci failed. See the output above.'
        exit 1
    }
}

npm test
$testExit = $LASTEXITCODE
if ($testExit -ne 0) {
    Write-Fail "Unit tests failed with exit code $testExit. Stopping."
    exit 1
}
Write-Pass 'Unit tests passed.'

# ---------------------------------------------------------------------------
# 3-4. Build both images
# ---------------------------------------------------------------------------
foreach ($scenario in @('vulnerable', 'fixed')) {
    Write-Step "Building Docker image for DEMO_SCENARIO=$scenario"
    docker build --build-arg "DEMO_SCENARIO=$scenario" --tag "trivy-demo:$scenario" .
    $buildExit = $LASTEXITCODE
    if ($buildExit -ne 0) {
        Write-Fail "Docker build for '$scenario' failed with exit code $buildExit."
        exit 1
    }
    Write-Pass "Built trivy-demo:$scenario."
}


# ---------------------------------------------------------------------------
# 5. Trivy scans (only if the CLI is installed locally)
# ---------------------------------------------------------------------------
Write-Step 'Checking for local Trivy CLI'

if (-not (Get-Command trivy -ErrorAction SilentlyContinue)) {
    Write-Info 'Trivy CLI is NOT installed locally. The vulnerability scans were NOT executed.'
    Write-Info 'The images were built, but the security gate has NOT been verified locally.'
    Write-Info 'To reproduce both scenarios through GitHub Actions instead (see README.md, sections 17-18):'
    Write-Info '  1. Push the project to GitHub.'
    Write-Info '  2. Actions > "Trivy Security Gate" > Run workflow > scenario = vulnerable  (expect FAILED gate).'
    Write-Info '  3. Actions > "Trivy Security Gate" > Run workflow > scenario = fixed       (expect PASSED gate).'
    Write-Info 'Optional: install Trivy (https://trivy.dev/docs/latest/getting-started/installation/) and re-run.'
    Write-Host ''
    Write-Host 'Partial demo completed: unit tests and image builds passed. Gate verification was skipped.' -ForegroundColor Yellow
    exit 0
}

$trivyVersion = (& trivy --version 2>$null | Select-Object -First 1)
Write-Pass "Trivy CLI found: $trivyVersion"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

# Relative report paths are used so the same commands work with the native Trivy CLI and with the
# containerized Trivy (which can only write into the mounted project directory).
$ReportRel = 'reports'

# ---------------------------------------------------------------------------
# 5a. Vulnerable image: the gate is EXPECTED to fail.
#     A non-zero exit code here is the successful demonstration, not a script error.
# ---------------------------------------------------------------------------
Write-Step 'Scanning trivy-demo:vulnerable (expected: gate FAILS)'

# Report-generation step (exit-code 0 so the JSON is always written).
trivy image --scanners vuln --vuln-type library --severity $Severity --format json --output "$ReportRel/trivy-report-vulnerable.json" --exit-code 0 trivy-demo:vulnerable
if ($LASTEXITCODE -ne 0) { Write-Fail "Trivy report generation failed for the vulnerable image (exit $LASTEXITCODE)."; exit 1 }

# Enforcement step (exit-code 1 when qualifying findings exist). Its non-zero exit is EXPECTED here.
trivy image --scanners vuln --vuln-type library --severity $Severity --format table --exit-code 1 trivy-demo:vulnerable
$vulnGateExit = $LASTEXITCODE
$vulnReport = Join-Path $ProjectRoot 'reports\trivy-report-vulnerable.json'

if (-not (Test-Path -LiteralPath $vulnReport)) {
    Write-Fail "Vulnerable JSON report was not created at $vulnReport."
} else {
    $vulnJson = Get-Content -LiteralPath $vulnReport -Raw | ConvertFrom-Json
    $findings = @()
    if ($vulnJson.Results) {
        foreach ($result in $vulnJson.Results) {
            if ($result.Vulnerabilities) { $findings += $result.Vulnerabilities }
        }
    }
    $lodashFindings = @($findings | Where-Object { $_.PkgName -eq 'lodash' -and $_.Severity -in @('HIGH', 'CRITICAL') })
    if ($lodashFindings.Count -gt 0) {
        Write-Pass "Vulnerable image has $($lodashFindings.Count) HIGH/CRITICAL lodash finding(s) in the JSON report."
        foreach ($f in $lodashFindings) {
            $fixed = if ($f.FixedVersion) { $f.FixedVersion } else { 'n/a' }
            Write-Info ("  {0} {1} {2} ({3}) fixed in: {4}" -f $f.VulnerabilityID, $f.PkgName, $f.InstalledVersion, $f.Severity, $fixed)
        }
    } else {
        Write-Fail 'Vulnerable image did NOT produce the expected HIGH/CRITICAL lodash finding.'
    }
}

if ($vulnGateExit -ne 0) {
    Write-Pass "Security gate FAILED for the vulnerable image as expected (exit code $vulnGateExit)."
} else {
    Write-Fail 'Security gate PASSED for the vulnerable image, but it was expected to fail.'
}

# ---------------------------------------------------------------------------
# 5b. Fixed image: the gate is EXPECTED to pass.
# ---------------------------------------------------------------------------
Write-Step 'Scanning trivy-demo:fixed (expected: gate PASSES)'

trivy image --scanners vuln --vuln-type library --severity $Severity --format json --output "$ReportRel/trivy-report-fixed.json" --exit-code 0 trivy-demo:fixed
if ($LASTEXITCODE -ne 0) { Write-Fail "Trivy report generation failed for the fixed image (exit $LASTEXITCODE)."; exit 1 }

trivy image --scanners vuln --vuln-type library --severity $Severity --format table --exit-code 1 trivy-demo:fixed
$fixedGateExit = $LASTEXITCODE
$fixedReport = Join-Path $ProjectRoot 'reports\trivy-report-fixed.json'

if ($fixedGateExit -eq 0) {
    Write-Pass 'Security gate PASSED for the fixed image (exit code 0).'
} else {
    Write-Fail "Security gate FAILED for the fixed image (exit code $fixedGateExit)."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host 'Demo completed: all expected outcomes were verified.' -ForegroundColor Green
    Write-Host "Reports written to: $ReportDir"
    exit 0
}
Write-Host "Demo completed with $($script:Failures) unexpected outcome(s)." -ForegroundColor Red
exit 1
