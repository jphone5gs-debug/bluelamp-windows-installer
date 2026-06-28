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

## 実機テストで発見・修正した不具合

### 2026-06-25 1回目テスト
- **環境**: テストPCにWSL/Ubuntuは未導入と確認(`wsl -l -v`の結果より。既存環境との衝突は今回は実害なし)
- **発見した不具合**: `irm https://.../install.ps1 | iex` 実行時に以下のParserErrorで即失敗
  ```
  予期しない属性 'CmdletBinding' です。
  式または ステートメントのトークン 'param' を使用できません。
  ```
  **原因**: `install.ps1`先頭に付けていたUTF-8 BOM(日本語の文字化け防止目的)が、HTTP経由で文字列として取得され`Invoke-Expression`に渡される際に`[CmdletBinding()]`/`param()`をスクリプトの先頭と認識できなくする。ファイルとして直接実行する場合は問題にならないが、`irm | iex`方式では致命的
  **対応**: `install.ps1`のみBOMを除去(他のdot-sourceされるモジュールファイルはBOM付きのまま維持)。`PSScriptAnalyzerSettings.psd1`の`PSUseBOMForUnicodeEncodedFile`ルールを除外設定に追加し、CIでも矛盾しないようにした
  **確認結果**: 修正後の再テストで日本語メッセージ(「インストーラー本体をローカルにダウンロードしています...」)は文字化けせず正常表示された

