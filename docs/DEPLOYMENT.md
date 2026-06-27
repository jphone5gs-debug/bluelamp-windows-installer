# デプロイ手順

## 前提条件

- GitHubリポジトリ `jphone5gs-debug/bluelamp-windows-installer` (main ブランチ) へのpush権限

## push前の静的検証

### shellcheck (bash/WSL)

```bash
shellcheck scripts/wsl/*.sh
```

### PSScriptAnalyzer (Windows PowerShell)

```powershell
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
$results = Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse
$results | Format-Table -AutoSize
```

エラーが0件であることを確認してからpushすること。

## push手順

```bash
git push origin main
```

push後、GitHub Actionsの `Lint` ワークフローが shellcheck + PSScriptAnalyzer を自動再検証する。

## 利用者向けインストーラーURL

```powershell
irm https://raw.githubusercontent.com/jphone5gs-debug/bluelamp-windows-installer/main/install.ps1 | iex
```

## インストールログの場所

インストール中の進捗・エラーは以下に保存されます（トラブルシューティング時に参照）:

```
%LOCALAPPDATA%\BlueLampInstaller\install.log
```
