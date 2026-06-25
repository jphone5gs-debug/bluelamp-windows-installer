@{
    Severity     = @('Error', 'Warning')
    # 本プロジェクトはフロントUIなし・PowerShellコンソール出力のみが要件(requirements.md)。
    # 色分けされた進捗表示が成功指標の一つのため、Write-Hostの使用を意図的に許可する。
    # install.ps1は`irm | iex`で文字列として実行されるため、先頭にBOMがあるとPowerShellの
    # パーサーが[CmdletBinding()]/param()を認識できずParserErrorになる(実機テストで確認済み)。
    # よってBOM強制ルールはプロジェクト全体で無効化する(他ファイルは手動でBOM付きを維持)
    ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseBOMForUnicodeEncodedFile')
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
