[CmdletBinding()]
param(
    [string] $Root = (Get-Location).Path,
    [string[]] $Paths = @('.'),
    [string[]] $ExcludePaths = @(),
    [string] $SettingsFile = '',
    [bool] $Fix = $false,
    [bool] $FailOnFindings = $true,
    [string] $PatchFile = ''
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

function Read-ScriptText {
    param([string] $Path)

    # Reject invalid UTF-8 rather than silently replacing characters.
    $defaultEncoding = [Text.UTF8Encoding]::new($false, $true)

    $reader = [IO.StreamReader]::new(
        $Path,
        $defaultEncoding,
        $true
    )

    try {
        $text = $reader.ReadToEnd()
        $encoding = $reader.CurrentEncoding
    }
    finally {
        $reader.Dispose()
    }

    $newline = "`n"
    if ($text.Contains("`r`n")) {
        $newline = "`r`n"
    }

    return @{
        Text     = $text
        Encoding = $encoding
        Newline  = $newline
    }
}

function Get-FormattedText {
    param(
        [string] $Text,
        [string] $Settings,
        [string] $Newline
    )

    $formatted = Invoke-Formatter `
        -ScriptDefinition $Text `
        -Settings $Settings `
        -ErrorAction Stop

    return [regex]::Replace(
        $formatted,
        "\r\n|\r|\n",
        $Newline
    )
}

function Assert-ValidSyntax {
    param(
        [string] $Text,
        [string] $Name
    )

    $tokens = $null
    $parseErrors = $null

    $null = [Management.Automation.Language.Parser]::ParseInput(
        $Text,
        [ref] $tokens,
        [ref] $parseErrors
    )

    if (@($parseErrors).Count -gt 0) {
        $messages = $parseErrors | ForEach-Object {
            "line $($_.Extent.StartLineNumber): $($_.Message)"
        }

        throw "Cannot format ${Name}: $($messages -join '; ')"
    }
}

function Show-FormattingDiff {
    param(
        [string] $OriginalPath,
        [string] $FormattedText,
        [Text.Encoding] $Encoding,
        [string] $RelativePath
    )

    $temporaryFile = [IO.Path]::GetTempFileName()

    try {
        [IO.File]::WriteAllText(
            $temporaryFile,
            $FormattedText,
            $Encoding
        )

        Write-Host "Formatting diff: $RelativePath"

        & git --no-pager diff `
            --no-index `
            --no-ext-diff `
            --no-color `
            -- $OriginalPath $temporaryFile | ForEach-Object {
            Write-Host $_
        }

        $diffExit = $LASTEXITCODE

        if ($diffExit -notin @(0, 1)) {
            throw "git diff failed with exit code $diffExit."
        }
    }
    finally {
        Remove-Item -LiteralPath $temporaryFile -Force `
            -ErrorAction SilentlyContinue
    }
}

try {
    $Root = (Resolve-Path -LiteralPath $Root).Path

    Import-Module PSScriptAnalyzer -ErrorAction Stop

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
            Join-Path $Root 'FormatterSettings.psd1'
        ) -PathType Leaf
    ) {
        $selectedSettings = Join-Path $Root 'FormatterSettings.psd1'
    }
    else {
        $selectedSettings = Join-Path $templatesRoot `
            'config/powershell/FormatterSettings.psd1'
    }

    if (-not (Test-Path -LiteralPath $selectedSettings -PathType Leaf)) {
        throw "Settings file does not exist: $selectedSettings"
    }

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
    $changedFiles = [Collections.Generic.List[string]]::new()

    Write-Host "Formatter settings: $selectedSettings"
    Write-Host "Selected PowerShell files: $($files.Count)"
    Write-Host "Fix: $Fix"
    Write-Host "Fail on findings: $FailOnFindings"

    foreach ($relative in $files) {
        $absolute = Join-Path $Root $relative
        $source = Read-ScriptText -Path $absolute

        Assert-ValidSyntax -Text $source.Text -Name $relative

        $formatted = Get-FormattedText `
            -Text $source.Text `
            -Settings $selectedSettings `
            -Newline $source.Newline

        if ($source.Text -ceq $formatted) {
            Write-Host "Formatted correctly: $relative"
            continue
        }

        $changedFiles.Add($relative)

        Show-FormattingDiff `
            -OriginalPath $absolute `
            -FormattedText $formatted `
            -Encoding $source.Encoding `
            -RelativePath $relative

        if ($env:GITHUB_ACTIONS -eq 'true') {
            $annotationLevel = 'warning'

            if ($FailOnFindings -and -not $Fix) {
                $annotationLevel = 'error'
            }

            $annotationFile = [IO.Path]::GetRelativePath(
                $env:GITHUB_WORKSPACE,
                $absolute
            ).Replace('\', '/')

            $annotationFile = (
                ConvertTo-AnnotationText $annotationFile
            ).Replace(',', '%2C').Replace(':', '%3A')

            Write-Host (
                "::$annotationLevel file=$annotationFile::" +
                'Formatting differences detected; see the diff in the log.'
            )
        }

        if ($Fix) {
            Assert-ValidSyntax -Text $formatted -Name $relative

            $secondPass = Get-FormattedText `
                -Text $formatted `
                -Settings $selectedSettings `
                -Newline $source.Newline

            if ($formatted -cne $secondPass) {
                throw "Formatter did not produce stable output for $relative."
            }

            [IO.File]::WriteAllText(
                $absolute,
                $formatted,
                $source.Encoding
            )

            Write-Host "Fixed: $relative"
        }
    }

    if ($files.Count -eq 0) {
        Write-Host 'No matching tracked PowerShell files.'
    }

    if ($Fix -and $changedFiles.Count -gt 0 -and $PatchFile) {
        $PatchFile = [IO.Path]::GetFullPath($PatchFile)
        $patchDirectory = Split-Path -Parent $PatchFile

        $null = New-Item -ItemType Directory `
            -Path $patchDirectory -Force

        # Let Git write the patch directly, preserving its patch encoding.
        Push-Location $Root
        try {
            $diffArguments = @(
                '--no-pager'
                'diff'
                '--no-ext-diff'
                '--binary'
                '--full-index'
                "--output=$PatchFile"
                '--'
            ) + $changedFiles.ToArray()

            & git @diffArguments

            if ($LASTEXITCODE -ne 0) {
                throw "Patch generation failed with exit code $LASTEXITCODE."
            }
        }
        finally {
            Pop-Location
        }

        Write-Host "Formatting patch created: $PatchFile"
    }

    Write-Host "Files requiring formatting: $($changedFiles.Count)"

    Write-Summary @"
## PowerShell formatting

| Item | Value |
|---|---|
| Files checked | $($files.Count) |
| Files requiring formatting | $($changedFiles.Count) |
| Fix enabled | $Fix |
| Fail on findings | $FailOnFindings |

Settings: ``$selectedSettings``

Fix mode changes files only in this job's workspace.
It does not commit or push changes.
"@

    if (
        $changedFiles.Count -gt 0 -and
        -not $Fix -and
        $FailOnFindings
    ) {
        exit 1
    }

    exit 0
}
catch {
    $message = ConvertTo-AnnotationText $_.Exception.Message

    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Host "::error::PowerShell formatting execution failed: $message"
    }
    else {
        Write-Host (
            "PowerShell formatting execution failed: " +
            $_.Exception.Message
        )
    }

    Write-Summary "PowerShell formatting execution failed: $message"
    exit 2
}