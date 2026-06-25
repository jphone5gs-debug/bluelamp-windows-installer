# 要件定義書: Windows PC向けBlueLamp全自動導入インストーラー

> ステータス: **確定**（Step#1〜#6完了。Step#7で本フォーマットに統合）

## 0. アーキ構成（最重要・後続の単一の源）

- 確定アーキ: 決定論スクリプト型（#6相当・フロントUI/DB/バックエンドサーバーなし・RPA）
- 操作者: 本人（複数の自分専用Windows PC）
- AI本体(プロンプトY): なし → Phase7（エージェント構築）スキップ
- MCP: なし（インストーラー自身はMCPを使わない。導入対象のbluelamp内部MCPとは無関係） → Phase8新規実装なし（後述の通りPhase8は「スクリプト本体実装」に読み替え）
- 自社DB: なし → データモデル定義不要
- フロントUI: なし（PowerShellコンソール出力のみ） → Phase3,4,9スキップ
- 動的変数: なし（固定処理。顧客ごとの出し分けは無い）
- 種別: 該当なし（MCP型でもWeb型でもない。スクリプト配布型）
- 配布: マイ専用（GitHub公開リポジトリでホスティング。テナント配信ではない）
- 配布先: `https://github.com/jphone5gs-debug/bluelamp-windows-installer`（新規・public・mainブランチ）

### 通すPhase（12フェーズをスクリプト配布用に読み替え）

| Phase | 名称 | 扱い |
|---|---|---|
| 1 | 要件定義 | 完了 |
| 2 | Git管理 | 実施（GitHubリポジトリ作成＝配布手段そのもの） |
| 3 | フロントエンド基盤 | スキップ（UIなし） |
| 4 | ページ実装 | スキップ |
| 5 | 環境構築 | 実施（検証用WSL/VM環境の準備） |
| 6 | バックエンド計画 | スキップ |
| 7 | エージェント構築 | スキップ（AIなし） |
| 8 | バックエンド実装 | 「**スクリプト本体実装**」に読み替えて実施（PowerShell+bash） |
| 9 | フロントエンド実装 | スキップ |
| 10 | E2Eテスト | 「**実機/VM導入テスト**」に読み替えて実施 |
| 11 | ローカル動作確認 | 実施 |
| 12 | デプロイ | 「**GitHub公開**」に読み替えて実施 |

---

## 1. プロジェクト概要

### 成果目標
自分が所有する複数台のWindows PC（Ubuntu/WSL2未導入）に対し、GitHub公開リポジトリに置いたPowerShellスクリプトをURLから1行実行(`irm <URL> | iex`)するだけで、WSL2+Ubuntu導入からBlueLamp CLI・Claude Code・同一BlueLampアカウントでの認証連携までを全自動で導入する、個人用の最簡易インストーラーを作る。

### 成功指標（定量）
1. 導入完了までの所要時間：30分以内（再起動含む）
2. 手動操作：PowerShell起動＋スクリプト実行1行＋UAC許可＋再起動後の再開待ち＋Claude Codeログイン＋BlueLampログイン＝合計6アクション以内
3. 導入成功率：自分の複数台PC（Windows 10/11）すべてで100%成功
4. 保守コスト：スクリプト更新はGitHub上のファイル差し替えのみ（サーバー管理不要）

### 成功指標（定性）
1. コピペ1行で完了する単純さ（覚えることがない）
2. 各ステップの進捗が見える
3. 失敗時に何が起きたか・どうすればいいかが明確
4. 再起動を挟んでも自動的に続きから再開される

### 最終的にユーザーが行う操作
1. PowerShellを**管理者として実行**
2. 以下を1行貼り付けて実行:
   ```powershell
   irm https://raw.githubusercontent.com/jphone5gs-debug/bluelamp-windows-installer/main/install.ps1 | iex
   ```
3. （再起動が必要な場合）再起動後、自動的に処理が再開される
4. Claude Codeのログイン画面が出たらブラウザでログイン
5. BlueLampのログイン画面が出たらブラウザでログイン
6. 完了メッセージに表示されたコマンド（例: `bluelamp1`）を実行して動作確認

---

## 2. システム全体像

### 機能一覧（モジュール構成）
下記「3. モジュール詳細仕様」を参照。

### ロール
単一ユーザー（本人）のみ。ロール区分・権限マトリクスは対象外。

### 認証要件
本プロジェクトが独自の認証システムを実装するわけではない。スクリプムは以下2つの**既存の認証フロー**を適切なタイミングで起動するだけ：
1. Claude Code自体のOAuthログイン（Anthropic/claude.aiアカウント）
2. BlueLampポータルのInteractive Login（`~/.musuhi/portal-token.enc`を生成する既存機構）

