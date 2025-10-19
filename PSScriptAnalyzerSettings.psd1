@{
  Rules = @{
    PSUseConsistentIndentation            = @{ Enable = $true; IndentationSize = 2; Kind = 'space' }
    PSUseConsistentWhitespace             = @{ Enable = $true }
    PSUseBOMForUnicodeEncodedFile         = @{ Enable = $true }
    PSAvoidUsingWriteHost                 = @{ Enable = $false }   # we use it for debug, controlled
    PSUseShouldProcessForStateChangingFunctions = @{ Enable = $false }
  }
}