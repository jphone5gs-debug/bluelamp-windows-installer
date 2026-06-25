# Windows PC向けBlueLamp全自動導入インストーラー

> 設計の共通原則（基本原則・資産価値の原則）は `~/.claude/CLAUDE.md` に従う。

## プロジェクト設定

技術スタック:
  Windows側: PowerShell 5.1+（標準搭載、追加インストール不要）
  WSL内: bash（Ubuntu標準搭載）
  バックエンド/フロントエンド/DB: なし（決定論スクリプト型・#6相当、UIなし）

配布先: GitHub公開リポジトリ `eva001/bluelamp-windows-installer`（mainブランチ、Raw Content経由）

最終実行コマンド（利用者がPowerShellを管理者として実行し1行貼り付け）:
```powershell
irm https://raw.githubusercontent.com/eva001/bluelamp-windows-installer/main/install.ps1 | iex
```

## 秘密情報の扱い

- **公開リポジトリのため、APIキー・パスワード・トークンは一切コードに埋め込まない**
- 認証は既存サービス（Claude Code OAuth／BlueLamp Interactive Login）の対話フローに委譲する。本プロジェクトが認証情報を生成・保持することはない
- `.env`等の秘密情報ファイルはこのプロジェクトには存在しない（必要な秘密情報自体が無い）

## 命名規則

- PowerShell関数: `Verb-Noun`形式のPascalCase（標準のPowerShell命名規則。例: `Test-WSLStatus`）
- bash関数: snake_case
- スクリプトファイル: `install.ps1`がエントリーポイント、内部モジュールは`scripts/`配下に分割

## コード品質

- 関数: 100行以下 / ファイル: 700行以下 / 複雑度: 10以下 / 行長: 120文字
- PowerShell: `PSScriptAnalyzerSettings.psd1`（プロジェクトルート）でLint
- bash: `.shellcheckrc`（プロジェクトルート）でLint
- 上記ツールでは行長/関数長/複雑度を直接強制できないため、PRレビュー時に目視確認する

## 開発ルール

### 冪等性（必須）
全モジュールは再実行安全であること。各モジュールの先頭で「既に完了しているか」を判定し、完了済みならスキップする（`Test-WSLStatus`等の状態確認関数を必ず経由する）。

### エラー対応
- 各ステップの失敗を握り潰さない。フォールバックで誤魔化さず、失敗時は明確なメッセージで停止する
- 外部ダウンロード（nvm/Claude Code/Ubuntu rootfs等）のURLはバージョン固定とし、404等の異常時はその場でエラー終了する（曖昧なリトライ放置をしない）
- 同じエラーが3回続く場合はWeb検索で最新情報を収集する

### WSL2/Ubuntu導入の実装注意点（Step#2調査済み）
- `wsl --install`単体ではユーザー名/パスワード作成プロンプトを非対話化できない。**`wsl --import`でUbuntu公式rootfsを直接取り込む**方式を使う（root起動→`adduser --disabled-password`→`/etc/wsl.conf`に`[user] default=`設定）
- Windows機能有効化後の再起動は必須想定。再起動後の自動再開は**タスクスケジューラ(`schtasks /create /sc ONLOGON`)**で実現し、完了後は自己削除する
- nvmは非ログインシェルで`.bashrc`を読み込まないため、`wsl -d Ubuntu --`実行時は`BASH_ENV`経由で明示的にsourceする

### 認証は2系統（混同しないこと）
1. **Claude Code自体のOAuthログイン**（Anthropic/claude.aiアカウント、`~/.claude/.credentials.json`）
2. **BlueLampポータルログイン**（`~/.musuhi/portal-token.enc`、既存のInteractive Login機構）

複数PCでも、トークン共有は行わず各PCで対話ログインする（公開スクリプトへの秘密情報埋め込みを避けるため）。

### デプロイ
- GitHubへのpushはユーザーの明示的な承認を得てから実行する
- リポジトリは新規作成・public・mainブランチ追跡

### ドキュメント管理
許可されたドキュメントのみ作成可能:
- docs/SCOPE_PROGRESS.md（実装計画・進捗）
- docs/requirements.md（要件定義）
- docs/DEPLOYMENT.md（デプロイ情報）
上記以外のドキュメント作成はユーザー許諾が必要。実装済みの記載は積極的に削除する。
