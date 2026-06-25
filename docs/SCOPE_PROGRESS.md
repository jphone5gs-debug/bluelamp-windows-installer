# 開発進捗（SCOPE_PROGRESS）

## アーキ構成

- 確定アーキ: 決定論スクリプト型（#6相当・フロントUI/DB/バックエンドサーバーなし・RPA）
- 操作者: 本人（複数の自分専用Windows PC）
- AI本体(プロンプトY): なし
- MCP: なし
- 自社DB: なし
- フロントUI: なし
- 動的変数: なし
- 配布: マイ専用（GitHub公開リポジトリ `eva001/bluelamp-windows-installer`）

詳細は `docs/requirements.md` を参照。

## 実装計画

### 開発フェーズ

| Phase | 名称 | 担当 | 状態 |
|-------|------|------|------|
| 1 | 要件定義 | Agent 1 | [x] |
| 2 | Git管理（GitHubリポジトリ作成） | Agent 2 | [ ] |
| 3 | フロントエンド基盤 | Agent 3 | [ ] スキップ(UIなし) |
| 4 | ページ実装 | Agent 4 | [ ] スキップ(UIなし) |
| 5 | 環境構築（検証用WSL/VM環境） | Agent 5 | [ ] |
| 6 | バックエンド計画 | Agent 6 | [ ] スキップ(バックエンドサーバーなし) |
| 7 | エージェント構築 | Agent 7 | [ ] スキップ(AI本体Yなし) |
| 8 | バックエンド実装 → **スクリプト本体実装** | Agent 8 | [ ] |
| 9 | フロントエンド実装(API統合) | Agent 9 | [ ] スキップ(UIなし) |
| 10 | E2Eテスト → **実機/VM導入テスト** | Agent 10 | [ ] |
| 11 | ローカル動作確認 | Agent 11 | [ ] |
| 12 | デプロイ → **GitHub公開** | Agent 12 | [ ] |

## スクリプトモジュール管理表

| ID | モジュール名 | 種別 | 着手 | 完了 |
|----|------------|------|------|------|
| S-001 | Test-WSLStatus | PowerShell関数 | [ ] | [ ] |
| S-002 | Enable-WSLFeature | PowerShell関数 | [ ] | [ ] |
| S-003 | Register-ResumeTask | PowerShell関数 | [ ] | [ ] |
| S-004 | Import-UbuntuDistro | PowerShell関数 | [ ] | [ ] |
| S-005 | Install-NodeInWSL | bash | [ ] | [ ] |
| S-006 | Install-ClaudeCodeInWSL | bash | [ ] | [ ] |
| S-007 | Install-BlueLampInWSL | bash | [ ] | [ ] |
| S-008 | Invoke-ClaudeCodeLogin | bash（対話） | [ ] | [ ] |
| S-009 | Invoke-BlueLampLogin | bash（対話） | [ ] | [ ] |
| S-010 | Show-CompletionGuide | PowerShell関数 | [ ] | [ ] |

## 外部アカウント準備状況

| サービス | アカウント | 備考 |
|---------|-----------|------|
| GitHub | [x] | ユーザー名 `eva001`（確認済み） |
| Claude.ai/Anthropic | [x] | 既存サブスクリプション、各PCで初回ログインのみ |
| BlueLampポータル | [x] | 既存アカウント、各PCで初回ログインのみ |

## メモ

このプロジェクトは「Windows PCにBlueLampを全自動導入するPowerShellインストーラー」を作るための要件定義。
詳細は `docs/requirements.md` を参照。
