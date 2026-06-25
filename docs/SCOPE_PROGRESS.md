# 開発進捗（SCOPE_PROGRESS）

## アーキ構成

- 確定アーキ: 決定論スクリプト型（#6相当・フロントUI/DB/バックエンドサーバーなし・RPA）
- 操作者: 本人（複数の自分専用Windows PC）
- AI本体(プロンプトY): なし
- MCP: なし
- 自社DB: なし
- フロントUI: なし
- 動的変数: なし
- 配布: マイ専用（GitHub公開リポジトリ `jphone5gs-debug/bluelamp-windows-installer`）

詳細は `docs/requirements.md` を参照。

## 実装計画

### 開発フェーズ

| Phase | 名称 | 担当 | 状態 |
|-------|------|------|------|
| 1 | 要件定義 | Agent 1 | [x] |
| 2 | Git管理（GitHubリポジトリ作成） | Agent 2 | [x] `jphone5gs-debug/bluelamp-windows-installer`として作成・push完了 |
| 3 | フロントエンド基盤 | Agent 3 | [ ] スキップ(UIなし) |
| 4 | ページ実装 | Agent 4 | [ ] スキップ(UIなし) |
| 5 | 環境構築（検証用WSL/VM環境） | Agent 5 | [ ] 未実施(実機Windows/WSL環境が無いサンドボックスのため) |
| 6 | バックエンド計画 | Agent 6 | [ ] スキップ(バックエンドサーバーなし) |
| 7 | エージェント構築 | Agent 7 | [ ] スキップ(AI本体Yなし) |
| 8 | バックエンド実装 → **スクリプト本体実装** | Agent 8 | [x] install.ps1 + scripts/ps(6) + scripts/wsl(5) 実装完了 |
| 9 | フロントエンド実装(API統合) | Agent 9 | [ ] スキップ(UIなし) |
| 10 | E2Eテスト → **実機/VM導入テスト** | Agent 10 | [ ] 未実施。実機PCでの確認が必須(下記「未検証事項」参照) |
| 11 | ローカル動作確認 | Agent 11 | [~] 静的検証(shellcheck/PSScriptAnalyzer)のみ実施。動作確認は実機PCで必要 |
| 12 | デプロイ → **GitHub公開** | Agent 12 | [ ] |

## スクリプトモジュール管理表

| ID | モジュール名 | 種別 | 着手 | 完了 |
|----|------------|------|------|------|
| S-001 | Test-WSLStatus | PowerShell関数 | [x] | [x] (静的検証のみ。実機未確認) |
| S-002 | Enable-WSLFeature | PowerShell関数 | [x] | [x] (静的検証のみ。実機未確認) |
| S-003 | Register-ResumeTask | PowerShell関数 | [x] | [x] (静的検証のみ。実機未確認) |
| S-004 | Import-UbuntuDistro | PowerShell関数 | [x] | [x] (静的検証のみ。実機未確認) |
| S-005 | install_node_in_wsl | bash | [x] | [x] (shellcheckのみ。実機未確認) |
| S-006 | install_claude_code_in_wsl | bash | [x] | [x] (shellcheckのみ。実機未確認) |
| S-007 | install_bluelamp_in_wsl | bash | [x] | [x] (shellcheckのみ。実機未確認) |
| S-008 | invoke_claude_code_login | bash（対話） | [x] | [x] (shellcheckのみ。実機未確認) |
| S-009 | invoke_bluelamp_login | bash（対話） | [x] | [x] (shellcheckのみ。実機未確認) |
| S-010 | Show-CompletionGuide | PowerShell関数 | [x] | [x] (静的検証のみ。実機未確認) |

## 未検証事項（実機PCでの確認が必須）

このサンドボックスはLinux環境のみでWindows/WSLの実機が無いため、以下は静的検証(shellcheck・PSScriptAnalyzer・bash構文チェック)のみで、実際の動作は未確認:

1. `wsl --import`によるUbuntu rootfs(noble)の実際のインポート挙動
2. `adduser --disabled-password` + `/etc/wsl.conf`の`[user] default=`設定が`wsl --terminate`後に実際に既定ユーザーとして反映されるか
3. Windows機能有効化→再起動→タスクスケジューラ(`ONLOGON`)による自動再開の一連の流れ
4. nvm v0.40.1のインストールと`BASH_ENV`経由のnvm/npmパス解決
5. Anthropic公式インストーラーによるClaude Code CLI導入(最小構成のUbuntu rootfs上での挙動)
6. `claude`実行時のOAuthログインフローが、stdin EOFを受けて想定通り終了するか(invoke-claude-login.sh)
7. `bluelamp1`実行時のBlueLampポータルログインフローが同様に終了するか(invoke-bluelamp-login.sh)
8. 30分以内・6アクション以内という成功指標の実測、および複数PCでの再現性

次のステップ(Agent 5またはAgent 10相当)で、実機Windows PCまたはWindows VM上での導入テストが必要。

## 外部アカウント準備状況

| サービス | アカウント | 備考 |
|---------|-----------|------|
| GitHub | [x] | ユーザー名 `jphone5gs-debug`（Phase2実施時に`eva001`では作成不可と判明し変更） |
| Claude.ai/Anthropic | [x] | 既存サブスクリプション、各PCで初回ログインのみ |
| BlueLampポータル | [x] | 既存アカウント、各PCで初回ログインのみ |

## メモ

このプロジェクトは「Windows PCにBlueLampを全自動導入するPowerShellインストーラー」を作るための要件定義。
詳細は `docs/requirements.md` を参照。
