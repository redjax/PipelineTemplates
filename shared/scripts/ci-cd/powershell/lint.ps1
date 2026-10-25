[CmdletBinding()]
param(
    [string] $Root = (Get-Location).Path,
    [string[]] $Paths = @('.'),
    [string[]] $ExcludePaths = @(),
    [string] $SettingsFile = '',
    [ValidateSet('Error', 'Warning', 'Information')]
    [string[]] $Severity = @('Error', 'Warning'),
    [bool] $FailOnFindings = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-AnnotationText {
    param([string] $Text)

    return $Text.Replace('%', '%25').
    Replace("`r", '%0D').
    Replace("`n", '%0A')
}

function Write-Summary {
    param([string] $Text)

    if ($env:GITHUB_STEP_SUMMARY) {
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY `
            -Value $Text -Encoding utf8
    }
}

try {
    $Root = (Resolve-Path -LiteralPath $Root).Path

    Import-Module PSScriptAnalyzer -ErrorAction Stop

    # This script lives at:
    # <templates>/shared/scripts/ci-cd/powershell/lint.ps1
    $templatesRoot = [IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot '../../../..')
    )

    if ($SettingsFile) {
        if ([IO.Path]::IsPathRooted($SettingsFile)) {
            throw 'SettingsFile must be relative to the consuming repository.'
        }

        $selectedSettings = [IO.Path]::GetFullPath(
            (Join-Path $Root $SettingsFile)
        )

        $relativeSettings = [IO.Path]::GetRelativePath(
            $Root,
            $selectedSettings
        )

        if (
            $relativeSettings -eq '..' -or
            $relativeSettings.StartsWith("../") -or
            $relativeSettings.StartsWith('..\')
        ) {
            throw 'SettingsFile must remain inside the consuming repository.'
        }

        if (-not (Test-Path -LiteralPath $selectedSettings -PathType Leaf)) {
            throw "Requested settings file does not exist: $selectedSettings"
        }
    }
    elseif (
        Test-Path -LiteralPath (
            Join-Path $Root 'PSScriptAnalyzerSettings.psd1'
        ) -PathType Leaf
    ) {
        $selectedSettings = Join-Path $Root 'PSScriptAnalyzerSettings.psd1'
    }
    else {
        $selectedSettings = Join-Path $templatesRoot `
            'config/powershell/PSScriptAnalyzerSettings.psd1'
    }

    if (-not (Test-Path -LiteralPath $selectedSettings -PathType Leaf)) {
        throw "Settings file does not exist: $selectedSettings"
    }

    # Validate data-file syntax before starting the scan.
    $null = Import-PowerShellDataFile -LiteralPath $selectedSettings

    $Paths = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($Paths.Count -eq 0) {
        $Paths = @('.')
    }

    Push-Location $Root
    try {
        $tracked = @(
            & git -c core.quotepath=false ls-files -- @Paths
        )

        if ($LASTEXITCODE -ne 0) {
            throw "git ls-files failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    $files = @(
        foreach ($relative in $tracked) {
            if ([IO.Path]::GetExtension($relative) -notin @(
                    '.ps1', '.psm1', '.psd1'
                )) {
                continue
            }

            $excluded = $false

            foreach ($pattern in $ExcludePaths) {
                if (
                    -not [string]::IsNullOrWhiteSpace($pattern) -and
                    $relative -like $pattern
                ) {
                    $excluded = $true
                    break
                }
            }

            if (
                -not $excluded -and
                (Test-Path -LiteralPath (Join-Path $Root $relative) -PathType Leaf)
            ) {
                $relative
            }
        }
    ) | Sort-Object -Unique

    $files = @($files)

    Write-Host "Lint settings: $selectedSettings"
    Write-Host "Selected PowerShell files: $($files.Count)"
    Write-Host "Severities: $($Severity -join ', ')"
    Write-Host "Fail on findings: $FailOnFindings"

    $findingCount = 0

    foreach ($relative in $files) {
        $absolute = Join-Path $Root $relative

        Write-Host "Analyzing: $relative"

        $findings = @(
            Invoke-ScriptAnalyzer `
                -Path $absolute `
                -Settings $selectedSettings `
                -Severity $Severity `
                -ErrorAction Stop
        )

        foreach ($finding in $findings) {
            $findingCount++

            $line = [Math]::Max(1, [int] $finding.Line)
            $column = 1

            if ($null -ne $finding.Extent) {
                $column = [Math]::Max(
                    1,
                    [int] $finding.Extent.StartColumnNumber
                )
            }

            $message = (
                '[{0}] {1}: {2}' -f
                $finding.Severity,
                $finding.RuleName,
                $finding.Message
            )

            Write-Host "${relative}:${line}:${column}: $message"

            if ($env:GITHUB_ACTIONS -eq 'true') {
                $annotationLevel = 'warning'

                if ($FailOnFindings) {
                    $annotationLevel = 'error'
                }

                # Checkout is under "source" in the reusable workflow.
                $annotationFile = [IO.Path]::GetRelativePath(
                    $env:GITHUB_WORKSPACE,
                    $absolute
                ).Replace('\', '/')

                $annotationFile = (
                    ConvertTo-AnnotationText $annotationFile
                ).Replace(',', '%2C').Replace(':', '%3A')

                $annotationMessage = ConvertTo-AnnotationText $message

                Write-Host (
                    "::$annotationLevel file=$annotationFile," +
                    "line=$line,col=$column::$annotationMessage"
                )
            }
        }
    }

    if ($files.Count -eq 0) {
        Write-Host 'No matching tracked PowerShell files.'
    }

    Write-Host "Lint findings: $findingCount"

    Write-Summary @"
## PowerShell lint

| Item | Value |
|---|---|
| Files checked | $($files.Count) |
| Findings | $findingCount |
| Fail on findings | $FailOnFindings |

Settings: ``$selectedSettings``
"@

    if ($findingCount -gt 0 -and $FailOnFindings) {
        exit 1
    }

    exit 0
}
catch {
    $message = ConvertTo-AnnotationText $_.Exception.Message

    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Host "::error::PowerShell lint execution failed: $message"
    }
    else {
        Write-Host "PowerShell lint execution failed: $($_.Exception.Message)"
    }

    Write-Summary "PowerShell lint execution failed: $message"
    exit 2
}