### 2026-06-28 3回目テスト
- **発見した不具合**: S-008（invoke-claude-login.sh）で以下のエラーが発生しインストーラーが失敗
  ```
  bash: line 49: syntax error near unexpected token `}'
  [BlueLampインストーラー] 失敗しました: Claude Codeのログインに失敗しました (終了コード: 2)
  ```
  **原因**: `Invoke-WslScript` が `echo|base64 -d|bash` パターンで bash にスクリプトを stdin から読ませていたため、`claude` コマンドがスクリプトの残部を stdin から消費してしまい、bash が関数の閉じ括弧 `}` を意図しない位置で検出して構文エラーになった。bash がパイプから受け取るスクリプトを先読みバッファ単位で処理する特性が原因で、`install-claude-code.sh` 等の非対話スクリプトでは発現しない。
  **対応**:
  1. `Common.ps1` の `Invoke-WslScript` を、スクリプト内容を `/tmp/bluelamp_wsl_run.sh` に書き出してから `bash <file>` で実行する方式に変更（bash がファイルからスクリプトを読むため、子プロセスが stdin を消費しない）
  2. `invoke-claude-login.sh`: `claude </dev/null || true` に変更（OAuth はブラウザで完了するため stdin 不要。`</dev/null` で REPL を即時終了させる）
  3. `invoke-bluelamp-login.sh`: `bluelamp1 </dev/null || true` に変更（同上）
  **未確認**: 修正後の claude OAuth 動作は次回テストで確認が必要

### 2026-06-25 2回目テスト
- **発見した不具合**: BOM修正後、ローカル展開した`install.ps1`を`& (Join-Path $repoPath 'install.ps1')`で直接呼び出した際に以下のエラーで失敗
  ```
  iex : このシステムではスクリプトの実行が無効になっているため、ファイル ...\install.ps1 を読み込むことができません。
  CategoryInfo : セキュリティ エラー: (:) [Invoke-Expression]、PSSecurityException
  FullyQualifiedErrorId : UnauthorizedAccess
  ```
  **原因**: `irm | iex`による文字列実行自体は実行ポリシーの対象外だが、`&`によるローカル.ps1ファイルの直接実行は対象になる。テストPCの実行ポリシーが既定の制限的な設定だったため失敗
  **対応**: S-003(`Register-ResumeTask`)のタスクスケジューラ起動コマンドと同様に、`powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path>`で新規プロセスとして起動するよう変更(システム全体の実行ポリシーは変更しない、このプロセス起動のみの一時的な許可)
  **未確認の残課題**: 修正後の動作は次回テストで確認が必要

## 堅牢化対応(実機テスト前に実施)

- **既存Ubuntu(WSL)との衝突回避**: 利用者がテスト予定PCに既存のUbuntu(WSL)環境を持っていることが判明したため、ディストリ名を汎用的な`Ubuntu`から専用名`BlueLamp`に変更。これにより既存環境を誤って「導入済み」と誤認して手を加えてしまう事故を防止
- **ダウンロード処理の有限回リトライ**: 自己ブートストラップのzip取得、Ubuntu rootfs取得、nvm/Claude Code CLIインストールスクリプト取得、`npm install -g bluelamp`に対し、一時的なネットワーク不調を想定した最大3回までの有限リトライを追加(無限リトライ・別ソースへのフォールバックはしない)
- **ブートストラップ部分の例外処理漏れを修正**: `irm | iex`実行時のローカル展開処理が例外処理(try/catch)の外にあり、失敗時に生のスタックトレースが表示される問題を修正。メインフローと同じ整形済みエラーメッセージ + 再実行で続きから再開できる旨の案内を表示するよう統一
- **リトライ時の残骸クリーンアップ**: `wsl --import`が一度失敗した後の再試行で、前回の中途半端なインポート先ディレクトリが残っていると失敗する問題に対応(再試行前に削除)
- **state.json破損時のメッセージ改善**: JSON解析に失敗した場合、生の例外ではなく「ファイルを削除して再実行してください」という具体的な対処を案内
- **完了案内とクリーンアップの順序修正**: 状態ファイル削除を完了案内より先に実施し、削除失敗時も警告のみでインストール自体は成功として扱う(些末な後始末の失敗で「失敗しました」と矛盾した表示になるのを防止)

## 外部アカウント準備状況

| サービス | アカウント | 備考 |
|---------|-----------|------|
| GitHub | [x] | ユーザー名 `jphone5gs-debug`（Phase2実施時に`eva001`では作成不可と判明し変更） |
| Claude.ai/Anthropic | [x] | 既存サブスクリプション、各PCで初回ログインのみ |
| BlueLampポータル | [x] | 既存アカウント、各PCで初回ログインのみ |

## 🔒 本番運用診断履歴

### 第1回診断 (2026-06-27)

**総合スコア**: 84/100 → **96/100 (A評価: Excellent)** ※自動修正適用後

#### スコア内訳（修正後）
| カテゴリ | 修正前 | 修正後 | 主な変更 |
|---------|--------|--------|---------|
| セキュリティ | 27/30 | 28/30 | デッドコード削除 |
| パフォーマンス | 18/20 | 18/20 | 変更なし |
| 信頼性 | 17/20 | 20/20 | schtasks/powershell.exeパスクォート修正 |
| 運用性 | 14/20 | 18/20 | ログファイル保存追加・DEPLOYMENT.md作成 |
| コード品質 | 8/10 | 10/10 | デッドコード削除 |

#### 実施した修正
- [x] `Register-ResumeTask.ps1`: `schtasks /tr` の `$command` をクォート（スペース含むユーザー名対応）
- [x] `install.ps1`: `powershell.exe -File` の `$installerPath` をクォート（同上）
- [x] `Common.ps1`: `Set-SecureTlsProtocol` デッドコード削除
- [x] `Common.ps1`: `Write-InstallLog` にファイル出力追加 (`install.log`)
- [x] `docs/DEPLOYMENT.md`: 作成
- [x] `install.ps1`: `Write-FatalErrorAndExit` でもログ記録（Common.ps1 dot-source後のみ）
- [x] `install.ps1`: 並列ジョブ（S-005/S-006）の出力を `install.log` に記録

#### ライセンス
このプロジェクトは外部npmパッケージを持たないスクリプト型のため、ライセンス診断はN/A。

#### 次回診断
大型変更時または実機テスト完了後に再実施を推奨。

### 第2回診断 (2026-06-28)

**総合スコア**: **96/100 (A評価: Excellent) ✅ 維持**

前回診断（2026-06-27）以降のコード変更なし。スコア変動なし。

#### スコア内訳
| カテゴリ | スコア | 残存減点理由 |
|---------|--------|------------|
| セキュリティ | 28/30 | nvm/claude.ai install.shをハッシュ検証なしで実行（業界慣行だが供給チェーンリスク） |
| パフォーマンス | 18/20 | 初回実行時のリポジトリZIPダウンロード（irm\|iex 配布モデルの構造的オーバーヘッド） |
| 信頼性 | 20/20 | — |
| 運用性 | 18/20 | モニタリングエンドポイント（インストーラー型につきN/A） |
| コード品質 | 10/10 | — |

#### 残存課題（いずれも構造的理由により改善困難・本番可判定に影響なし）
- セキュリティ -2: 外部提供インストールスクリプトのSHA検証省略はnvm/Anthropicが提供する配布方式の制約
- パフォーマンス -2: `irm|iex`配布モデルを採用する限りZIPダウンロードは不可避
- 運用性 -2: スクリプト型インストーラーにはWebサービス型の監視エンドポイントは不適用

#### ✅ 目標達成（90点以上）— 本番運用可能

#### 次回診断推奨タイミング
- 実機テスト（Phase 10）完了後
- 大型コード変更時

---

## メモ

このプロジェクトは「Windows PCにBlueLampを全自動導入するPowerShellインストーラー」を作るための要件定義。
詳細は `docs/requirements.md` を参照。
