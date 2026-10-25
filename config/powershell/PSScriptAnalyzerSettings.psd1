@{
    ## Report correctness and maintainability findings.
    Severity     = @(
        'Error'
        'Warning'
    )

    ## Formatting is handled separately by FormatterSettings.psd1.
    ExcludeRules = @(
        'PSPlaceOpenBrace'
        'PSPlaceCloseBrace'
        'PSUseConsistentWhitespace'
        'PSUseConsistentIndentation'
        'PSAlignAssignmentStatement'
        'PSUseCorrectCasing'
    )
}