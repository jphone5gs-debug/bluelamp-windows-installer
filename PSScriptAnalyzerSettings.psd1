@{
    Severity     = @('Error', 'Warning')
    # 本プロジェクトはフロントUIなし・PowerShellコンソール出力のみが要件(requirements.md)。
    # 色分けされた進捗表示が成功指標の一つのため、Write-Hostの使用を意図的に許可する
    ExcludeRules = @('PSAvoidUsingWriteHost')
    Rules        = @{
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
