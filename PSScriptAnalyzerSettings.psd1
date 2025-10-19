@{
  Rules = @{
    PSAvoidAssignmentToAutomaticVariable = @{ Enable = $true }
    PSAvoidUsingEmptyCatchBlock          = @{ Enable = $true }
    PSUseApprovedVerbs                   = @{ Enable = $false }  # we allow Log-Debug/Run-VBox naming
    PSUseConsistentIndentation           = @{ Enable = $false }
    PSUseConsistentWhitespace            = @{ Enable = $false }
    PSReviewUnusedParameter              = @{ Enable = $false }
    PSAvoidUsingWriteHost                = @{ Enable = $false }
    PSUseShouldProcessForStateChangingFunctions = @{ Enable = $false }
    PSUseSingularNouns                   = @{ Enable = $false }
  }
}