---

## 3. モジュール詳細仕様

エントリーポイントは `install.ps1`。

| ID | モジュール名 | 種別 | 機能 | 入力 | 出力 | 確認手段 |
|----|------------|------|------|------|------|---------|
| S-001 | Test-WSLStatus | PowerShell関数 | WSL2/Ubuntu導入済みかを判定（冪等性確保・再実行安全） | なし | 状態フラグ（WSL有効/Ubuntu導入済み/再起動要否） | コンソールログ |
| S-002 | Enable-WSLFeature | PowerShell関数 | Windows機能(WSL, VirtualMachinePlatform)を有効化 | なし | 再起動要否フラグ | コンソールログ |
| S-003 | Register-ResumeTask | PowerShell関数 | 再起動が必要な場合、タスクスケジューラに1回限りの再開タスクを登録し再起動 | 再起動要否フラグ | （再起動実行・完了後は自己削除） | タスクスケジューラ登録確認 |
| S-004 | Import-UbuntuDistro | PowerShell関数 | Ubuntu公式rootfsを`wsl --import`で導入、ユーザー自動作成 | なし | ディストリ登録状態 | `wsl -l -v`出力 |
| S-005 | Install-NodeInWSL | bash（`wsl -d Ubuntu --`） | nvm(v0.40.1固定)経由でNode.js LTSを導入 | なし | nodeバージョン | `node -v` |
| S-006 | Install-ClaudeCodeInWSL | bash | Claude Code CLIをネイティブインストーラーで導入 | なし | claudeバイナリパス | `claude --version`の終了コード |
| S-007 | Install-BlueLampInWSL | bash | `npm install -g bluelamp`実行 | なし | bluelampコマンド群生成確認 | `which bluelamp1` |
| S-008 | Invoke-ClaudeCodeLogin | bash（対話） | Claude Code初回起動・ブラウザログイン案内 | なし | OAuthトークン保存確認 | `.credentials.json`存在確認 |
| S-009 | Invoke-BlueLampLogin | bash（対話） | `bluelamp1`初回実行・BlueLampポータルログイン案内 | なし | portal-token.enc生成確認 | `.musuhi/portal-token.enc`存在確認 |
| S-010 | Show-CompletionGuide | PowerShell関数 | 完了後、次に打つコマンドの案内を表示 | なし | 完了メッセージ | コンソール出力 |

### 処理順序・依存関係

```
S-001(状態判定) → S-002(機能有効化) →[再起動が必要な場合のみ]→ S-003(再開タスク登録・再起動)
  → S-004(Ubuntu導入) → ┬→ S-005(Node導入) → S-007(bluelamp導入) → S-009(BlueLampログイン) ─┐
                        └→ S-006(ClaudeCode導入) → S-008(ClaudeCodeログイン) ──────────────┴→ S-010(完了案内)
```
S-005とS-006はS-004完了後に並列実行可能（相互に依存しないため）。S-010はS-008とS-009の**両方**が完了して初めて実行する。

### 既知の落とし穴（実装時に必ず踏まえる）
- `wsl --import`はOOBEユーザー作成ステップを通らずrootで起動できるため、`adduser --disabled-password`等で非対話ユーザー作成→`/etc/wsl.conf`に`[user] default=`設定が必要
- nvmは非ログインシェルで`.bashrc`を読み込まないため、`wsl -d Ubuntu --`での実行時は`BASH_ENV`経由で明示的にnvmスクリプトをsourceする
- S-002の再起動要否判定（`RestartNeeded`）を誤検出した場合、S-004の`wsl --import`がWSLエンジン未初期化で失敗する。S-004の冒頭で`wsl --status`による再確認ガードを入れる
- nvmインストールURLはバージョン固定（`v0.40.1`）を使用し、将来404になった場合は曖昧なフォールバックをせずエラーで停止する（潔癖性の原則）
- S-006の成否は`claude --version`の終了コードで判定し、失敗時はS-008に進まない

---

## 4. データ設計概要

対象外。自社DBは持たない。WSL2・Claude Code・BlueLampがそれぞれ自身の設定/トークンファイルをローカル（WSL内のホームディレクトリ）に生成するのみで、本プロジェクトが管理するデータストアは存在しない。

---

## 5. セキュリティ要件

