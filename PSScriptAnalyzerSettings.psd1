@{
  Rules = @{
    PSAvoidAssignmentToAutomaticVariable           = @{ Enable = $true }
    PSAvoidUsingEmptyCatchBlock                    = @{ Enable = $true }
    PSReviewUnusedParameter                        = @{ Enable = $false }
    PSAvoidUsingWriteHost                          = @{ Enable = $false }
    PSUseApprovedVerbs                             = @{ Enable = $false }
    PSUseConsistentIndentation                     = @{ Enable = $false }
    PSUseConsistentWhitespace                      = @{ Enable = $false }
    PSUseShouldProcessForStateChangingFunctions    = @{ Enable = $false }
    PSUseSingularNouns                             = @{ Enable = $false }
  }
}