@{
    ## Report correctness and maintainability findings.
    Severity     = @(
        'Error'
        'Warning'
    )

    ## Formatting is handled separately by FormatterSettings.psd1.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSUseSingularNouns'
        ## I generally target PowerShell 7 and use UTF-8 without BOM.
        'PSUseBOMForUnicodeEncodedFile'

        'PSPlaceOpenBrace'
        'PSPlaceCloseBrace'
        'PSUseConsistentWhitespace'
        'PSUseConsistentIndentation'
        'PSAlignAssignmentStatement'
        'PSUseCorrectCasing'
    )
}