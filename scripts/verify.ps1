[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-NativeCheck {
    param([string]$Executable, [string[]]$Arguments, [string]$StderrPath)

    # Windows PowerShell wraps redirected native stderr in ErrorRecord objects.
    $ErrorActionPreference = 'Continue'
    if ($PSVersionTable.PSVersion -ge [version]'7.3') {
        $PSNativeCommandUseErrorActionPreference = $false
    }
    $output = @(& $Executable @Arguments 2> $StderrPath)
    $status = $LASTEXITCODE
    [pscustomobject]@{
        Status = $status
        Stdout = $output -join "`n"
        Stderr = [string](Get-Content -LiteralPath $StderrPath -Raw -ErrorAction Stop)
    }
}

function Read-WorkflowRunBlock {
    param([string]$WorkflowPath, [string]$StepName)

    $workflowLines = [string[]](Get-Content -LiteralPath $WorkflowPath -Encoding UTF8)
    $runMarker = '        run: |'
    $stepStart = [Array]::IndexOf($workflowLines, "      - name: $StepName")
    if ($stepStart -lt 0) { throw "Missing step '$StepName' in $WorkflowPath." }
    $blockStart = [Array]::IndexOf($workflowLines, $runMarker, ($stepStart + 1))
    if ($blockStart -lt 0 -or $workflowLines[($stepStart + 1)..($blockStart - 1)] -match '^      - ') {
        throw "Expected a literal run block for '$StepName' in $WorkflowPath."
    }
    $indent = '          '
    $block = @(for ($index = $blockStart + 1; $index -lt $workflowLines.Count; $index++) {
        $line = $workflowLines[$index]
        if ($line.StartsWith($indent, [StringComparison]::Ordinal)) {
            $line.Substring($indent.Length)
        } elseif ($line.Trim().Length -eq 0) {
            ''
        } else {
            break
        }
    })
    if (-not ($block -join "`n").Trim()) { throw "The run block in $WorkflowPath is empty." }
    $block
}

function Invoke-WorkflowRunBlock {
    param([string]$Engine, [string]$Script, [string]$WorkingDirectory, [string]$StderrPath)

    Push-Location -LiteralPath $WorkingDirectory
    try {
        Invoke-NativeCheck $Engine @('-NoProfile', '-NonInteractive', '-File', $Script) $StderrPath
    } finally {
        Pop-Location
    }
}

function Test-GoInputs {
    param([string]$WorkflowPath, [string]$Engine, [string]$FixtureRoot, [string]$StderrPath)

    $script = Join-Path $FixtureRoot 'validate-go-inputs.ps1'
    $metadata = Join-Path $FixtureRoot 'go-inputs.txt'
    Set-Content -LiteralPath $script -Encoding UTF8 -Value @(
        Read-WorkflowRunBlock $WorkflowPath 'Validate Go version and runner'
    )
    $cases = @(
        @{ Go = '1.26.0'; Runner = 'ubuntu-24.04'; Event = 'push'; Attempt = '1'; Artifact = 'go-linux-amd64'; Exe = 'app' }
        @{ Go = '1.27.4'; Runner = 'windows-2025'; Event = 'pull_request'; Attempt = '2'; Artifact = 'go-windows-amd64-attempt-2'; Exe = 'app.exe' }
        @{ Go = '1.25.9'; Runner = 'ubuntu-24.04'; Event = 'push'; Error = 'go-version must be an exact Go release' }
        @{ Go = '1.27'; Runner = 'ubuntu-24.04'; Event = 'push'; Error = 'go-version must be an exact Go release' }
        @{ Go = '1.27.4-rc.1'; Runner = 'ubuntu-24.04'; Event = 'push'; Error = 'go-version must be an exact Go release' }
        @{ Go = '$(Write-Output sentinel)'; Runner = 'ubuntu-24.04'; Event = 'push'; Error = 'go-version must be an exact Go release' }
        @{ Go = '1.27.4'; Runner = 'self-hosted'; Event = 'push'; Error = 'runner must be ubuntu-24.04 or windows-2025' }
        @{ Go = '1.27.4'; Runner = 'ubuntu-24.04'; Event = 'pull_request_target'; Error = 'Unsupported caller event' }
    )
    $previous = @{}
    foreach ($name in 'REQUESTED_GO_VERSION', 'REQUESTED_RUNNER', 'GITHUB_EVENT_NAME', 'GITHUB_RUN_ATTEMPT', 'GITHUB_OUTPUT') {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        $env:GITHUB_OUTPUT = $metadata
        foreach ($case in $cases) {
            $env:REQUESTED_GO_VERSION = $case.Go
            $env:REQUESTED_RUNNER = $case.Runner
            $env:GITHUB_EVENT_NAME = $case.Event
            $env:GITHUB_RUN_ATTEMPT = $case['Attempt']
            Set-Content -LiteralPath $metadata -Value @() -Encoding UTF8
            $result = Invoke-WorkflowRunBlock $Engine $script $FixtureRoot $StderrPath
            $output = @(Get-Content -LiteralPath $metadata -Encoding UTF8)
            if ($case.ContainsKey('Error')) {
                if ($result.Status -ne 1 -or -not $result.Stderr.Contains($case.Error) -or $output.Count -ne 0) {
                    throw "Go input check failed to reject the fixture. $($result.Stderr)"
                }
            } elseif ($result.Status -ne 0 -or ($output -join ' ') -cne
                "runner=$($case.Runner) artifact-name=$($case.Artifact) executable=$($case.Exe)") {
                throw "Go input check produced incorrect metadata. Exit $($result.Status). $($output -join ' ') $($result.Stderr)"
            }
        }
    } finally {
        foreach ($name in $previous.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
    }
    Write-Output "Go workflow input and output metadata passed $($cases.Count) fixtures."
}

function Test-GoWorkflow {
    param([string]$WorkflowPath, [string]$GoExecutable, [string]$Engine, [string]$FixtureRoot, [string]$StderrPath)

    $stepScript = Join-Path $FixtureRoot 'Go workflow step.ps1'
    Set-Content -LiteralPath $stepScript -Encoding UTF8 -Value @(
        Read-WorkflowRunBlock $WorkflowPath 'Vet, test, and build the caller application'
    )
    $module = "module example.com/ci-go-fixture`n`ngo 1.26.0"
    $mainSource = @'
package main

import "fmt"

func message() string { return "go fixture binary" }

func main() { fmt.Println(message()) }
'@
    $passingTest = @'
package main

import "testing"

func TestMessage(t *testing.T) {
    if got := message(); got != "go fixture binary" {
        t.Fatalf("message() = %q", got)
    }
}
'@
    $failingTest = @'
package main

import "testing"

func TestFailure(t *testing.T) { t.Fatal("go-test-fixture-failure") }
'@
    $cases = @(
        @{ Name = 'success'; Module = $module; Source = $mainSource; Test = $passingTest; Diagnostic = ''; ToolOutput = '' }
        @{ Name = 'missing module'; Module = ''; Source = $mainSource; Test = ''; Diagnostic = 'Required caller root go.mod is missing.'; ToolOutput = '' }
        @{ Name = 'non-main package'; Module = $module; Source = 'package fixture'; Test = ''; Diagnostic = 'The caller root Go package must be main.'; ToolOutput = '' }
        @{ Name = 'vet failure'; Module = $module; Source = $mainSource.Replace('fmt.Println(message())', 'fmt.Printf("%d", message())'); Test = ''; Diagnostic = 'go vet failed.'; ToolOutput = 'wrong type string' }
        @{ Name = 'test failure'; Module = $module; Source = $mainSource; Test = $failingTest; Diagnostic = 'go test failed.'; ToolOutput = 'go-test-fixture-failure' }
        @{ Name = 'build failure'; Module = $module; Source = 'package main'; Test = ''; Diagnostic = 'go build failed.'; ToolOutput = 'function main is undeclared' }
    )

    $previousEnvironment = @{}
    foreach ($name in 'RUNNER_TEMP', 'GOWORK', 'GOTOOLCHAIN') {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        $env:GOWORK = 'off'
        $env:GOTOOLCHAIN = 'local'
        $goSuffix = Invoke-NativeCheck $GoExecutable @('env', 'GOEXE') $StderrPath
        if ($goSuffix.Status -ne 0) { throw "go env GOEXE failed in the test harness.`n$($goSuffix.Stderr)" }

        foreach ($case in $cases) {
            $caseRoot = Join-Path $FixtureRoot ('Go caller ' + $case.Name)
            $caller = Join-Path $caseRoot 'checkout'
            $env:RUNNER_TEMP = Join-Path $caseRoot 'runner temp'
            New-Item -ItemType Directory -Path $caller, $env:RUNNER_TEMP -Force | Out-Null
            if ($case.Module) { Set-Content -LiteralPath (Join-Path $caller 'go.mod') -Encoding ASCII -Value $case.Module }
            if ($case.Test) { Set-Content -LiteralPath (Join-Path $caller 'main_test.go') -Encoding ASCII -Value $case.Test }
            Set-Content -LiteralPath (Join-Path $caller 'main.go') -Encoding ASCII -Value $case.Source

            $result = Invoke-WorkflowRunBlock $Engine $stepScript $caller $StderrPath
            $binary = Join-Path $env:RUNNER_TEMP "go-verification/app$($goSuffix.Stdout)"
            if ($case.Diagnostic) {
                $combinedOutput = $result.Stdout + "`n" + $result.Stderr
                if ($result.Status -ne 1 -or -not $result.Stderr.Contains($case.Diagnostic) -or
                        ($case.ToolOutput -and -not $combinedOutput.Contains($case.ToolOutput))) {
                    throw "Go workflow case '$($case.Name)' expected exit 1 and '$($case.Diagnostic)'; got exit $($result.Status).`n$combinedOutput"
                }
                if (Test-Path -LiteralPath $binary) {
                    throw "Go workflow case '$($case.Name)' left an application artifact after failure."
                }
            } else {
                if ($result.Status -ne 0 -or $result.Stderr -or $result.Stdout -notmatch '^ok\s+example\.com/ci-go-fixture' -or
                        -not (Test-Path -LiteralPath $binary -PathType Leaf)) {
                    throw "Go workflow did not pass its test and build the expected artifact. Exit $($result.Status).`n$($result.Stdout)`n$($result.Stderr)"
                }
                $artifact = Invoke-NativeCheck $binary @() $StderrPath
                if ($artifact.Status -ne 0 -or $artifact.Stdout -cne 'go fixture binary' -or $artifact.Stderr) {
                    throw "Go workflow artifact did not run successfully. Exit $($artifact.Status).`n$($artifact.Stdout)`n$($artifact.Stderr)"
                }
            }
            Write-Output "Reusable Go workflow run block passed the $($case.Name) fixture."
        }
    } finally {
        foreach ($name in $previousEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
        }
    }
}

$projectRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).ProviderPath
$workflowDirectory = Join-Path $projectRoot '.github/workflows'
$reusableWorkflow = Join-Path $workflowDirectory 'reusable-verify.yml'
$goWorkflow = Join-Path $workflowDirectory 'reusable-go.yml'
$goCommand = Get-Command go -CommandType Application -TotalCount 1 -ErrorAction SilentlyContinue
if (-not $goCommand) {
    throw 'Go is required on PATH to run the pinned workflow validator.'
}
$actionlintModule = 'github.com/rhysd/actionlint/cmd/actionlint@v1.7.12'
$scriptEngine = (Get-Process -Id $PID -ErrorAction Stop).Path

$workflowFiles = @(Get-ChildItem -LiteralPath $workflowDirectory -File |
    Where-Object { $_.Extension -in '.yml', '.yaml' } | Sort-Object Name)
if ($workflowFiles.Count -eq 0) { throw 'No workflow files found.' }

$fixtureRoot = Join-Path $projectRoot ('.verify-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $stderrPath = Join-Path $fixtureRoot 'command-stderr.log'
    $lintArguments = @('run', $actionlintModule, '-no-color') + $workflowFiles.FullName
    $lint = Invoke-NativeCheck $goCommand.Source $lintArguments $stderrPath
    if ($lint.Status -ne 0) {
        throw "actionlint failed with exit $($lint.Status).`n$($lint.Stdout)`n$($lint.Stderr)"
    }
    Write-Output "actionlint v1.7.12 validated $($workflowFiles.Count) workflow files."

    $invalidWorkflow = Join-Path $fixtureRoot 'invalid-workflow.yml'
    Set-Content -LiteralPath $invalidWorkflow -Encoding ASCII -Value @'
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    unexpected-fixture-key: true
    steps:
      - run: echo fixture
'@
    $badLint = Invoke-NativeCheck $goCommand.Source @('run', $actionlintModule, '-no-color', $invalidWorkflow) $stderrPath
    $badLintOutput = $badLint.Stdout + "`n" + $badLint.Stderr
    if ($badLint.Status -eq 0 -or $badLintOutput -notmatch 'unexpected-fixture-key') {
        throw "actionlint did not reject the deliberate invalid workflow. Exit $($badLint.Status).`n$badLintOutput"
    }
    Write-Output 'actionlint rejected the deliberate invalid workflow.'

    $stepScript = Join-Path $fixtureRoot 'workflow step.ps1'
    Set-Content -LiteralPath $stepScript -Encoding UTF8 -Value @(
        Read-WorkflowRunBlock $reusableWorkflow 'Verify the caller repository'
    )
    $successVerifier = @'
$callerRoot = Split-Path -Parent $PSScriptRoot
if ((Get-Location).Path -ne $callerRoot -or -not (Test-Path -LiteralPath 'caller-sentinel.txt' -PathType Leaf)) {
    throw 'fixture did not run in the caller workspace'
}
if ([Environment]::GetCommandLineArgs()[-1] -ne $PSCommandPath) {
    throw 'fixture did not run as a child process'
}
Write-Output 'fixture succeeded'
exit 0
'@
    $missingDiagnostic = 'Required verifier scripts/verify.ps1 is missing'
    $cases = @(
        @{ Name = 'success'; Script = $successVerifier; Status = 0; Stdout = 'fixture succeeded'; Diagnostic = '' }
        @{ Name = 'failure'; Script = "Write-Output 'fixture failed'`nexit 37"; Status = 37; Stdout = 'fixture failed'; Diagnostic = '' }
        @{ Name = 'thrown error'; Script = "throw 'fixture threw an error'"; Status = 1; Stdout = ''; Diagnostic = 'fixture threw an error' }
        @{ Name = 'missing script'; Script = $null; Status = 1; Stdout = ''; Diagnostic = $missingDiagnostic }
        @{ Name = 'directory at script path'; Script = $null; Status = 1; Stdout = ''; Diagnostic = $missingDiagnostic }
    )
    foreach ($case in $cases) {
        $caller = Join-Path $fixtureRoot ('caller ' + $case.Name)
        $callerScripts = Join-Path $caller 'scripts'
        New-Item -ItemType Directory -Path $callerScripts -Force | Out-Null
        $verifier = Join-Path $callerScripts 'verify.ps1'
        if ($null -ne $case.Script) {
            Set-Content -LiteralPath $verifier -Encoding UTF8 -Value $case.Script
        } elseif ($case.Name -eq 'directory at script path') {
            New-Item -ItemType Directory -Path $verifier | Out-Null
        }
        if ($case.Name -eq 'success') {
            Set-Content -LiteralPath (Join-Path $caller 'caller-sentinel.txt') -Value 'synthetic caller workspace'
        }

        $result = Invoke-WorkflowRunBlock $scriptEngine $stepScript $caller $stderrPath
        if ($result.Status -ne $case.Status -or $result.Stdout -cne $case.Stdout) {
            throw "Workflow case '$($case.Name)' returned exit $($result.Status) and stdout '$($result.Stdout)'. Expected exit $($case.Status) and stdout '$($case.Stdout)'.`n$($result.Stderr)"
        }
        if ($case.Diagnostic -and -not $result.Stderr.Contains($case.Diagnostic)) {
            throw "Workflow case '$($case.Name)' did not report '$($case.Diagnostic)'.`n$($result.Stderr)"
        }
        if (-not $case.Diagnostic -and $result.Stderr) {
            throw "Workflow case '$($case.Name)' wrote unexpected stderr.`n$($result.Stderr)"
        }
        Write-Output "Reusable workflow run block passed the $($case.Name) fixture."
    }
    Test-GoInputs $goWorkflow $scriptEngine $fixtureRoot $stderrPath
    Test-GoWorkflow $goWorkflow $goCommand.Source $scriptEngine $fixtureRoot $stderrPath
} finally {
    $resolvedFixtureRoot = (Resolve-Path -LiteralPath $fixtureRoot).ProviderPath
    if ([IO.Path]::GetDirectoryName($resolvedFixtureRoot) -ne $projectRoot) {
        throw 'Refusing to remove a verification fixture outside the project directory.'
    }
    Remove-Item -LiteralPath $resolvedFixtureRoot -Recurse -Force
}