- **公開リポジトリへの秘密情報埋め込み禁止**: スクリプトにAPIキー・パスワード・トークンを一切含めない（実行時に既存サービスへの対話ログインへ委譲する設計のため、そもそも持たない）
- **HTTPS固定**: ダウンロード元（GitHub Raw / Ubuntu公式rootfs / nvm公式 / Claude Code公式インストーラー / npm registry）はすべてHTTPS。スクリプト冒頭で`[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12`を明示（古いWindows 10対策）
- **改ざん耐性（任意拡張）**: 将来的にコミットハッシュ/リリースタグ固定運用にすることで、リポジトリ乗っ取り時のリスクを下げられる（初版では運用負荷を優先しmainブランチ追跡とする）
- **エラーの隠蔽禁止**: 各モジュールの失敗を握り潰さない。フォールバックで誤魔化さず、失敗時は明確なメッセージで停止する（潔癖性の原則）
- **冪等性**: 全モジュールが再実行安全（既に完了済みのステップはスキップ）であることを必須要件とする
- ヘルスチェックエンドポイント/グレースフルシャットダウンは対象外（Webサーバーではないため）

---

## 6. 技術スタック

```yaml
スクリプト言語:
  Windows側: PowerShell 5.1+（Windows標準搭載、追加インストール不要）
  WSL内: bash（Ubuntu標準搭載）
配布: GitHub Raw Content経由（irm | iex形式、公開リポジトリ）
WSL基盤: Microsoft公式 wsl.exe + Ubuntu公式rootfs（wsl --import方式）
Node.js: nvm（バージョン固定: v0.40.1）→ Node.js LTS
BlueLamp本体: npm経由 bluelampパッケージ（最新版）
Claude Code CLI: Anthropic公式ネイティブインストーラー
認証: 既存のClaude Code OAuthログイン／BlueLamp Interactive Loginをそのまま起動（独自実装なし）
再起動継続: Windowsタスクスケジューラ（schtasks、ONLOGON、完了後自己削除）
バージョン管理: Git/GitHub（リポジトリ jphone5gs-debug/bluelamp-windows-installer、public、mainブランチ）
```

バックエンドサーバー・データベース・フロントエンドフレームワークは不要。

---

## 7. 外部サービス一覧

| サービス | 用途 | 選定理由 |
|---------|------|---------|
| GitHub Raw Content | スクリプトファイルの配布（`irm`元） | 無料・既存アカウントあり・URLで直接配信可能 |
| Ubuntu公式WSL rootfs (cloud-images.ubuntu.com) | Ubuntuディストリの取得 | Canonical公式配布元、信頼性が高い |
| nvm公式インストールスクリプト | Node.js環境構築 | 業界標準、本機での実績あり |
| Claude Code公式インストーラー (claude.ai/install.sh) | Claude Code CLI導入 | Anthropic公式、非対話インストール対応確認済み |
| npm registry (bluelampパッケージ) | BlueLamp CLI本体導入 | 既存の正規パッケージ、本機の実例と同一 |

いずれも無料・追加コストなし。

---

## 8. AI設計

対象外（AI本体Y=なし、決定論スクリプトのため）。

---

## 付録: Step#2 実機調査ログ（事実）

実機（本PC）調査により判明した、現行bluelamp導入の実体:

1. **本体パッケージ**: グローバルnpmパッケージ名は `bluelamp`（README表記は `bluelamp-neo` だが公開名は `bluelamp`。本機では `bluelamp@6.4.10`）
2. **導入コマンドはこれだけ**: `npm install -g bluelamp` で `bluelamp1`〜`bluelamp200` の200コマンドが一括生成。postinstallフックは意図的に無効化されており追加コマンド不要
3. **MCP配布の仕組み**: `bluelampN`実行毎に一時MCP設定ファイルを自動生成し`claude --mcp-config <temp>`で渡す。ユーザーがMCP設定を編集する場面はない
4. **認証は2系統、独立**:
   - Claude Code自体のOAuth（`~/.claude/.credentials.json`の`claudeAiOauth`）＝Anthropic/claude.aiアカウント
   - BlueLampポータル（`~/.musuhi/portal-token.enc`）＝`src/auth/InteractiveLogin`が生成
   - 複数PCでも、公開スクリプトへの秘密情報埋め込みはセキュリティ上避け、各PCで1回ずつ対話ログインする設計を採用（OAuth許可は「不可逆な人間同意」としてユーザーに依頼してよい操作）
5. **Claude Code CLI本体は別物**: `~/.local/bin/claude`はAnthropic公式ネイティブインストーラー由来のELFバイナリで、bluelampのnpm依存関係には含まれない＝別途インストールが必要
