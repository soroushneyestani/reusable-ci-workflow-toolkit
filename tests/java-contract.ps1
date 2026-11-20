[CmdletBinding()]
param([switch]$SkipMaven)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-StepScript {
    param([string]$Workflow, [string]$Name)

    $steps = $Workflow -split '(?m)^      - (?:name: |uses: )'
    $named = @($steps | Where-Object { $_.StartsWith("$Name`n", [StringComparison]::Ordinal) })
    if ($named.Count -ne 1) { throw "Expected one workflow step named '$Name'." }
    $body = [regex]::Match($named[0], '(?m)^        run: \|\n(?<body>(?:^ {10}.*\n|^\n)+)').Groups['body'].Value
    if (-not $body.Trim()) { throw "Missing literal run block for '$Name'." }
    [scriptblock]::Create(($body -creplace '(?m)^ {10}', ''))
}

function Assert-StepFailure {
    param([scriptblock]$Step, [string]$Diagnostic, [string]$MavenLog = '')

    $log = [Collections.Generic.List[string]]::new()
    try {
        & $Step 2>&1 | ForEach-Object { $log.Add([string]$_) }
    } catch {
        if ($_.Exception.Message -cne $Diagnostic -or
                ($MavenLog -and ($log -join "`n") -notmatch $MavenLog)) {
            throw "Expected '$Diagnostic' and Maven log pattern '$MavenLog'.`n$($log -join "`n")`n$_"
        }
        return
    }
    throw "Expected '$Diagnostic', but the workflow step succeeded."
}

$project = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).ProviderPath
$workflowPath = Join-Path $project '.github/workflows/reusable-java.yml'
$workflow = (Get-Content -LiteralPath $workflowPath -Raw -Encoding utf8).Replace("`r`n", "`n")
$invocation = Get-StepScript $workflow 'Validate Java workflow invocation'
$configuration = Get-StepScript $workflow 'Validate caller Maven configuration'
$build = Get-StepScript $workflow 'Verify and stage the Java application'
$source = Join-Path $project 'fixtures/java-caller'
$binPath = Join-Path $project 'bin'
if (-not (Test-Path -LiteralPath $binPath -PathType Container)) {
    New-Item -ItemType Directory -Path $binPath | Out-Null
}
$bin = Get-Item -LiteralPath $binPath
if ($bin.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'The test bin directory must not be a link.' }
$scratch = Join-Path $bin.FullName ('java-contract-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$oldEnvironment = @{}
foreach ($name in 'GITHUB_EVENT_NAME', 'REQUESTED_JAVA_VERSION', 'RUNNER_TEMP') {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    Push-Location -LiteralPath $scratch
    try {
        $env:REQUESTED_JAVA_VERSION = '21'
        foreach ($callerEvent in 'push', 'pull_request', 'workflow_dispatch') {
            $env:GITHUB_EVENT_NAME = $callerEvent
            & $invocation
        }
        foreach ($callerEvent in 'pull_request_target', 'workflow_run', 'schedule') {
            $env:GITHUB_EVENT_NAME = $callerEvent
            Assert-StepFailure $invocation 'Use only push, pull_request, or workflow_dispatch to run this workflow.'
        }
        $env:GITHUB_EVENT_NAME = 'push'
        foreach ($version in '', '17', '21.0.1', 'latest', '21; invalid') {
            $env:REQUESTED_JAVA_VERSION = $version
            Assert-StepFailure $invocation 'java-version must be 21.'
        }

        Assert-StepFailure $configuration 'A regular caller root pom.xml is required.'
        New-Item -ItemType Directory -Path 'pom.xml' | Out-Null
        Assert-StepFailure $configuration 'A regular caller root pom.xml is required.'
        Write-Output 'Reusable Java workflow passed invocation and Maven configuration fixtures.'
    } finally {
        Pop-Location
    }

    if ($SkipMaven) {
        Write-Output 'Reusable Java workflow Maven build fixtures not run (-SkipMaven).'
        return
    }

    Get-Command mvn, java -CommandType Application -ErrorAction Stop | Out-Null
    $mavenCache = Join-Path $bin.FullName 'java-contract-maven-cache'
    $cases = @(
        @{ Name = 'success'; File = ''; Original = ''; Replacement = ''; Error = ''; Evidence = '' }
        @{ Name = 'test failure'; File = 'src/test/java/example/ci/MainTest.java'; Original = 'hello from the Java caller'; Replacement = 'expected synthetic test failure'; Error = 'Maven clean verify failed.'; Evidence = 'expected synthetic test failure' }
        @{ Name = 'lint failure'; File = 'src/main/java/example/ci/Main.java'; Original = '  static String greeting()'; Replacement = "`tstatic String greeting()"; Error = 'Maven clean verify failed.'; Evidence = 'FileTabCharacter' }
        @{ Name = 'missing jar'; File = 'pom.xml'; Original = '<finalName>app</finalName>'; Replacement = '<finalName>other</finalName>'; Error = 'Maven must produce a regular target/app.jar.'; Evidence = 'BUILD SUCCESS' }
    )
    foreach ($case in $cases) {
        $root = Join-Path $scratch $case.Name
        $caller = Join-Path $root 'caller checkout'
        $mavenConfig = Join-Path $caller '.mvn'
        $env:RUNNER_TEMP = Join-Path $root 'runner temp'
        New-Item -ItemType Directory -Path $mavenConfig, $env:RUNNER_TEMP | Out-Null
        Copy-Item -LiteralPath (Join-Path $source 'pom.xml') -Destination $caller
        Copy-Item -LiteralPath (Join-Path $source 'src') -Destination $caller -Recurse
        $utf8 = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText((Join-Path $mavenConfig 'maven.config'), "-Dmaven.repo.local=$mavenCache`n", $utf8)
        if ($case.File) {
            $path = Join-Path $caller $case.File
            $content = [IO.File]::ReadAllText($path)
            if (-not $content.Contains($case.Original)) { throw "Test fixture text for '$($case.Name)' is missing." }
            [IO.File]::WriteAllText($path, $content.Replace($case.Original, $case.Replacement), $utf8)
        }
        $staged = Join-Path $env:RUNNER_TEMP 'java-verification/app.jar'
        Push-Location -LiteralPath $caller
        try {
            & $configuration
            if ($case.Error) {
                Assert-StepFailure $build $case.Error $case.Evidence
                if (Test-Path -LiteralPath $staged) { throw 'Failed Maven verification staged a JAR.' }
            } else {
                & $build | Out-Null
                if ((Get-FileHash -LiteralPath $staged).Hash -cne (Get-FileHash -LiteralPath 'target/app.jar').Hash) {
                    throw 'The staged JAR differs from the Maven output.'
                }
                $message = & java -jar $staged
                if ($LASTEXITCODE -ne 0 -or $message -cne 'hello from the Java caller') { throw 'The staged JAR did not execute as expected.' }
            }
        } finally {
            Pop-Location
        }
        Write-Output "Reusable Java workflow passed the $($case.Name) fixture."
    }
} finally {
    foreach ($name in $oldEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], 'Process')
    }
    $resolved = (Resolve-Path -LiteralPath $scratch).ProviderPath
    if ([IO.Path]::GetDirectoryName($resolved) -ne $bin.FullName) { throw 'Refusing to remove a fixture outside the project bin directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
