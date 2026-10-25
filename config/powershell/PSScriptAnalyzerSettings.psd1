@{
    ## Report correctness and maintainability findings.
    Severity     = @(
        'Error'
        'Warning'
    )

    ## Formatting is handled separately by FormatterSettings.psd1.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSPlaceOpenBrace'
        'PSPlaceCloseBrace'
        'PSUseConsistentWhitespace'
        'PSUseConsistentIndentation'
        'PSAlignAssignmentStatement'
        'PSUseCorrectCasing'
    )
}