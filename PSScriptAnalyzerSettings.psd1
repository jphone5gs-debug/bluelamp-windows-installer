@{
    Severity = @('Error', 'Warning')
    Rules    = @{
        PSAvoidUsingPositionalParameters = @{ Enabled = $true }
        PSUseConsistentIndentation       = @{ Enabled = $true; IndentationSize = 4 }
        PSUseConsistentWhitespace        = @{ Enabled = $true }
        PSAvoidGlobalVars                = @{ Enabled = $true }
        PSAvoidUsingCmdletAliases        = @{ Enabled = $true }
        PSProvideCommentHelp             = @{ Enabled = $false }
    }
    # 行長120文字 / 関数100行以下 / ファイル700行以下 / 複雑度10以下は
    # PSScriptAnalyzer標準ルールでは直接強制できないため、PRレビュー時に目視確認する
}
